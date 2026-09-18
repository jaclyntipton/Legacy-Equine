-- Bulk orchestration over the existing authoritative Show preview/runner.
create table public.show_bulk_runs(
 id uuid primary key default gen_random_uuid(),request_key uuid not null unique,
 actor_id uuid not null references public.stables(id),qa_only boolean not null default false,
 requested_count integer not null,completed_count integer not null default 0,skipped_count integer not null default 0,
 result jsonb not null default '{}',created_at timestamptz not null default now(),completed_at timestamptz
);
alter table public.show_bulk_runs enable row level security;
create policy "bulk show runners read own batches" on public.show_bulk_runs for select using(actor_id=auth.uid()or public.has_show_capability('shows.admin.audit'));

create or replace function public.has_show_capability(p_capability text,p_user uuid default auth.uid())returns boolean
language sql stable security definer set search_path=public as $$
 select exists(select 1 from stables where id=p_user and account_number=1)
 or public.has_admin_permission(case p_capability
  when'shows.bulk_enter_all'then'admin.shows.bulk_enter_all' when'shows.bulk_create'then'admin.shows.bulk_create'
  when'shows.admin.bulk_run'then'admin.shows.bulk_run' when'shows.admin.edit'then'admin.shows.edit'
  when'shows.admin.lock'then'admin.shows.lock' when'shows.admin.run_now'then'admin.shows.run'
  when'shows.admin.cancel'then'admin.shows.cancel' when'shows.admin.preview'then'admin.shows.preview'
  when'shows.admin.duplicate'then'admin.shows.duplicate' when'shows.admin.qa'then'admin.shows.qa'
  when'shows.admin.private'then'admin.shows.private' when'shows.admin.processing'then'admin.shows.processing'
  when'shows.admin.audit'then'admin.shows.audit' else'__unknown_show_capability__'end,p_user)
$$;

create or replace function public.get_show_capabilities()returns jsonb language sql stable security definer set search_path=public as $$
 select jsonb_object_agg(capability,has_show_capability(capability))from unnest(array[
  'shows.bulk_enter_all','shows.bulk_create','shows.admin.bulk_run','shows.admin.edit','shows.admin.lock',
  'shows.admin.run_now','shows.admin.cancel','shows.admin.preview','shows.admin.duplicate','shows.admin.qa',
  'shows.admin.private','shows.admin.processing','shows.admin.audit'])capability
$$;

create or replace function public.admin_bulk_preview_shows(p_shows uuid[],p_qa boolean default false)returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare show_id uuid;sh player_shows;item jsonb;items jsonb:='[]';eligible integer:=0;invalid integer:=0;reason text;score_preview jsonb;
begin
 if not has_show_capability('shows.admin.bulk_run')then raise exception 'Bulk Run Shows permission required';end if;
 if p_qa and not has_show_capability('shows.admin.qa')then raise exception 'Show QA permission required';end if;
 foreach show_id in array coalesce(p_shows,'{}'::uuid[])loop
  select * into sh from player_shows where id=show_id;reason:=null;score_preview:=null;
  if sh.id is null then reason:='Show not found';
  elsif sh.status='complete'then reason:='Already completed';
  elsif sh.status='processing'then reason:='Already processing';
  elsif sh.status<>'open'then reason:='Show is not open';
  elsif p_qa and not(sh.is_private or sh.is_admin_qa)then reason:='Not a private/test Show';
  elsif not p_qa and(sh.is_private or sh.is_admin_qa)then reason:='Private/test Show must use QA bulk run';
  end if;
  if reason is null then eligible:=eligible+1;score_preview:=admin_preview_show_results(sh.id);else invalid:=invalid+1;end if;
  item:=jsonb_build_object('show_id',show_id,'name',coalesce(sh.name,'Unavailable Show'),'discipline',(select name from show_disciplines where id=sh.discipline_id),'tier',(select name from show_tiers where id=sh.tier_id),'run_at',sh.run_at,'entry_count',(select count(*)from player_show_entries where show_id=sh.id),'purse',coalesce(sh.entry_fee_purse,0)+coalesce(sh.show_fund_allocation,0)+coalesce(sh.treasury_allocation,0),'eligible',reason is null,'reason',reason,'results',coalesce(score_preview->'entries','[]'::jsonb));items:=items||jsonb_build_array(item);
 end loop;
 return jsonb_build_object('requested',coalesce(cardinality(p_shows),0),'eligible',eligible,'cannot_run',invalid,'qa_only',p_qa,'side_effects',false,'shows',items);
end$$;

create or replace function public.admin_bulk_run_shows(p_shows uuid[],p_request_key uuid,p_qa boolean default false)returns jsonb
language plpgsql security definer set search_path=public as $$
declare batch_id uuid;prior jsonb;show_id uuid;sh player_shows;items jsonb:='[]';completed integer:=0;skipped integer:=0;reason text;preview jsonb;batch_result jsonb;
begin
 if not has_show_capability('shows.admin.bulk_run')then raise exception 'Bulk Run Shows permission required';end if;
 if p_qa and not has_show_capability('shows.admin.qa')then raise exception 'Show QA permission required';end if;
 select r.result into prior from show_bulk_runs r where r.request_key=p_request_key and r.actor_id=auth.uid()and r.completed_at is not null;if prior is not null then return prior||jsonb_build_object('idempotent',true);end if;
 insert into show_bulk_runs(request_key,actor_id,qa_only,requested_count)values(p_request_key,auth.uid(),p_qa,coalesce(cardinality(p_shows),0))on conflict(request_key)do nothing returning id into batch_id;
 if batch_id is null then select r.result into prior from show_bulk_runs r where r.request_key=p_request_key and r.actor_id=auth.uid();return coalesce(prior,jsonb_build_object('requested',coalesce(cardinality(p_shows),0),'completed',0,'skipped',coalesce(cardinality(p_shows),0),'processing',true,'shows','[]'::jsonb))||jsonb_build_object('idempotent',true);end if;
 foreach show_id in array coalesce(p_shows,'{}'::uuid[])loop
  reason:=null;preview:=null;
  begin
   select * into sh from player_shows where id=show_id for update;
   if sh.id is null then reason:='Show not found';elsif sh.status='complete'then reason:='Already completed';elsif sh.status='processing'then reason:='Already processing';elsif sh.status<>'open'then reason:='Show is not open';elsif p_qa and not(sh.is_private or sh.is_admin_qa)then reason:='Not a private/test Show';elsif not p_qa and(sh.is_private or sh.is_admin_qa)then reason:='Private/test Show must use QA bulk run';end if;
   if reason is null and p_qa then
    preview:=admin_preview_show_results(sh.id);completed:=completed+1;
    insert into show_admin_audit(show_id,actor_id,action,details)values(sh.id,auth.uid(),'bulk_qa_preview',jsonb_build_object('batch_id',batch_id,'side_effects',false));
   elsif reason is null then
    update player_shows set locked_at=coalesce(locked_at,now()),locked_by=coalesce(locked_by,auth.uid()),run_at=least(run_at,now())where id=sh.id;
    perform process_due_player_shows();
    if exists(select 1 from player_shows where id=sh.id and status='complete')then completed:=completed+1;insert into show_admin_audit(show_id,actor_id,action,details)values(sh.id,auth.uid(),'bulk_run_completed',jsonb_build_object('batch_id',batch_id));else reason:='Show processing did not complete';end if;
   end if;
  exception when others then reason:=sqlerrm;
  end;
  if reason is not null then skipped:=skipped+1;end if;
  items:=items||jsonb_build_array(jsonb_build_object('show_id',show_id,'name',coalesce(sh.name,'Unavailable Show'),'status',case when reason is null then case when p_qa then'previewed'else'completed'end else'skipped'end,'reason',reason,'results',coalesce(preview->'entries','[]'::jsonb)));
 end loop;
 batch_result:=jsonb_build_object('batch_id',batch_id,'requested',coalesce(cardinality(p_shows),0),'completed',completed,'skipped',skipped,'qa_only',p_qa,'side_effects',not p_qa,'shows',items);
 update show_bulk_runs set completed_count=completed,skipped_count=skipped,result=batch_result,completed_at=now()where id=batch_id;
 insert into show_admin_audit(actor_id,action,details)values(auth.uid(),case when p_qa then'bulk_qa_completed'else'bulk_run_completed'end,batch_result-'shows');return batch_result;
end$$;

revoke all on function public.admin_bulk_preview_shows(uuid[],boolean),public.admin_bulk_run_shows(uuid[],uuid,boolean)from public;
grant execute on function public.admin_bulk_preview_shows(uuid[],boolean),public.admin_bulk_run_shows(uuid[],uuid,boolean)to authenticated;
