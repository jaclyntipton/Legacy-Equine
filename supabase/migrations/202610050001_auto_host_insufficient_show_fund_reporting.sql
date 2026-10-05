-- Report Auto Host funding shortages explicitly instead of hiding them as
-- one swallowed per-show error for every attempted show creation.
create or replace function public.run_show_auto_host(p_cycle_key text,p_trigger text,p_actor uuid default null)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  c show_auto_host_config;
  v_run_id uuid;
  v_prior jsonb;
  v_owner_id uuid;
  v_plan jsonb;
  v_item jsonb;
  v_i integer;
  v_wanted integer;
  v_created integer:=0;
  v_skipped integer:=0;
  v_errors integer:=0;
  v_evaluated integer:=0;
  v_created_ids uuid[]:='{}';
  v_show_id uuid;
  v_show_name text;
  v_names text[];
  v_run_day date;
  v_run_at timestamptz;
  v_fee bigint;
  v_purse bigint;
  v_fund system_funds;
  v_required bigint:=0;
  v_available bigint:=0;
  v_result jsonb;
begin
  if p_trigger not in('scheduled','manual')then raise exception'Invalid Auto Host trigger';end if;
  if p_trigger='manual'and not has_show_capability('shows.admin.auto_host',coalesce(p_actor,auth.uid()))then raise exception'Auto Host permission required';end if;

  select * into c from show_auto_host_config where id=true for update;
  if p_trigger='scheduled'and(not c.enabled or not c.daily_enabled)then return jsonb_build_object('status','off','created',0);end if;
  select r.result into v_prior from show_auto_host_runs r where r.cycle_key=p_cycle_key and r.completed_at is not null;
  if v_prior is not null then return v_prior||jsonb_build_object('idempotent',true);end if;
  select s.id into v_owner_id from stables s where s.account_number=1;
  if v_owner_id is null then raise exception'Owner Account #1 not found';end if;

  insert into show_auto_host_runs(cycle_key,trigger,actor_id,scheduled_for)
  values(p_cycle_key,p_trigger,coalesce(p_actor,v_owner_id),now())
  on conflict(cycle_key)do nothing
  returning id into v_run_id;
  if v_run_id is null then return jsonb_build_object('status','processing_or_complete','idempotent',true,'created',0);end if;

  v_plan:=show_auto_host_plan();
  v_run_day:=(now()at time zone c.timezone)::date+c.run_delay_days;
  v_run_at:=(v_run_day::timestamp at time zone c.timezone);

  for v_item in select value from jsonb_array_elements(v_plan->'items')planned(value)loop
    v_wanted:=(v_item->>'would_create')::integer;
    if v_wanted<=0 then continue;end if;
    if c.use_show_defaults then
      select d.entry_fee,d.base_purse into v_fee,v_purse from get_show_economy_defaults(v_item->>'tier_id')d;
    else
      v_fee:=(v_item->>'entry_fee')::bigint;
      v_purse:=(v_item->>'base_purse')::bigint;
    end if;
    if coalesce(v_fee,0)<=0 or coalesce(v_purse,0)<=0 then raise exception'Valid Show economy defaults are required for tier %',v_item->>'tier_id';end if;
    v_required:=v_required+(v_wanted*v_purse);
  end loop;

  select sf.balance into v_available from system_funds sf where sf.id='show_fund'for update;
  if v_required>v_available then
    v_result:=jsonb_build_object(
      'run_id',v_run_id,
      'cycle_key',p_cycle_key,
      'trigger',p_trigger,
      'status','insufficient_show_fund',
      'evaluated',coalesce((v_plan->>'combination_count')::integer,0),
      'created',0,
      'skipped',coalesce((v_plan->>'combination_count')::integer,0),
      'errors',0,
      'show_ids',v_created_ids,
      'run_at',v_run_at,
      'required_show_fund',v_required,
      'available_show_fund',v_available,
      'shortfall',v_required-v_available,
      'idempotent',false
    );
    update show_auto_host_runs r
      set shows_evaluated=coalesce((v_plan->>'combination_count')::integer,0),
          shows_created=0,
          shows_skipped=coalesce((v_plan->>'combination_count')::integer,0),
          error_count=0,
          result=v_result,
          completed_at=now()
      where r.id=v_run_id;
    insert into show_admin_audit(actor_id,action,details)
    values(coalesce(p_actor,v_owner_id),'auto_host_funding_blocked',v_result-'show_ids');
    return v_result;
  end if;

  for v_item in select value from jsonb_array_elements(v_plan->'items')planned(value)loop
    v_wanted:=(v_item->>'would_create')::integer;
    v_evaluated:=v_evaluated+1;
    if v_wanted=0 then v_skipped:=v_skipped+1;continue;end if;
    for v_i in 1..v_wanted loop begin
      if c.use_show_defaults then
        select d.entry_fee,d.base_purse into v_fee,v_purse from get_show_economy_defaults(v_item->>'tier_id')d;
      else
        v_fee:=(v_item->>'entry_fee')::bigint;
        v_purse:=(v_item->>'base_purse')::bigint;
      end if;
      if coalesce(v_fee,0)<=0 or coalesce(v_purse,0)<=0 then raise exception'Valid Show economy defaults are required for tier %',v_item->>'tier_id';end if;
      select p.names into v_names from show_auto_host_name_pools p where p.discipline_id=v_item->>'discipline_id';
      v_show_name:=coalesce(v_names[1+mod(v_created+v_i-1,greatest(cardinality(v_names),1))],'Legacy '||(v_item->>'discipline')||' Classic');
      if exists(select 1 from player_shows ps where ps.name=v_show_name and ps.run_date=v_run_day)then
        v_show_name:=left(v_show_name||' '||(select count(*)+1 from player_shows ps where ps.name like v_show_name||'%'and ps.run_date=v_run_day),80);
      end if;
      select * into v_fund from system_funds sf where sf.id='show_fund'for update;
      if v_fund.balance<v_purse then raise exception'Show Fund balance is insufficient for configured purse';end if;
      update system_funds sf set balance=sf.balance-v_purse,lifetime_outflow=sf.lifetime_outflow+v_purse where sf.id='show_fund';
      insert into player_shows(creator_id,name,discipline_id,tier_id,run_date,run_at,entry_fee,max_entries,maximum_per_owner,description,show_fund_allocation,source,auto_host_run_id)
      values(v_owner_id,v_show_name,v_item->>'discipline_id',v_item->>'tier_id',v_run_day,v_run_at,v_fee,null,2147483647,'Hosted by Legacy Equine · Source: Auto Host',v_purse,'auto_host',v_run_id)
      returning id into v_show_id;
      insert into system_fund_ledger(fund_id,amount,transaction_type,source,destination,initiated_by,reason,related_id)
      values('show_fund',-v_purse,'show_funding','LE Show Fund',v_show_name,v_owner_id,'Auto Host authoritative base purse',v_show_id);
      v_created:=v_created+1;
      v_created_ids:=array_append(v_created_ids,v_show_id);
    exception when others then
      v_errors:=v_errors+1;
    end;end loop;
  end loop;

  v_result:=jsonb_build_object('run_id',v_run_id,'cycle_key',p_cycle_key,'trigger',p_trigger,'evaluated',v_evaluated,'created',v_created,'skipped',v_skipped,'errors',v_errors,'show_ids',v_created_ids,'run_at',v_run_at,'idempotent',false);
  update show_auto_host_runs r set shows_evaluated=v_evaluated,shows_created=v_created,shows_skipped=v_skipped,error_count=v_errors,result=v_result,completed_at=now()where r.id=v_run_id;
  insert into show_admin_audit(actor_id,action,details)values(coalesce(p_actor,v_owner_id),'auto_host_'||p_trigger,v_result-'show_ids');
  return v_result;
end$$;

revoke all on function public.run_show_auto_host(text,text,uuid)from public;
grant execute on function public.run_show_auto_host(text,text,uuid)to service_role;
