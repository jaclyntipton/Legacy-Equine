-- Permanent Owner Show capabilities and the secured Admin Show workspace.
create or replace function public.has_show_capability(p_capability text,p_user uuid default auth.uid()) returns boolean
language sql stable security definer set search_path=public as $$
 select exists(select 1 from stables where id=p_user and account_number=1)
 or public.has_admin_permission(case p_capability
  when 'shows.bulk_enter_all' then 'admin.shows.bulk_enter_all'
  when 'shows.bulk_create' then 'admin.shows.bulk_create'
  when 'shows.admin.edit' then 'admin.shows.edit'
  when 'shows.admin.lock' then 'admin.shows.lock'
  when 'shows.admin.run_now' then 'admin.shows.run'
  when 'shows.admin.cancel' then 'admin.shows.cancel'
  when 'shows.admin.preview' then 'admin.shows.preview'
  when 'shows.admin.duplicate' then 'admin.shows.duplicate'
  when 'shows.admin.qa' then 'admin.shows.qa'
  when 'shows.admin.private' then 'admin.shows.private'
  when 'shows.admin.processing' then 'admin.shows.processing'
  when 'shows.admin.audit' then 'admin.shows.audit'
  else '__unknown_show_capability__' end,p_user)
$$;

create or replace function public.get_show_capabilities() returns jsonb
language sql stable security definer set search_path=public as $$
 select jsonb_object_agg(capability,has_show_capability(capability)) from unnest(array[
  'shows.bulk_enter_all','shows.bulk_create','shows.admin.edit','shows.admin.lock',
  'shows.admin.run_now','shows.admin.cancel','shows.admin.preview','shows.admin.duplicate',
  'shows.admin.qa','shows.admin.private','shows.admin.processing','shows.admin.audit'
 ]) capability
$$;

alter table public.player_shows add column if not exists locked_at timestamptz;
alter table public.player_shows add column if not exists locked_by uuid references public.stables(id);
alter table public.player_shows add column if not exists is_private boolean not null default false;
alter table public.player_shows add column if not exists is_admin_qa boolean not null default false;
alter table public.player_shows add column if not exists cancelled_at timestamptz;
alter table public.player_shows add column if not exists cancelled_by uuid references public.stables(id);
alter table public.player_shows add column if not exists cancellation_reason text;
alter table public.player_shows add column if not exists duplicated_from uuid references public.player_shows(id);

create table if not exists public.show_admin_audit(
 id uuid primary key default gen_random_uuid(),show_id uuid references public.player_shows(id),
 actor_id uuid not null references public.stables(id),action text not null,details jsonb not null default '{}',
 created_at timestamptz not null default now()
);
alter table public.show_admin_audit enable row level security;
create policy "show auditors read audit" on public.show_admin_audit for select using(has_show_capability('shows.admin.audit'));

create table if not exists public.show_qa_allowlist(
 stable_id uuid primary key references public.stables(id),granted_by uuid not null references public.stables(id),
 active boolean not null default true,note text not null default '',created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
alter table public.show_qa_allowlist enable row level security;
create policy "show qa admins read allowlist" on public.show_qa_allowlist for select using(has_show_capability('shows.admin.qa'));

create or replace function public.admin_show_workspace() returns jsonb
language plpgsql stable security definer set search_path=public as $$
begin
 if not (has_admin_permission('admin.shows.view') or has_show_capability('shows.admin.processing') or has_show_capability('shows.admin.edit')) then raise exception 'Show administration permission required';end if;
 return jsonb_build_object(
  'shows',coalesce((select jsonb_agg(jsonb_build_object('id',sh.id,'name',sh.name,'discipline_id',sh.discipline_id,'discipline',d.name,'tier_id',sh.tier_id,'tier',t.name,'run_at',sh.run_at,'run_date',sh.run_date,'entry_fee',sh.entry_fee,'max_entries',sh.max_entries,'description',sh.description,'status',sh.status,'entry_count',(select count(*) from player_show_entries e where e.show_id=sh.id),'purse',sh.entry_fee_purse+sh.show_fund_allocation+sh.treasury_allocation,'locked',sh.locked_at is not null,'is_private',sh.is_private,'is_admin_qa',sh.is_admin_qa,'processed_at',sh.processed_at,'cancelled_at',sh.cancelled_at) order by sh.run_at desc) from player_shows sh join show_disciplines d on d.id=sh.discipline_id join show_tiers t on t.id=sh.tier_id),'[]'::jsonb),
  'audit',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'show_id',a.show_id,'show_name',sh.name,'actor',s.name,'actor_account',s.account_number,'action',a.action,'details',a.details,'created_at',a.created_at) order by a.created_at desc) from show_admin_audit a left join player_shows sh on sh.id=a.show_id join stables s on s.id=a.actor_id limit 300),'[]'::jsonb),
  'allowlist',coalesce((select jsonb_agg(jsonb_build_object('stable_id',q.stable_id,'name',s.name,'account_number',s.account_number,'active',q.active,'note',q.note) order by s.account_number) from show_qa_allowlist q join stables s on s.id=q.stable_id),'[]'::jsonb),
  'capabilities',get_show_capabilities()
 );
end$$;

create or replace function public.admin_preview_show_results(p_show uuid) returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare sh player_shows;weights jsonb;
begin
 if not has_show_capability('shows.admin.preview') then raise exception 'Show preview permission required';end if;
 select * into sh from player_shows where id=p_show;if not found then raise exception 'Show not found';end if;
 select stat_weights into weights from show_disciplines where id=sh.discipline_id;
 return jsonb_build_object('show_id',sh.id,'show_name',sh.name,'side_effects',false,'entries',coalesce((select jsonb_agg(x order by score desc,base_score desc,career_points_snapshot desc,entered_at,horse_id) from(select e.horse_id,e.horse_name_snapshot horse_name,e.owner_name_snapshot owner_name,e.career_points_snapshot,e.entered_at,(select sum((b.value->>'effective')::numeric*(w.value::text)::numeric)/nullif(sum((w.value::text)::numeric),0) from jsonb_each(show_score_breakdown(e.horse_id,weights,sh.run_at)) b join jsonb_each(weights) w on w.key=b.key) score,(select sum(((b.value->>'base')::numeric+(b.value->>'training')::numeric)*(w.value::text)::numeric)/nullif(sum((w.value::text)::numeric),0) from jsonb_each(show_score_breakdown(e.horse_id,weights,sh.run_at)) b join jsonb_each(weights) w on w.key=b.key) base_score from player_show_entries e where e.show_id=sh.id)x),'[]'::jsonb));
end$$;

create or replace function public.admin_show_action(p_show uuid,p_action text,p_changes jsonb default '{}') returns jsonb
language plpgsql security definer set search_path=public as $$
declare sh player_shows;new_id uuid;result jsonb;
begin
 select * into sh from player_shows where id=p_show for update;if not found then raise exception 'Show not found';end if;
 if p_action='lock' or p_action='unlock' then
  if not has_show_capability('shows.admin.lock') then raise exception 'Show lock permission required';end if;
  if sh.status<>'open' then raise exception 'Only open Shows can be locked or unlocked';end if;
  update player_shows set locked_at=case when p_action='lock' then now() else null end,locked_by=case when p_action='lock' then auth.uid() else null end where id=sh.id;
 elsif p_action='cancel' then
  if not has_show_capability('shows.admin.cancel') then raise exception 'Show cancellation permission required';end if;
  if sh.status not in('open','processing') then raise exception 'This Show cannot be cancelled';end if;
  update player_shows set status='cancelled',cancelled_at=now(),cancelled_by=auth.uid(),cancellation_reason=left(coalesce(p_changes->>'reason','Owner cancelled'),300) where id=sh.id;
 elsif p_action='edit' then
  if not has_show_capability('shows.admin.edit') then raise exception 'Show editing permission required';end if;
  if sh.status<>'open' then raise exception 'Only open Shows can be edited';end if;
  update player_shows set name=left(coalesce(nullif(trim(p_changes->>'name'),''),name),80),description=left(coalesce(p_changes->>'description',description),1000),run_at=coalesce((p_changes->>'run_at')::timestamptz,run_at),run_date=coalesce((p_changes->>'run_at')::timestamptz::date,run_date),max_entries=coalesce((p_changes->>'max_entries')::integer,max_entries) where id=sh.id;
 elsif p_action in('duplicate','duplicate_test') then
  if not has_show_capability('shows.admin.duplicate') then raise exception 'Show duplication permission required';end if;
  if p_action='duplicate_test' and not has_show_capability('shows.admin.qa') then raise exception 'Show QA permission required';end if;
  insert into player_shows(creator_id,name,discipline_id,tier_id,run_date,run_at,entry_fee,max_entries,maximum_per_owner,description,is_private,is_admin_qa,duplicated_from)
  values(auth.uid(),left(sh.name||case when p_action='duplicate_test' then ' — QA Test' else ' — Copy' end,80),sh.discipline_id,sh.tier_id,greatest(current_date+1,sh.run_date+1),(greatest(current_date+1,sh.run_date+1)::timestamp at time zone 'America/New_York'),sh.entry_fee,sh.max_entries,sh.maximum_per_owner,sh.description,case when p_action='duplicate_test' then true else sh.is_private end,case when p_action='duplicate_test' then true else sh.is_admin_qa end,sh.id) returning id into new_id;
 elsif p_action='run_now' then
  if not has_show_capability('shows.admin.run_now') then raise exception 'Run Show permission required';end if;
  if sh.status<>'open' then raise exception 'Only an open Show can run';end if;
  update player_shows set locked_at=coalesce(locked_at,now()),locked_by=coalesce(locked_by,auth.uid()),run_at=least(run_at,now()) where id=sh.id;
  perform process_due_player_shows();
  if not exists(select 1 from player_shows where id=sh.id and status='complete') then raise exception 'Show processing did not complete';end if;
 else raise exception 'Unknown Show action';end if;
 insert into show_admin_audit(show_id,actor_id,action,details) values(sh.id,auth.uid(),p_action,coalesce(p_changes,'{}'));
 select jsonb_build_object('show_id',sh.id,'action',p_action,'duplicate_id',new_id,'status',(select status from player_shows where id=sh.id)) into result;return result;
end$$;

create or replace function public.preview_show_entries(p_pairs jsonb) returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_progress jsonb;v_item jsonb;v_show player_shows;v_horse horses;v_eligible jsonb:='[]';v_skipped jsonb:='[]';v_fee bigint:=0;v_count integer;v_seen text[]:='{}';v_key text;v_selected jsonb:='{}';v_selected_for_show integer;
begin
 v_progress:=get_account_progression();
 if (select count(distinct x->>'show_id') from jsonb_array_elements(coalesce(p_pairs,'[]')) x)>1 and not ((v_progress->>'advanced_bulk_entry')::boolean or has_show_capability('shows.bulk_enter_all')) then raise exception 'Multiple-Show entry is not available for this account';end if;
 for v_item in select * from jsonb_array_elements(coalesce(p_pairs,'[]')) loop
  v_key:=(v_item->>'show_id')||':'||(v_item->>'horse_id');if v_key=any(v_seen) then continue;end if;v_seen:=array_append(v_seen,v_key);
  select * into v_show from player_shows where id=(v_item->>'show_id')::uuid;select * into v_horse from horses where id=(v_item->>'horse_id')::uuid and owner_id=auth.uid();
  if v_show.id is null or v_horse.id is null then v_skipped:=v_skipped||jsonb_build_array(v_item||jsonb_build_object('reason','Horse or Show unavailable'));
  elsif v_show.status<>'open' or v_show.run_at<=now() then v_skipped:=v_skipped||jsonb_build_array(v_item||jsonb_build_object('horse_name',v_horse.name,'show_name',v_show.name,'reason','Show is closed'));
  elsif v_show.locked_at is not null then v_skipped:=v_skipped||jsonb_build_array(v_item||jsonb_build_object('horse_name',v_horse.name,'show_name',v_show.name,'reason','Entries are locked'));
  elsif v_show.is_private and not (has_show_capability('shows.admin.qa') or exists(select 1 from show_qa_allowlist q where q.stable_id=auth.uid() and q.active)) then v_skipped:=v_skipped||jsonb_build_array(v_item||jsonb_build_object('horse_name',v_horse.name,'show_name',v_show.name,'reason','Private test Show'));
  elsif exists(select 1 from player_show_entries e where e.show_id=v_show.id and e.horse_id=v_horse.id) then v_skipped:=v_skipped||jsonb_build_array(v_item||jsonb_build_object('horse_name',v_horse.name,'show_name',v_show.name,'reason','Already entered'));
  elsif v_horse.sanctuary_retired_at is not null then v_skipped:=v_skipped||jsonb_build_array(v_item||jsonb_build_object('horse_name',v_horse.name,'show_name',v_show.name,'reason','Horse is retired to Sanctuary'));
  elsif get_horse_competition_tier(v_horse.career_points)<>v_show.tier_id then v_skipped:=v_skipped||jsonb_build_array(v_item||jsonb_build_object('horse_name',v_horse.name,'show_name',v_show.name,'reason','Career Point tier'));
  else select count(*) into v_count from player_show_entries where show_id=v_show.id;v_selected_for_show:=coalesce((v_selected->>v_show.id::text)::integer,0);if v_show.max_entries is not null and v_count+v_selected_for_show>=v_show.max_entries then v_skipped:=v_skipped||jsonb_build_array(v_item||jsonb_build_object('horse_name',v_horse.name,'show_name',v_show.name,'reason','Show is full'));
  else v_eligible:=v_eligible||jsonb_build_array(v_item||jsonb_build_object('horse_name',v_horse.name,'show_name',v_show.name,'fee',v_show.entry_fee));v_fee:=v_fee+v_show.entry_fee;v_selected:=jsonb_set(v_selected,array[v_show.id::text],to_jsonb(v_selected_for_show+1),true);end if;end if;
 end loop;
 return jsonb_build_object('eligible',v_eligible,'skipped',v_skipped,'total_fee',v_fee,'balance',(select balance from stables where id=auth.uid()),'previewed_at',now());
end$$;

drop function if exists public.get_player_shows();
create function public.get_player_shows() returns table(id uuid,name text,discipline text,tier text,run_at timestamptz,entry_fee bigint,max_entries integer,entry_count bigint,description text,creator_name text,creator_account bigint,status text,discipline_id text,tier_id text,purse bigint,creator_id uuid) language sql security definer set search_path=public stable as $$
select sh.id,sh.name,d.name,t.name,sh.run_at,sh.entry_fee,sh.max_entries,count(e.id),sh.description,s.name,s.account_number,sh.status,sh.discipline_id,sh.tier_id,sh.entry_fee_purse+sh.show_fund_allocation+sh.treasury_allocation,sh.creator_id from player_shows sh join show_disciplines d on d.id=sh.discipline_id join show_tiers t on t.id=sh.tier_id join stables s on s.id=sh.creator_id left join player_show_entries e on e.show_id=sh.id where sh.status in('open','complete') and(not sh.is_private or has_show_capability('shows.admin.qa') or exists(select 1 from show_qa_allowlist q where q.stable_id=auth.uid() and q.active)) group by sh.id,d.name,t.name,s.name,s.account_number order by sh.run_at
$$;

create or replace function public.admin_set_show_qa_access(p_stable uuid,p_active boolean,p_note text default '') returns void
language plpgsql security definer set search_path=public as $$begin
 if not has_show_capability('shows.admin.qa') then raise exception 'Show QA permission required';end if;
 insert into show_qa_allowlist(stable_id,granted_by,active,note) values(p_stable,auth.uid(),p_active,left(coalesce(p_note,''),300)) on conflict(stable_id) do update set active=excluded.active,note=excluded.note,granted_by=auth.uid(),updated_at=now();
 insert into show_admin_audit(actor_id,action,details) values(auth.uid(),'qa_allowlist',jsonb_build_object('stable_id',p_stable,'active',p_active,'note',p_note));
end$$;

revoke all on function public.has_show_capability(text,uuid),public.get_show_capabilities(),public.admin_show_workspace(),public.admin_preview_show_results(uuid),public.admin_show_action(uuid,text,jsonb),public.admin_set_show_qa_access(uuid,boolean,text),public.preview_show_entries(jsonb),public.get_player_shows() from public;
grant execute on function public.has_show_capability(text,uuid),public.get_show_capabilities(),public.admin_show_workspace(),public.admin_preview_show_results(uuid),public.admin_show_action(uuid,text,jsonb),public.admin_set_show_qa_access(uuid,boolean,text),public.preview_show_entries(jsonb),public.get_player_shows() to authenticated;
