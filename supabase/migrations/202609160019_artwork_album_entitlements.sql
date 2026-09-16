-- Single Artwork Album: explicit entitlements, safe quota enforcement, and Owner gifts.
create table public.artwork_storage_config(
 id boolean primary key default true check(id),
 subscriber_base_capacity integer not null default 100 check(subscriber_base_capacity>=0),
 free_base_capacity integer not null default 0 check(free_base_capacity>=0),
 max_upload_bytes integer not null default 5242880 check(max_upload_bytes between 1 and 5242880),
 max_dimension integer not null default 1200 check(max_dimension between 1 and 1200),
 allowed_mime_types text[] not null default array['image/jpeg','image/png','image/webp'],
 updated_at timestamptz not null default now(),updated_by uuid references stables(id)
);insert into artwork_storage_config(id)values(true)on conflict do nothing;

create table public.artwork_storage_entitlements(
 stable_id uuid primary key references stables(id) on delete cascade,
 bonus_capacity integer not null default 0 check(bonus_capacity>=0),
 unlimited boolean not null default false,
 privilege text not null default 'Owner Granted' check(privilege in('Owner Granted','Special','None')),
 subscription_dependent boolean not null default false,
 note text not null default '',updated_by uuid references stables(id),updated_at timestamptz not null default now()
);
create table public.artwork_album_items(
 id uuid primary key default gen_random_uuid(),stable_id uuid not null references stables(id) on delete cascade,
 storage_path text not null unique,mime_type text not null default '',byte_size integer not null default 0,
 width integer not null default 0,height integer not null default 0,
 status text not null default 'reserved' check(status in('reserved','active','removed')),
 created_at timestamptz not null default now(),finalized_at timestamptz,removed_at timestamptz,
 check(byte_size between 0 and 5242880),check(width between 0 and 1200),check(height between 0 and 1200)
);create index artwork_album_owner_status on artwork_album_items(stable_id,status,created_at);
create table public.artwork_storage_gift_history(
 id bigint generated always as identity primary key,recipient_id uuid not null references stables(id),granted_by uuid not null references stables(id),
 previous_base integer not null,previous_bonus integer not null,previous_unlimited boolean not null,
 change_description text not null,new_base integer not null,new_bonus integer not null,new_unlimited boolean not null,
 subscription_dependent boolean not null default false,reason text not null default '',created_at timestamptz not null default now()
);
alter table artwork_storage_config enable row level security;alter table artwork_storage_entitlements enable row level security;alter table artwork_album_items enable row level security;alter table artwork_storage_gift_history enable row level security;
create policy "album owners read items" on artwork_album_items for select using(stable_id=auth.uid()or has_admin_permission('admin.accounts.view'));
create policy "album owners remove items" on artwork_album_items for update using(stable_id=auth.uid())with check(stable_id=auth.uid());
create policy "owners read entitlement" on artwork_storage_entitlements for select using(stable_id=auth.uid()or is_owner_account());
create policy "owner reads gift history" on artwork_storage_gift_history for select using(recipient_id=auth.uid()or is_owner_account());
create policy "config is readable" on artwork_storage_config for select using(auth.uid()is not null);

create or replace function public.artwork_storage_summary(p_stable uuid default auth.uid())returns jsonb language plpgsql stable security definer set search_path=public as $$
declare s stables;cfg artwork_storage_config;e artwork_storage_entitlements;sub boolean;used integer;base integer;bonus integer;unlim boolean;begin
 select * into s from stables where id=p_stable;if not found then raise exception 'Account not found';end if;
 if p_stable<>auth.uid()and not has_admin_permission('admin.accounts.view')then raise exception 'Administrator permission required';end if;
 select * into cfg from artwork_storage_config where id=true;select * into e from artwork_storage_entitlements where stable_id=p_stable;sub:=is_active_subscriber(p_stable);
 base:=case when sub then cfg.subscriber_base_capacity else cfg.free_base_capacity end;
 bonus:=case when coalesce(e.subscription_dependent,false)and not sub then 0 else coalesce(e.bonus_capacity,0)end;
 unlim:=s.account_number=1 or coalesce(e.unlimited,false);select count(*)into used from artwork_album_items where stable_id=p_stable and status in('reserved','active');
 return jsonb_build_object('stable_id',s.id,'account_number',s.account_number,'name',s.name,'subscriber',sub,'privilege',case when s.account_number=1 then'Owner'when unlim then'Special'when bonus>0 then coalesce(e.privilege,'Owner Granted')when sub then'Subscriber'else'None'end,'base_capacity',base,'bonus_capacity',bonus,'effective_capacity',case when unlim then null else base+bonus end,'unlimited',unlim,'current_usage',used,'over_capacity',not unlim and used>base+bonus,'max_upload_bytes',cfg.max_upload_bytes,'max_dimension',cfg.max_dimension,'allowed_mime_types',cfg.allowed_mime_types);
end$$;

create or replace function public.admin_artwork_storage_accounts()returns setof jsonb language plpgsql security definer set search_path=public as $$begin
 perform require_admin_permission('admin.accounts.view');return query select artwork_storage_summary(s.id)from stables s where s.account_number is not null order by s.account_number;end$$;
create or replace function public.owner_grant_artwork_storage(p_stable uuid,p_action text,p_amount integer default null,p_subscription_dependent boolean default false,p_reason text default '')returns jsonb language plpgsql security definer set search_path=public as $$
declare before_state jsonb;after_state jsonb;old artwork_storage_entitlements;begin
 if not is_owner_account()then raise exception 'Owner Account #1 access required';end if;if not exists(select 1 from stables where id=p_stable)then raise exception 'Account not found';end if;
 before_state:=artwork_storage_summary(p_stable);select * into old from artwork_storage_entitlements where stable_id=p_stable;
 insert into artwork_storage_entitlements(stable_id)values(p_stable)on conflict do nothing;
 if p_action='add'then if coalesce(p_amount,0)<=0 then raise exception 'Bonus must be positive';end if;update artwork_storage_entitlements set bonus_capacity=bonus_capacity+p_amount,unlimited=false,privilege='Owner Granted',subscription_dependent=p_subscription_dependent,note=left(p_reason,500),updated_by=auth.uid(),updated_at=now()where stable_id=p_stable;
 elsif p_action='set'then if coalesce(p_amount,-1)<0 then raise exception 'Capacity cannot be negative';end if;update artwork_storage_entitlements set bonus_capacity=p_amount,unlimited=false,privilege=case when p_amount=0 then'None'else'Owner Granted'end,subscription_dependent=p_subscription_dependent,note=left(p_reason,500),updated_by=auth.uid(),updated_at=now()where stable_id=p_stable;
 elsif p_action='unlimited'then update artwork_storage_entitlements set unlimited=true,privilege='Special',subscription_dependent=false,note=left(p_reason,500),updated_by=auth.uid(),updated_at=now()where stable_id=p_stable;
 elsif p_action='clear'then update artwork_storage_entitlements set bonus_capacity=0,unlimited=false,privilege='None',subscription_dependent=false,note=left(p_reason,500),updated_by=auth.uid(),updated_at=now()where stable_id=p_stable;
 else raise exception 'Choose add, set, unlimited, or clear';end if;
 after_state:=artwork_storage_summary(p_stable);insert into artwork_storage_gift_history(recipient_id,granted_by,previous_base,previous_bonus,previous_unlimited,change_description,new_base,new_bonus,new_unlimited,subscription_dependent,reason)values(p_stable,auth.uid(),(before_state->>'base_capacity')::int,(before_state->>'bonus_capacity')::int,(before_state->>'unlimited')::boolean,p_action||case when p_amount is null then''else' '||p_amount end,(after_state->>'base_capacity')::int,(after_state->>'bonus_capacity')::int,(after_state->>'unlimited')::boolean,p_subscription_dependent,left(p_reason,500));
 insert into admin_audit_log(actor_id,action_type,system,target_type,target_id,details)values(auth.uid(),'artwork_storage.'||p_action,'accounts','stable',p_stable::text,jsonb_build_object('before',before_state,'after',after_state,'reason',p_reason));return after_state;
end$$;
create or replace function public.owner_set_subscriber_artwork_capacity(p_capacity integer)returns void language plpgsql security definer set search_path=public as $$begin if not is_owner_account()then raise exception 'Owner Account #1 access required';end if;if p_capacity<0 then raise exception 'Capacity cannot be negative';end if;update artwork_storage_config set subscriber_base_capacity=p_capacity,updated_by=auth.uid(),updated_at=now()where id=true;insert into admin_audit_log(actor_id,action_type,system,details)values(auth.uid(),'artwork_storage.default_changed','accounts',jsonb_build_object('subscriber_base_capacity',p_capacity));end$$;

create or replace function public.reserve_artwork_album_upload(p_mime text,p_byte_size integer,p_extension text)returns jsonb language plpgsql security definer set search_path=public as $$
declare summary jsonb;cfg artwork_storage_config;item artwork_album_items;ext text;begin summary:=artwork_storage_summary(auth.uid());select * into cfg from artwork_storage_config where id=true;
 if p_mime<>all(cfg.allowed_mime_types)then raise exception 'Artwork must be a JPEG, PNG, or WebP image';end if;if p_byte_size<=0 or p_byte_size>cfg.max_upload_bytes then raise exception 'Artwork uploads must be 5 MB or smaller';end if;if not(summary->>'unlimited')::boolean and(summary->>'current_usage')::int>=(summary->>'effective_capacity')::int then raise exception 'Artwork Album is at capacity';end if;
 ext:=lower(regexp_replace(p_extension,'[^a-z0-9]','','g'));if ext not in('jpg','jpeg','png','webp')then raise exception 'Unsupported artwork file extension';end if;
 insert into artwork_album_items(stable_id,storage_path,mime_type,byte_size)values(auth.uid(),auth.uid()||'/artwork-album/'||gen_random_uuid()||'.'||ext,p_mime,p_byte_size)returning * into item;return jsonb_build_object('id',item.id,'storage_path',item.storage_path);end$$;
create or replace function public.finalize_artwork_album_upload(p_item uuid,p_width integer,p_height integer)returns jsonb language plpgsql security definer set search_path=public as $$declare cfg artwork_storage_config;item artwork_album_items;begin select * into cfg from artwork_storage_config where id=true;select * into item from artwork_album_items where id=p_item and stable_id=auth.uid()for update;if not found then raise exception 'Artwork reservation not found';end if;if p_width<=0 or p_height<=0 or p_width>cfg.max_dimension or p_height>cfg.max_dimension then raise exception 'Stored Artwork must be 1200 × 1200 pixels or smaller';end if;update artwork_album_items set width=p_width,height=p_height,status='active',finalized_at=now()where id=p_item returning * into item;return to_jsonb(item);end$$;
create or replace function public.remove_artwork_album_item(p_item uuid)returns void language plpgsql security definer set search_path=public as $$begin update artwork_album_items set status='removed',removed_at=now()where id=p_item and stable_id=auth.uid()and status<>'removed';if not found then raise exception 'Artwork not found';end if;end$$;

revoke all on function admin_artwork_storage_accounts(),owner_grant_artwork_storage(uuid,text,integer,boolean,text),owner_set_subscriber_artwork_capacity(integer),reserve_artwork_album_upload(text,integer,text),finalize_artwork_album_upload(uuid,integer,integer),remove_artwork_album_item(uuid)from public;
grant execute on function artwork_storage_summary(uuid),admin_artwork_storage_accounts(),owner_grant_artwork_storage(uuid,text,integer,boolean,text),owner_set_subscriber_artwork_capacity(integer),reserve_artwork_album_upload(text,integer,text),finalize_artwork_album_upload(uuid,integer,integer),remove_artwork_album_item(uuid)to authenticated;
