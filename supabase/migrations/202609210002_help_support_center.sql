-- Private, authoritative player support tickets and Owner/Admin support tooling.
create table if not exists public.support_tickets(
 id uuid primary key default gen_random_uuid(),
 ticket_number bigint generated always as identity(start with 1000) unique,
 stable_id uuid not null references public.stables(id)on delete restrict,
 ticket_type text not null check(ticket_type in('bug','general')),
 category text not null,
 title text not null,
 description text not null,
 reproduction text not null default'',
 attachment_path text,
 technical_context jsonb not null default'{}',
 object_context jsonb not null default'{}',
 status text not null default'open'check(status in('open','in_review','need_info','resolved','closed','duplicate')),
 priority text not null default'normal'check(priority in('low','normal','high','critical')),
 assigned_admin_id uuid references public.stables(id),
 duplicate_of uuid references public.support_tickets(id),
 last_player_viewed_at timestamptz,
 last_admin_update_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists support_ticket_owner_idx on public.support_tickets(stable_id,updated_at desc);
create index if not exists support_ticket_queue_idx on public.support_tickets(status,ticket_type,updated_at desc);

create table if not exists public.support_ticket_messages(
 id uuid primary key default gen_random_uuid(),
 ticket_id uuid not null references public.support_tickets(id)on delete cascade,
 author_id uuid not null references public.stables(id),
 message_type text not null check(message_type in('player_reply','admin_reply','internal_note')),
 body text not null,
 created_at timestamptz not null default now()
);
create index if not exists support_message_ticket_idx on public.support_ticket_messages(ticket_id,created_at);

alter table public.support_tickets enable row level security;
alter table public.support_ticket_messages enable row level security;
drop policy if exists "players read own support tickets" on public.support_tickets;
create policy "players read own support tickets" on public.support_tickets for select using(stable_id=auth.uid()or public.has_admin_permission('support.manage'));
drop policy if exists "players read safe support messages" on public.support_ticket_messages;
create policy "players read safe support messages" on public.support_ticket_messages for select using(
 public.has_admin_permission('support.manage')or(message_type<>'internal_note'and exists(select 1 from public.support_tickets t where t.id=ticket_id and t.stable_id=auth.uid()))
);

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('support-attachments','support-attachments',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id)do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists "support attachment upload" on storage.objects;
create policy "support attachment upload" on storage.objects for insert to authenticated with check(bucket_id='support-attachments'and(storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "support attachment read" on storage.objects;
create policy "support attachment read" on storage.objects for select to authenticated using(bucket_id='support-attachments'and((storage.foldername(name))[1]=auth.uid()::text or public.has_admin_permission('support.manage')));

create or replace function public.support_safe_text(p_value text,p_limit integer)returns text language sql immutable as $$select left(trim(regexp_replace(coalesce(p_value,''),'<[^>]*>','','g')),p_limit)$$;
create or replace function public.support_ticket_code(p_number bigint)returns text language sql immutable as $$select 'LE-'||p_number::text$$;

create or replace function public.submit_support_ticket(
 p_type text,p_category text,p_title text,p_description text,p_reproduction text default'',p_attachment_path text default null,p_technical_context jsonb default'{}',p_object_context jsonb default'{}'
)returns jsonb language plpgsql security definer set search_path=public as $$
declare t support_tickets;allowed_bug text[]:=array['Horse / Stable','Shows','Store / Inventory','Feed / Tack','Marketplace','Professions','Community','Bank / LED','Account','Mobile / Display','Other'];allowed_general text[]:=array['Account Help','Gameplay Question','Player/Community Concern','Purchase/LED Problem','Report Player/Content','Other'];safe_tech jsonb;safe_object jsonb;
begin
 if auth.uid()is null or not exists(select 1 from stables where id=auth.uid())then raise exception'Authenticated Stable required';end if;
 if p_type not in('bug','general')then raise exception'Choose Bug Report or Contact Admin';end if;
 if(p_type='bug'and not p_category=any(allowed_bug))or(p_type='general'and not p_category=any(allowed_general))then raise exception'Choose a valid support category';end if;
 if length(trim(coalesce(p_title,'')))not between 3 and 120 or length(trim(coalesce(p_description,'')))not between 10 and 5000 then raise exception'Title and description are required';end if;
 if p_attachment_path is not null and p_attachment_path!~('^'||auth.uid()::text||'/[A-Za-z0-9._/-]+$')then raise exception'Invalid support attachment';end if;
 safe_tech:=jsonb_strip_nulls(jsonb_build_object('route',left(p_technical_context->>'route',500),'reported_at',p_technical_context->>'reported_at','viewport',left(p_technical_context->>'viewport',80),'device_class',left(p_technical_context->>'device_class',30),'user_agent',left(p_technical_context->>'user_agent',500),'build',left(p_technical_context->>'build',100)));
 safe_object:=jsonb_strip_nulls(jsonb_build_object('horse_id',p_object_context->>'horse_id','show_id',p_object_context->>'show_id','profession',left(p_object_context->>'profession',50),'career_level',left(p_object_context->>'career_level',50),'listing_id',p_object_context->>'listing_id','content_type',left(p_object_context->>'content_type',50),'content_id',p_object_context->>'content_id'));
 insert into support_tickets(stable_id,ticket_type,category,title,description,reproduction,attachment_path,technical_context,object_context,last_player_viewed_at)
 values(auth.uid(),p_type,p_category,support_safe_text(p_title,120),support_safe_text(p_description,5000),support_safe_text(p_reproduction,3000),nullif(p_attachment_path,''),safe_tech,safe_object,now())returning*into t;
 return jsonb_build_object('id',t.id,'ticket_number',support_ticket_code(t.ticket_number));
end$$;

create or replace function public.get_my_support_tickets()returns jsonb language plpgsql security definer set search_path=public as $$begin
 return coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'ticket_number',support_ticket_code(t.ticket_number),'type',t.ticket_type,'category',t.category,'title',t.title,'status',t.status,'priority',t.priority,'created_at',t.created_at,'updated_at',t.updated_at,'has_update',t.last_admin_update_at is not null and t.last_admin_update_at>coalesce(t.last_player_viewed_at,t.created_at))order by t.updated_at desc)from support_tickets t where t.stable_id=auth.uid()),'[]'::jsonb);
end$$;

create or replace function public.get_my_support_update_count()returns integer language sql stable security definer set search_path=public as $$select count(*)::integer from support_tickets where stable_id=auth.uid()and last_admin_update_at is not null and last_admin_update_at>coalesce(last_player_viewed_at,created_at)$$;

create or replace function public.get_support_ticket(p_ticket uuid)returns jsonb language plpgsql security definer set search_path=public as $$declare t support_tickets;admin boolean:=has_admin_permission('support.manage');result jsonb;begin
 select*into t from support_tickets where id=p_ticket and(stable_id=auth.uid()or admin);if not found then raise exception'Support ticket not found';end if;
 if not admin then update support_tickets set last_player_viewed_at=now()where id=t.id;end if;
 select jsonb_build_object('id',t.id,'ticket_number',support_ticket_code(t.ticket_number),'type',t.ticket_type,'ticket_type',t.ticket_type,'category',t.category,'title',t.title,'description',t.description,'reproduction',t.reproduction,'attachment_path',t.attachment_path,'technical_context',case when admin then t.technical_context else'{}'::jsonb end,'object_context',t.object_context,'status',t.status,'priority',case when admin then t.priority else null end,'assigned_admin_id',case when admin then t.assigned_admin_id else null end,'account_number',case when admin then(select s.account_number from stables s where s.id=t.stable_id)else null end,'username',case when admin then(select coalesce(s.username,s.name)from stables s where s.id=t.stable_id)else null end,'duplicate_of',case when t.duplicate_of is null then null else(select support_ticket_code(d.ticket_number)from support_tickets d where d.id=t.duplicate_of)end,'created_at',t.created_at,'updated_at',t.updated_at,'messages',coalesce((select jsonb_agg(jsonb_build_object('id',m.id,'type',m.message_type,'body',m.body,'author',coalesce(s.username,s.name),'created_at',m.created_at)order by m.created_at)from support_ticket_messages m join stables s on s.id=m.author_id where m.ticket_id=t.id and(admin or m.message_type<>'internal_note')),'[]'::jsonb))into result;
 return result;
end$$;

create or replace function public.add_support_reply(p_ticket uuid,p_body text)returns void language plpgsql security definer set search_path=public as $$declare t support_tickets;begin
 select*into t from support_tickets where id=p_ticket and stable_id=auth.uid()for update;if not found then raise exception'Support ticket not found';end if;if t.status in('closed','duplicate')then raise exception'This ticket is closed';end if;if length(trim(coalesce(p_body,'')))not between 2 and 3000 then raise exception'Add a reply before sending';end if;
 insert into support_ticket_messages(ticket_id,author_id,message_type,body)values(t.id,auth.uid(),'player_reply',support_safe_text(p_body,3000));update support_tickets set updated_at=now(),status=case when status='need_info'then'in_review'else status end where id=t.id;
end$$;

create or replace function public.admin_support_workspace(p_query text default'',p_status text default'',p_type text default'',p_category text default'')returns jsonb language plpgsql stable security definer set search_path=public as $$begin
 perform require_admin_permission('support.manage');
 return jsonb_build_object('counts',jsonb_build_object('open',(select count(*)from support_tickets where status='open'),'in_review',(select count(*)from support_tickets where status='in_review'),'need_info',(select count(*)from support_tickets where status='need_info'),'resolved_today',(select count(*)from support_tickets where status='resolved'and updated_at::date=current_date)),'admins',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'account_number',s.account_number,'name',coalesce(s.username,s.name))order by s.account_number)from stables s where has_admin_permission('support.manage',s.id)),'[]'::jsonb),'tickets',coalesce((select jsonb_agg(to_jsonb(x)order by x.updated_at desc)from(select t.id,support_ticket_code(t.ticket_number)ticket_number,t.ticket_type,t.category,t.title,t.status,t.priority,t.created_at,t.updated_at,t.technical_context->>'build'build,s.account_number,coalesce(s.username,s.name)username,case when t.duplicate_of is null then null else support_ticket_code(d.ticket_number)end duplicate_of from support_tickets t join stables s on s.id=t.stable_id left join support_tickets d on d.id=t.duplicate_of where(coalesce(p_status,'')=''or(p_status='unresolved_bugs'and t.ticket_type='bug'and t.status not in('resolved','closed','duplicate'))or t.status=p_status)and(coalesce(p_type,'')=''or t.ticket_type=p_type)and(coalesce(p_category,'')=''or t.category=p_category)and(coalesce(trim(p_query),'')=''or concat_ws(' ',support_ticket_code(t.ticket_number),t.title,t.category,s.account_number,coalesce(s.username,s.name))ilike'%'||trim(p_query)||'%')limit 500)x),'[]'::jsonb));
end$$;

create or replace function public.admin_update_support_ticket(p_ticket uuid,p_status text,p_priority text,p_assigned_admin uuid default null,p_reply text default'',p_internal_note text default'',p_duplicate_ticket text default'')returns void language plpgsql security definer set search_path=public as $$declare t support_tickets;duplicate_id uuid;before_state jsonb;begin
 perform require_admin_permission('support.manage');select*into t from support_tickets where id=p_ticket for update;if not found then raise exception'Support ticket not found';end if;if p_status not in('open','in_review','need_info','resolved','closed','duplicate')or p_priority not in('low','normal','high','critical')then raise exception'Invalid support status or priority';end if;if p_assigned_admin is not null and not(has_admin_permission('support.manage',p_assigned_admin))then raise exception'Assigned account lacks Support permission';end if;
 if p_status='duplicate'then select id into duplicate_id from support_tickets where support_ticket_code(ticket_number)=upper(trim(p_duplicate_ticket))and id<>p_ticket;if duplicate_id is null then raise exception'Choose a valid duplicate ticket number';end if;end if;
 before_state:=jsonb_build_object('status',t.status,'priority',t.priority,'assigned_admin_id',t.assigned_admin_id,'duplicate_of',t.duplicate_of);
 if length(trim(coalesce(p_reply,'')))>0 then insert into support_ticket_messages(ticket_id,author_id,message_type,body)values(p_ticket,auth.uid(),'admin_reply',support_safe_text(p_reply,3000));end if;
 if length(trim(coalesce(p_internal_note,'')))>0 then insert into support_ticket_messages(ticket_id,author_id,message_type,body)values(p_ticket,auth.uid(),'internal_note',support_safe_text(p_internal_note,3000));end if;
 update support_tickets set status=p_status,priority=p_priority,assigned_admin_id=p_assigned_admin,duplicate_of=case when p_status='duplicate'then duplicate_id else null end,last_admin_update_at=case when length(trim(coalesce(p_reply,'')))>0 or p_status<>t.status then now()else last_admin_update_at end,updated_at=now()where id=p_ticket;
 insert into admin_audit_log(actor_id,action_type,system,target_type,target_id,details)values(auth.uid(),'support.ticket_updated','support','support_ticket',p_ticket::text,jsonb_build_object('before',before_state,'after',jsonb_build_object('status',p_status,'priority',p_priority,'assigned_admin_id',p_assigned_admin,'duplicate_of',duplicate_id),'player_reply',length(trim(coalesce(p_reply,'')))>0,'internal_note',length(trim(coalesce(p_internal_note,'')))>0));
end$$;

revoke all on function public.submit_support_ticket(text,text,text,text,text,text,jsonb,jsonb),public.get_my_support_tickets(),public.get_my_support_update_count(),public.get_support_ticket(uuid),public.add_support_reply(uuid,text),public.admin_support_workspace(text,text,text,text),public.admin_update_support_ticket(uuid,text,text,uuid,text,text,text)from public;
grant execute on function public.submit_support_ticket(text,text,text,text,text,text,jsonb,jsonb),public.get_my_support_tickets(),public.get_my_support_update_count(),public.get_support_ticket(uuid),public.add_support_reply(uuid,text),public.admin_support_workspace(text,text,text,text),public.admin_update_support_ticket(uuid,text,text,uuid,text,text,text)to authenticated;
