-- Authoritative 18+ account eligibility, private identity, and private-social safety foundation.
alter table public.stables drop constraint if exists stables_account_status_check;
alter table public.stables add constraint stables_account_status_check check(account_status in('unverified','active','suspended','archived','cleanup_eligible','age_review'));

create table if not exists public.account_private_identity(
 account_id uuid primary key references auth.users(id)on delete cascade,
 first_name text not null check(length(first_name)between 1 and 80),
 last_name text not null check(length(last_name)between 1 and 80),
 date_of_birth date not null,
 identity_complete boolean not null default true,
 age_status text not null check(age_status in('adult','age_review','restricted')),
 social_allowed boolean not null default false,
 completed_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
alter table public.account_private_identity enable row level security;
alter table public.account_private_identity force row level security;
drop policy if exists "account reads own private identity" on public.account_private_identity;
create policy "account reads own private identity" on public.account_private_identity for select to authenticated using(account_id=auth.uid());

create table if not exists public.account_private_identity_audit(
 id uuid primary key default gen_random_uuid(),account_id uuid not null references auth.users(id)on delete cascade,
 actor_id uuid references auth.users(id)on delete set null,action text not null,previous_values jsonb not null default'{}',new_values jsonb not null default'{}',reason text not null,created_at timestamptz not null default now()
);
alter table public.account_private_identity_audit enable row level security;
alter table public.account_private_identity_audit force row level security;

create or replace function public.account_is_adult(p_dob date,p_on date default current_date)returns boolean language sql immutable as $$select p_dob is not null and p_dob<=p_on and p_dob<=(p_on-interval'18 years')::date$$;
create or replace function public.account_social_eligible(p_account uuid default auth.uid())returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from account_private_identity i join stables s on s.id=i.account_id where i.account_id=p_account and i.identity_complete and i.age_status='adult'and i.social_allowed and coalesce(s.account_status,'active')not in('suspended','deleted','age_review'))
$$;
create or replace function public.require_social_eligibility()returns void language plpgsql stable security definer set search_path=public as $$begin
 if auth.uid()is null then raise exception'Authentication required';end if;
 if not account_social_eligible(auth.uid())then raise exception'Account Information Required. Legacy Equine is currently available to players age 18 and older. Contact Admin through Help & Support for account questions.';end if;
end$$;
create or replace function public.get_my_account_eligibility()returns jsonb language sql stable security definer set search_path=public as $$
 select case when i.account_id is null then jsonb_build_object('identity_complete',false,'adult',false,'social_allowed',false,'status','information_required')
 else jsonb_build_object('identity_complete',i.identity_complete,'adult',i.age_status='adult','social_allowed',account_social_eligible(auth.uid()),'status',i.age_status)end
 from(values(1))v(x)left join account_private_identity i on i.account_id=auth.uid()
$$;
create or replace function public.complete_account_information(p_first_name text,p_last_name text,p_date_of_birth date)returns jsonb language plpgsql security definer set search_path=public as $$
declare first_value text:=trim(coalesce(p_first_name,''));last_value text:=trim(coalesce(p_last_name,''));adult boolean;
begin
 if auth.uid()is null or not exists(select 1 from stables where id=auth.uid())then raise exception'Authenticated account required';end if;
 if exists(select 1 from account_private_identity where account_id=auth.uid())then raise exception'Account information is already complete. Contact Admin through Help & Support for corrections.';end if;
 if length(first_value)not between 1 and 80 or length(last_value)not between 1 and 80 then raise exception'First and last name are required';end if;
 if p_date_of_birth is null or p_date_of_birth>current_date then raise exception'Enter a valid date of birth';end if;
 adult:=account_is_adult(p_date_of_birth,current_date);
 insert into account_private_identity(account_id,first_name,last_name,date_of_birth,age_status,social_allowed)values(auth.uid(),first_value,last_value,p_date_of_birth,case when adult then'adult'else'age_review'end,adult);
 if not adult then update stables set account_status='age_review'where id=auth.uid();end if;
 insert into account_private_identity_audit(account_id,actor_id,action,reason)values(auth.uid(),auth.uid(),'identity.completed',case when adult then'Existing account information completed'else'Existing account requires age-policy review'end);
 return get_my_account_eligibility();
end$$;

create or replace function public.public_signup_availability(p_username text,p_stable_name text,p_first_name text,p_last_name text,p_date_of_birth date)returns jsonb language plpgsql stable security definer set search_path=public as $$
declare normalized text:=trim(coalesce(p_username,''));stable_value text:=trim(coalesce(p_stable_name,''));first_value text:=trim(coalesce(p_first_name,''));last_value text:=trim(coalesce(p_last_name,''));
begin
 if normalized!~'^[A-Za-z0-9_]{3,24}$'then raise exception'Username must be 3–24 letters, numbers, or underscores';end if;
 if length(stable_value)not between 2 and 60 then raise exception'Stable name must be 2–60 characters';end if;
 if length(first_value)not between 1 and 80 or length(last_value)not between 1 and 80 then raise exception'First and last name are required';end if;
 if p_date_of_birth is null or p_date_of_birth>current_date then raise exception'Enter a valid date of birth';end if;
 if not account_is_adult(p_date_of_birth,current_date)then raise exception'Legacy Equine is currently available to players age 18 and older. You may create an account once you meet the current age requirement.';end if;
 return jsonb_build_object('username_available',not exists(select 1 from stables where lower(username)=lower(normalized)),'stable_name_valid',true,'age_eligible',true);
end$$;

create or replace function public.initialize_new_auth_player()returns trigger language plpgsql security definer set search_path=public,auth as $$
declare stable_value text:=trim(coalesce(new.raw_user_meta_data->>'stable_name',''));username_value text:=trim(coalesce(new.raw_user_meta_data->>'username',''));first_value text:=trim(coalesce(new.raw_user_meta_data->>'private_first_name',''));last_value text:=trim(coalesce(new.raw_user_meta_data->>'private_last_name',''));dob date;is_test boolean;
begin
 if stable_value=''and username_value=''then return new;end if;
 if length(stable_value)not between 2 and 60 then raise exception'Stable name must be 2–60 characters';end if;
 if username_value!~'^[A-Za-z0-9_]{3,24}$'then raise exception'Username must be 3–24 letters, numbers, or underscores';end if;
 if length(first_value)not between 1 and 80 or length(last_value)not between 1 and 80 then raise exception'First and last name are required';end if;
 begin dob:=(new.raw_user_meta_data->>'date_of_birth')::date;exception when others then raise exception'Enter a valid date of birth';end;
 if dob>current_date then raise exception'Enter a valid date of birth';end if;
 if not account_is_adult(dob,current_date)then raise exception'Legacy Equine is currently available to players age 18 and older.';end if;
 if exists(select 1 from public.stables where lower(username)=lower(username_value))then raise exception'That username is unavailable';end if;
 is_test:=coalesce(new.email ilike'%+test@%',false)or coalesce(new.email ilike'%+qa@%',false)or coalesce(new.email ilike'%@example.%',false);
 insert into public.stables(id,name,username,balance,account_number,account_xp)values(new.id,stable_value,username_value,3000,case when is_test then null else nextval('public.account_number_seq')end,0);
 insert into public.account_private_identity(account_id,first_name,last_name,date_of_birth,age_status,social_allowed)values(new.id,first_value,last_value,dob,'adult',true);
 insert into public.currency_ledger(stable_id,amount,reason)values(new.id,3000,'Starting funds');
 return new;
end$$;

create or replace function public.can_view_private_identity(p_user uuid default auth.uid())returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from stables where id=p_user and account_number=1)or has_admin_permission('accounts.private_identity.view',p_user)$$;
create or replace function public.admin_get_private_identity(p_account uuid)returns jsonb language plpgsql security definer set search_path=public as $$declare result jsonb;begin
 if not can_view_private_identity()then raise exception'Private identity permission required';end if;
 select jsonb_build_object('account_id',s.id,'account_number',s.account_number,'username',s.username,'stable_name',s.name,'first_name',i.first_name,'last_name',i.last_name,'date_of_birth',i.date_of_birth,'age_status',coalesce(i.age_status,'information_required'),'identity_complete',coalesce(i.identity_complete,false),'social_allowed',coalesce(i.social_allowed,false))into result from stables s left join account_private_identity i on i.account_id=s.id where s.id=p_account;
 if result is null then raise exception'Account not found';end if;
 insert into admin_audit_log(actor_id,action_type,system,target_type,target_id,details)values(auth.uid(),'accounts.private_identity.viewed','accounts','account',p_account::text,jsonb_build_object('purpose','Admin Accounts workflow'));
 return result;
end$$;
create or replace function public.admin_correct_private_identity(p_account uuid,p_first_name text,p_last_name text,p_date_of_birth date,p_reason text)returns void language plpgsql security definer set search_path=public as $$declare old account_private_identity;adult boolean;begin
 if not can_view_private_identity()then raise exception'Private identity permission required';end if;
 if length(trim(coalesce(p_reason,'')))<10 then raise exception'An internal correction reason is required';end if;
 if length(trim(coalesce(p_first_name,'')))not between 1 and 80 or length(trim(coalesce(p_last_name,'')))not between 1 and 80 or p_date_of_birth is null or p_date_of_birth>current_date then raise exception'Valid private account information is required';end if;
 select*into old from account_private_identity where account_id=p_account for update;adult:=account_is_adult(p_date_of_birth,current_date);
 insert into account_private_identity(account_id,first_name,last_name,date_of_birth,age_status,social_allowed)values(p_account,trim(p_first_name),trim(p_last_name),p_date_of_birth,case when adult then'adult'else'age_review'end,adult)on conflict(account_id)do update set first_name=excluded.first_name,last_name=excluded.last_name,date_of_birth=excluded.date_of_birth,age_status=excluded.age_status,social_allowed=excluded.social_allowed,updated_at=now();
 update stables set account_status=case when adult and account_status='age_review'then'active'when not adult then'age_review'else account_status end where id=p_account;
 insert into account_private_identity_audit(account_id,actor_id,action,previous_values,new_values,reason)values(p_account,auth.uid(),'identity.corrected',case when old.account_id is null then'{}'::jsonb else jsonb_build_object('first_name',old.first_name,'last_name',old.last_name,'date_of_birth',old.date_of_birth,'age_status',old.age_status)end,jsonb_build_object('first_name',trim(p_first_name),'last_name',trim(p_last_name),'date_of_birth',p_date_of_birth,'age_status',case when adult then'adult'else'age_review'end),left(trim(p_reason),500));
 insert into admin_audit_log(actor_id,action_type,system,target_type,target_id,details)values(auth.uid(),'accounts.private_identity.corrected','accounts','account',p_account::text,jsonb_build_object('reason',left(trim(p_reason),500),'adult',adult));
end$$;

-- Mailbox safety primitives are installed before any player-facing Mailbox navigation.
create table if not exists public.player_blocks(blocker_id uuid not null references public.stables(id)on delete cascade,blocked_id uuid not null references public.stables(id)on delete cascade,created_at timestamptz not null default now(),primary key(blocker_id,blocked_id),check(blocker_id<>blocked_id));
create table if not exists public.mailbox_threads(id uuid primary key default gen_random_uuid(),participant_one uuid not null references public.stables(id)on delete cascade,participant_two uuid not null references public.stables(id)on delete cascade,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),check(participant_one::text<participant_two::text),unique(participant_one,participant_two));
create table if not exists public.mailbox_messages(id uuid primary key default gen_random_uuid(),thread_id uuid not null references public.mailbox_threads(id)on delete cascade,sender_id uuid not null references public.stables(id)on delete cascade,body text not null check(length(body)between 1 and 3000),created_at timestamptz not null default now());
create table if not exists public.mailbox_message_reports(id uuid primary key default gen_random_uuid(),message_id uuid not null references public.mailbox_messages(id)on delete cascade,reporter_id uuid not null references public.stables(id)on delete cascade,support_ticket_id uuid references public.support_tickets(id),reason text not null,created_at timestamptz not null default now(),unique(message_id,reporter_id));
alter table public.player_blocks enable row level security;alter table public.mailbox_threads enable row level security;alter table public.mailbox_messages enable row level security;alter table public.mailbox_message_reports enable row level security;
alter table public.player_blocks force row level security;alter table public.mailbox_threads force row level security;alter table public.mailbox_messages force row level security;alter table public.mailbox_message_reports force row level security;
create policy "players read own blocks" on public.player_blocks for select using(blocker_id=auth.uid());
create policy "participants read threads" on public.mailbox_threads for select using(account_social_eligible()and auth.uid()in(participant_one,participant_two));
create policy "participants read messages" on public.mailbox_messages for select using(account_social_eligible()and exists(select 1 from mailbox_threads t where t.id=thread_id and auth.uid()in(t.participant_one,t.participant_two)));
create policy "players read own message reports" on public.mailbox_message_reports for select using(reporter_id=auth.uid());
create or replace function public.block_mailbox_player(p_account uuid,p_block boolean default true)returns void language plpgsql security definer set search_path=public as $$begin perform require_social_eligibility();if p_account=auth.uid()or not exists(select 1 from stables where id=p_account)then raise exception'Choose a valid player';end if;if p_block then insert into player_blocks(blocker_id,blocked_id)values(auth.uid(),p_account)on conflict do nothing;else delete from player_blocks where blocker_id=auth.uid()and blocked_id=p_account;end if;end$$;
create or replace function public.send_mailbox_message(p_recipient uuid,p_body text,p_thread uuid default null)returns jsonb language plpgsql security definer set search_path=public as $$declare recipient uuid;thread mailbox_threads;message mailbox_messages;one_id uuid;two_id uuid;last_time timestamptz;begin
 perform require_social_eligibility();if p_recipient=auth.uid()or not account_social_eligible(p_recipient)then raise exception'Recipient is unavailable';end if;if exists(select 1 from player_blocks where(blocker_id=auth.uid()and blocked_id=p_recipient)or(blocker_id=p_recipient and blocked_id=auth.uid()))then raise exception'Messaging is unavailable for this player';end if;
 if length(trim(coalesce(p_body,'')))not between 1 and 3000 then raise exception'Message must be 1–3,000 characters';end if;
 select max(created_at)into last_time from mailbox_messages where sender_id=auth.uid();if last_time>now()-interval'3 seconds'then raise exception'Please wait before sending another message';end if;
 one_id:=least(auth.uid()::text,p_recipient::text)::uuid;two_id:=greatest(auth.uid()::text,p_recipient::text)::uuid;
 if p_thread is not null then select*into thread from mailbox_threads where id=p_thread and auth.uid()in(participant_one,participant_two)and p_recipient in(participant_one,participant_two)for update;end if;
 if thread.id is null then insert into mailbox_threads(participant_one,participant_two)values(one_id,two_id)on conflict(participant_one,participant_two)do update set updated_at=now()returning*into thread;end if;
 insert into mailbox_messages(thread_id,sender_id,body)values(thread.id,auth.uid(),left(trim(regexp_replace(p_body,'<[^>]*>','','g')),3000))returning*into message;update mailbox_threads set updated_at=now()where id=thread.id;
 return jsonb_build_object('thread_id',thread.id,'message_id',message.id,'created_at',message.created_at);
end$$;
create or replace function public.report_mailbox_message(p_message uuid,p_reason text)returns uuid language plpgsql security definer set search_path=public as $$declare m mailbox_messages;t mailbox_threads;ticket uuid;begin perform require_social_eligibility();select*into m from mailbox_messages where id=p_message;select*into t from mailbox_threads where id=m.thread_id and auth.uid()in(participant_one,participant_two);if t.id is null then raise exception'Message not found';end if;if length(trim(coalesce(p_reason,'')))<3 then raise exception'Add a report reason';end if;
 insert into support_tickets(stable_id,ticket_type,category,title,description,object_context)values(auth.uid(),'general','Report Player/Content','Reported private message',left(trim(p_reason),5000),jsonb_build_object('content_type','mailbox_message','content_id',m.id))returning id into ticket;
 insert into mailbox_message_reports(message_id,reporter_id,support_ticket_id,reason)values(m.id,auth.uid(),ticket,left(trim(p_reason),500))on conflict(message_id,reporter_id)do update set reason=excluded.reason,support_ticket_id=excluded.support_ticket_id;
 return ticket;
end$$;

drop policy if exists "authenticated rooms readable" on public.chat_rooms;
create policy "eligible accounts read rooms" on public.chat_rooms for select to authenticated using(account_social_eligible()and archived_at is null and(read_permission='players'or community_staff()));
drop policy if exists "authenticated visible messages readable" on public.chat_messages;
create policy "eligible accounts read messages" on public.chat_messages for select to authenticated using(account_social_eligible()and(moderation_status='visible'or author_id=auth.uid()or community_staff()));
create or replace function public.get_chat_rooms()returns table(id uuid,name text,description text,display_order integer,icon text,rules text,read_permission text,post_permission text,active boolean,archived_at timestamptz,locked boolean,read_only boolean)language plpgsql security definer set search_path=public stable as $$begin perform require_social_eligibility();return query select r.id,r.name,r.description,r.display_order,r.icon,r.rules,r.read_permission,r.post_permission,r.active,r.archived_at,r.locked,r.read_only from chat_rooms r where r.archived_at is null and(r.read_permission='players'or community_staff())order by r.display_order,r.name;end$$;
create or replace function public.get_chat_messages(target_room uuid,before_time timestamptz default null,page_size integer default 50)returns table(id uuid,room_id uuid,content text,created_at timestamptz,edited_at timestamptz,moderation_status text,moderation_reason text,author_id uuid,stable_name text,username text,account_number bigint,avatar_url text,community_role community_role)language plpgsql security definer set search_path=public stable as $$begin perform require_social_eligibility();if not exists(select 1 from chat_rooms r where r.id=target_room and r.archived_at is null and(r.read_permission='players'or community_staff()))then raise exception'Chat room is unavailable';end if;return query select m.id,m.room_id,case when m.moderation_status='hidden'then'[Message removed by Community staff]'else m.content end,m.created_at,m.edited_at,m.moderation_status,case when community_staff()then m.moderation_reason end,m.author_id,s.name,s.username,s.account_number,s.avatar_url,s.community_role from chat_messages m join stables s on s.id=m.author_id where m.room_id=target_room and(before_time is null or m.created_at<before_time)and(m.moderation_status='visible'or m.author_id=auth.uid()or community_staff())order by m.created_at desc limit least(greatest(page_size,1),100);end$$;
create or replace function public.send_chat_message(target_room uuid,message_content text,refs jsonb default'[]')returns chat_messages language plpgsql security definer set search_path=public as $$declare r chat_rooms;s stables;result chat_messages;last_message chat_messages;begin perform require_social_eligibility();select*into s from stables where id=auth.uid();if s.username is null then raise exception'Create a username in Settings before chatting';end if;select*into r from chat_rooms where id=target_room for update;if not found or not r.active or r.archived_at is not null then raise exception'Chat room is unavailable';end if;if r.locked or r.read_only then raise exception'This room is currently read-only';end if;if r.post_permission='staff'and not community_staff()then raise exception'Only Community staff may post here';end if;if exists(select 1 from chat_mutes m where m.stable_id=s.id and(m.room_id is null or m.room_id=r.id)and m.expires_at>now())then raise exception'You are temporarily muted from this chat';end if;if length(trim(message_content))not between 1 and 1000 then raise exception'Messages must be 1–1,000 characters';end if;select*into last_message from chat_messages where author_id=s.id order by created_at desc limit 1;if last_message.created_at>now()-interval'3 seconds'then raise exception'Please wait a moment before sending another message';end if;if last_message.created_at>now()-interval'2 minutes'and lower(last_message.content)=lower(trim(message_content))then raise exception'Please do not repeat the same message';end if;insert into chat_messages(room_id,author_id,content,entity_refs)values(r.id,s.id,left(trim(regexp_replace(message_content,'<[^>]*>','','g')),1000),coalesce(refs,'[]'))returning*into result;return result;end$$;

revoke all on table public.account_private_identity,public.account_private_identity_audit,public.player_blocks,public.mailbox_threads,public.mailbox_messages,public.mailbox_message_reports from anon,authenticated;
grant select on public.account_private_identity to authenticated;
grant select on public.player_blocks,public.mailbox_threads,public.mailbox_messages,public.mailbox_message_reports to authenticated;
revoke all on function public.account_is_adult(date,date),public.account_social_eligible(uuid),public.require_social_eligibility(),public.get_my_account_eligibility(),public.complete_account_information(text,text,date),public.public_signup_availability(text,text,text,text,date),public.can_view_private_identity(uuid),public.admin_get_private_identity(uuid),public.admin_correct_private_identity(uuid,text,text,date,text),public.block_mailbox_player(uuid,boolean),public.send_mailbox_message(uuid,text,uuid),public.report_mailbox_message(uuid,text)from public;
grant execute on function public.account_is_adult(date,date),public.public_signup_availability(text,text,text,text,date)to anon,authenticated;
grant execute on function public.account_social_eligible(uuid),public.require_social_eligibility(),public.get_my_account_eligibility(),public.complete_account_information(text,text,date),public.can_view_private_identity(uuid),public.admin_get_private_identity(uuid),public.admin_correct_private_identity(uuid,text,text,date,text),public.block_mailbox_player(uuid,boolean),public.send_mailbox_message(uuid,text,uuid),public.report_mailbox_message(uuid,text)to authenticated;

comment on table public.account_private_identity is'Protected private account/safety identity. Never expose through public profile projections.';
comment on function public.account_social_eligible(uuid)is'Central raw-DOB-minimizing capability resolver for private and community social systems.';
