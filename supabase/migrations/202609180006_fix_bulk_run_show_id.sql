-- Remove PL/pgSQL variable/column collisions from the production bulk Show path.
create or replace function public.admin_bulk_preview_shows(p_shows uuid[],p_qa boolean default false)returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare v_show_id uuid;v_show player_shows;v_item jsonb;v_items jsonb:='[]';v_eligible integer:=0;v_invalid integer:=0;v_reason text;v_score_preview jsonb;
begin
 if not has_show_capability('shows.admin.bulk_run')then raise exception 'Bulk Run Shows permission required';end if;
 if p_qa and not has_show_capability('shows.admin.qa')then raise exception 'Show QA permission required';end if;
 foreach v_show_id in array coalesce(p_shows,'{}'::uuid[])loop
  select ps.* into v_show from player_shows as ps where ps.id=v_show_id;v_reason:=null;v_score_preview:=null;
  if v_show.id is null then v_reason:='Show not found';
  elsif v_show.status='complete'then v_reason:='Already completed';
  elsif v_show.status='processing'then v_reason:='Already processing';
  elsif v_show.status<>'open'then v_reason:='Show is not open';
  elsif p_qa and not(v_show.is_private or v_show.is_admin_qa)then v_reason:='Not a private/test Show';
  elsif not p_qa and(v_show.is_private or v_show.is_admin_qa)then v_reason:='Private/test Show must use QA bulk run';
  end if;
  if v_reason is null then v_eligible:=v_eligible+1;v_score_preview:=admin_preview_show_results(v_show.id);else v_invalid:=v_invalid+1;end if;
  v_item:=jsonb_build_object('show_id',v_show_id,'name',coalesce(v_show.name,'Unavailable Show'),'discipline',(select sd.name from show_disciplines as sd where sd.id=v_show.discipline_id),'tier',(select st.name from show_tiers as st where st.id=v_show.tier_id),'run_at',v_show.run_at,'entry_count',(select count(*)from player_show_entries as pse where pse.show_id=v_show.id),'purse',coalesce(v_show.entry_fee_purse,0)+coalesce(v_show.show_fund_allocation,0)+coalesce(v_show.treasury_allocation,0),'eligible',v_reason is null,'reason',v_reason,'results',coalesce(v_score_preview->'entries','[]'::jsonb));v_items:=v_items||jsonb_build_array(v_item);
 end loop;
 return jsonb_build_object('requested',coalesce(cardinality(p_shows),0),'eligible',v_eligible,'cannot_run',v_invalid,'qa_only',p_qa,'side_effects',false,'shows',v_items);
end$$;

create or replace function public.admin_bulk_run_shows(p_shows uuid[],p_request_key uuid,p_qa boolean default false)returns jsonb
language plpgsql security definer set search_path=public as $$
declare v_batch_id uuid;v_prior jsonb;v_show_id uuid;v_show player_shows;v_items jsonb:='[]';v_completed integer:=0;v_skipped integer:=0;v_reason text;v_preview jsonb;v_batch_result jsonb;
begin
 if not has_show_capability('shows.admin.bulk_run')then raise exception 'Bulk Run Shows permission required';end if;
 if p_qa and not has_show_capability('shows.admin.qa')then raise exception 'Show QA permission required';end if;
 select sbr.result into v_prior from show_bulk_runs as sbr where sbr.request_key=p_request_key and sbr.actor_id=auth.uid()and sbr.completed_at is not null;if v_prior is not null then return v_prior||jsonb_build_object('idempotent',true);end if;
 insert into show_bulk_runs(request_key,actor_id,qa_only,requested_count)values(p_request_key,auth.uid(),p_qa,coalesce(cardinality(p_shows),0))on conflict(request_key)do nothing returning id into v_batch_id;
 if v_batch_id is null then select sbr.result into v_prior from show_bulk_runs as sbr where sbr.request_key=p_request_key and sbr.actor_id=auth.uid();return coalesce(v_prior,jsonb_build_object('requested',coalesce(cardinality(p_shows),0),'completed',0,'skipped',coalesce(cardinality(p_shows),0),'processing',true,'shows','[]'::jsonb))||jsonb_build_object('idempotent',true);end if;
 foreach v_show_id in array coalesce(p_shows,'{}'::uuid[])loop
  v_reason:=null;v_preview:=null;v_show:=null;
  begin
   select ps.* into v_show from player_shows as ps where ps.id=v_show_id for update;
   if v_show.id is null then v_reason:='Show not found';elsif v_show.status='complete'then v_reason:='Already completed';elsif v_show.status='processing'then v_reason:='Already processing';elsif v_show.status<>'open'then v_reason:='Show is not open';elsif p_qa and not(v_show.is_private or v_show.is_admin_qa)then v_reason:='Not a private/test Show';elsif not p_qa and(v_show.is_private or v_show.is_admin_qa)then v_reason:='Private/test Show must use QA bulk run';end if;
   if v_reason is null and p_qa then
    v_preview:=admin_preview_show_results(v_show.id);v_completed:=v_completed+1;
    insert into show_admin_audit(show_id,actor_id,action,details)values(v_show.id,auth.uid(),'bulk_qa_preview',jsonb_build_object('batch_id',v_batch_id,'side_effects',false));
   elsif v_reason is null then
    update player_shows as ps set locked_at=coalesce(ps.locked_at,now()),locked_by=coalesce(ps.locked_by,auth.uid()),run_at=least(ps.run_at,now())where ps.id=v_show.id;
    perform process_due_player_shows();
    if exists(select 1 from player_shows as ps where ps.id=v_show.id and ps.status='complete')then v_completed:=v_completed+1;insert into show_admin_audit(show_id,actor_id,action,details)values(v_show.id,auth.uid(),'bulk_run_completed',jsonb_build_object('batch_id',v_batch_id));else v_reason:='Show processing did not complete';end if;
   end if;
  exception when others then v_reason:=sqlerrm;
  end;
  if v_reason is not null then v_skipped:=v_skipped+1;end if;
  v_items:=v_items||jsonb_build_array(jsonb_build_object('show_id',v_show_id,'name',coalesce(v_show.name,'Unavailable Show'),'status',case when v_reason is null then case when p_qa then'previewed'else'completed'end else'skipped'end,'reason',v_reason,'results',coalesce(v_preview->'entries','[]'::jsonb)));
 end loop;
 v_batch_result:=jsonb_build_object('batch_id',v_batch_id,'requested',coalesce(cardinality(p_shows),0),'completed',v_completed,'skipped',v_skipped,'qa_only',p_qa,'side_effects',not p_qa,'shows',v_items);
 update show_bulk_runs as sbr set completed_count=v_completed,skipped_count=v_skipped,result=v_batch_result,completed_at=now()where sbr.id=v_batch_id;
 insert into show_admin_audit(actor_id,action,details)values(auth.uid(),case when p_qa then'bulk_qa_completed'else'bulk_run_completed'end,v_batch_result-'shows');return v_batch_result;
end$$;

revoke all on function public.admin_bulk_preview_shows(uuid[],boolean),public.admin_bulk_run_shows(uuid[],uuid,boolean)from public;
grant execute on function public.admin_bulk_preview_shows(uuid[],boolean),public.admin_bulk_run_shows(uuid[],uuid,boolean)to authenticated;
