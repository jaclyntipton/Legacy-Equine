-- Resolve the production PL/pgSQL variable/column collision in the shared
-- manual + scheduled Auto Host runner. Then verify the production maintain
-- path and restore the exact schedule state captured by the safety pause.

create or replace function public.run_show_auto_host(p_cycle_key text,p_trigger text,p_actor uuid default null)returns jsonb language plpgsql security definer set search_path=public as $$
declare c show_auto_host_config;run_id uuid;prior jsonb;owner_id uuid;plan jsonb;item jsonb;i integer;wanted integer;created integer:=0;skipped integer:=0;errors integer:=0;evaluated integer:=0;created_ids uuid[]:='{}';show_id uuid;show_name text;names text[];run_day date;run_at_time timestamptz;fee bigint;purse bigint;fund system_funds;v_result jsonb;
begin
 if p_trigger not in('scheduled','manual')then raise exception'Invalid Auto Host trigger';end if;if p_trigger='manual'and not has_show_capability('shows.admin.auto_host',coalesce(p_actor,auth.uid()))then raise exception'Auto Host permission required';end if;
 select * into c from show_auto_host_config where id=true for update;if p_trigger='scheduled'and(not c.enabled or not c.daily_enabled)then return jsonb_build_object('status','off','created',0);end if;
 select r.result into prior from show_auto_host_runs as r where r.cycle_key=p_cycle_key and r.completed_at is not null;if prior is not null then return prior||jsonb_build_object('idempotent',true);end if;
 select s.id into owner_id from stables as s where s.account_number=1;if owner_id is null then raise exception'Owner Account #1 not found';end if;
 insert into show_auto_host_runs(cycle_key,trigger,actor_id,scheduled_for)values(p_cycle_key,p_trigger,coalesce(p_actor,owner_id),now())on conflict(cycle_key)do nothing returning id into run_id;
 if run_id is null then return jsonb_build_object('status','processing_or_complete','idempotent',true,'created',0);end if;
 plan:=show_auto_host_plan();run_day:=(now()at time zone c.timezone)::date+c.run_delay_days;run_at_time:=(run_day::timestamp at time zone c.timezone);
 for item in select value from jsonb_array_elements(plan->'items')as planned(value)loop wanted:=(item->>'would_create')::integer;evaluated:=evaluated+1;if wanted=0 then skipped:=skipped+1;continue;end if;
  for i in 1..wanted loop begin
   fee:=case when c.use_show_defaults then 0 else(item->>'entry_fee')::bigint end;purse:=case when c.use_show_defaults then 0 else(item->>'base_purse')::bigint end;
   select p.names into names from show_auto_host_name_pools as p where p.discipline_id=item->>'discipline_id';show_name:=coalesce(names[1+mod(created+i-1,greatest(cardinality(names),1))],'Legacy '||(item->>'discipline')||' Classic');
   if exists(select 1 from player_shows as existing_show where existing_show.name=show_name and existing_show.run_date=run_day)then show_name:=left(show_name||' '||(select count(*)+1 from player_shows as same_name where same_name.name like show_name||'%'and same_name.run_date=run_day),80);end if;
   if purse>0 then select * into fund from system_funds as sf where sf.id='show_fund'for update;if fund.balance<purse then raise exception'Show Fund balance is insufficient for configured purse';end if;update system_funds as sf set balance=sf.balance-purse,lifetime_outflow=sf.lifetime_outflow+purse where sf.id='show_fund';end if;
   insert into player_shows(creator_id,name,discipline_id,tier_id,run_date,run_at,entry_fee,max_entries,maximum_per_owner,description,show_fund_allocation,source,auto_host_run_id)
   values(owner_id,show_name,item->>'discipline_id',item->>'tier_id',run_day,run_at_time,fee,null,2147483647,'Hosted by Legacy Equine · Source: Auto Host',purse,'auto_host',run_id)returning id into show_id;
   if purse>0 then insert into system_fund_ledger(fund_id,amount,transaction_type,source,destination,initiated_by,reason,related_id)values('show_fund',-purse,'show_funding','LE Show Fund',show_name,owner_id,'Auto Host configured base purse',show_id);end if;
   created:=created+1;created_ids:=array_append(created_ids,show_id);
  exception when others then errors:=errors+1;end;end loop;
 end loop;
 v_result:=jsonb_build_object('run_id',run_id,'cycle_key',p_cycle_key,'trigger',p_trigger,'evaluated',evaluated,'created',created,'skipped',skipped,'errors',errors,'show_ids',created_ids,'run_at',run_at_time,'idempotent',false);
 update show_auto_host_runs as r set shows_evaluated=evaluated,shows_created=created,shows_skipped=skipped,error_count=errors,result=v_result,completed_at=now()where r.id=run_id;
 insert into show_admin_audit(actor_id,action,details)values(coalesce(p_actor,owner_id),'auto_host_'||p_trigger,v_result-'show_ids');return v_result;
end$$;

do $$
declare owner_id uuid;before_count bigint;after_preview_count bigint;plan jsonb;first_run jsonb;second_run jsonb;saved show_auto_host_repair_state;
begin
 select * into saved from show_auto_host_repair_state where id=true;
 if not found then raise exception'Auto Host repair safety state is missing';end if;
 select s.id into owner_id from stables as s where s.account_number=1;
 select count(*)into before_count from player_shows;
 plan:=show_auto_host_plan();
 select count(*)into after_preview_count from player_shows;
 if after_preview_count<>before_count then raise exception'Auto Host preview/plan created Shows';end if;
 if(plan->>'quantity_mode')<>'maintain'then raise exception'Production Auto Host is not in Maintain Target Availability mode';end if;
 first_run:=run_show_auto_host('repair-result-ambiguity-first-20260918','manual',owner_id);
 if coalesce((first_run->>'errors')::integer,0)<>0 then raise exception'Controlled Auto Host run produced errors: %',first_run;end if;
 second_run:=run_show_auto_host('repair-result-ambiguity-second-20260918','manual',owner_id);
 if coalesce((second_run->>'errors')::integer,0)<>0 or coalesce((second_run->>'created')::integer,0)<>0 then raise exception'Maintain-X verification created unnecessary Shows: %',second_run;end if;
 update show_auto_host_config as c set enabled=saved.was_enabled,daily_enabled=saved.was_daily_enabled,updated_at=now()where c.id=true;
 update show_auto_host_repair_state set restored_at=now()where id=true;
 insert into show_admin_audit(actor_id,action,details)values(owner_id,'auto_host_result_repair_verified',jsonb_build_object('preview_side_effects',false,'plan_would_create',plan->'would_create','first_run',first_run-'show_ids','second_run',second_run-'show_ids','restored_enabled',saved.was_enabled,'restored_daily_enabled',saved.was_daily_enabled));
end$$;

revoke all on function public.run_show_auto_host(text,text,uuid)from public;
grant execute on function public.run_show_auto_host(text,text,uuid)to service_role;
