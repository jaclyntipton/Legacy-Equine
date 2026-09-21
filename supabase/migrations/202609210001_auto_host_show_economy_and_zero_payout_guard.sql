-- Central Show economy defaults, Auto Host repair, and zero-payout ledger guard.
alter table public.show_tiers add column if not exists default_entry_fee bigint not null default 25 check(default_entry_fee>0);
alter table public.show_tiers add column if not exists default_base_purse bigint not null default 200 check(default_base_purse>0);

create or replace function public.get_show_economy_defaults(p_tier text)returns table(entry_fee bigint,base_purse bigint)
language sql stable security definer set search_path=public as $$
 select st.default_entry_fee,st.default_base_purse from show_tiers st where st.id=p_tier and st.active
$$;

create or replace function public.admin_save_show_economy_defaults(p_tier text,p_entry_fee bigint,p_base_purse bigint)returns jsonb
language plpgsql security definer set search_path=public as $$declare v_before jsonb;v_after jsonb;begin
 if not has_show_capability('shows.admin.edit')then raise exception'Show administration permission required';end if;
 if p_entry_fee<=0 or p_base_purse<=0 then raise exception'Entry fee and base purse must be greater than zero';end if;
 select to_jsonb(st)into v_before from show_tiers st where st.id=p_tier for update;if v_before is null then raise exception'Show tier not found';end if;
 update show_tiers st set default_entry_fee=p_entry_fee,default_base_purse=p_base_purse where st.id=p_tier returning to_jsonb(st)into v_after;
 insert into show_admin_audit(actor_id,action,details)values(auth.uid(),'show_economy_defaults_updated',jsonb_build_object('tier',p_tier,'before',v_before,'after',v_after));return v_after;
end$$;

create table if not exists public.show_economy_reconciliation_runs(
 id uuid primary key default gen_random_uuid(),created_at timestamptz not null default now(),
 audited integer not null,zero_fee integer not null,zero_purse integer not null,safely_reconciled integer not null,manual_review integer not null,details jsonb not null
);
alter table public.show_economy_reconciliation_runs enable row level security;
create policy "show economy auditors read reconciliation" on public.show_economy_reconciliation_runs for select using(has_show_capability('shows.admin.audit'));

-- Auto Host's default mode previously translated directly to literal zeroes.
create or replace function public.run_show_auto_host(p_cycle_key text,p_trigger text,p_actor uuid default null)returns jsonb language plpgsql security definer set search_path=public as $$
declare c show_auto_host_config;v_run_id uuid;v_prior jsonb;v_owner_id uuid;v_plan jsonb;v_item jsonb;v_i integer;v_wanted integer;v_created integer:=0;v_skipped integer:=0;v_errors integer:=0;v_evaluated integer:=0;v_created_ids uuid[]:='{}';v_show_id uuid;v_show_name text;v_names text[];v_run_day date;v_run_at timestamptz;v_fee bigint;v_purse bigint;v_fund system_funds;v_result jsonb;
begin
 if p_trigger not in('scheduled','manual')then raise exception'Invalid Auto Host trigger';end if;if p_trigger='manual'and not has_show_capability('shows.admin.auto_host',coalesce(p_actor,auth.uid()))then raise exception'Auto Host permission required';end if;
 select * into c from show_auto_host_config where id=true for update;if p_trigger='scheduled'and(not c.enabled or not c.daily_enabled)then return jsonb_build_object('status','off','created',0);end if;
 select r.result into v_prior from show_auto_host_runs r where r.cycle_key=p_cycle_key and r.completed_at is not null;if v_prior is not null then return v_prior||jsonb_build_object('idempotent',true);end if;
 select s.id into v_owner_id from stables s where s.account_number=1;if v_owner_id is null then raise exception'Owner Account #1 not found';end if;
 insert into show_auto_host_runs(cycle_key,trigger,actor_id,scheduled_for)values(p_cycle_key,p_trigger,coalesce(p_actor,v_owner_id),now())on conflict(cycle_key)do nothing returning id into v_run_id;
 if v_run_id is null then return jsonb_build_object('status','processing_or_complete','idempotent',true,'created',0);end if;
 v_plan:=show_auto_host_plan();v_run_day:=(now()at time zone c.timezone)::date+c.run_delay_days;v_run_at:=(v_run_day::timestamp at time zone c.timezone);
 for v_item in select value from jsonb_array_elements(v_plan->'items')planned(value)loop v_wanted:=(v_item->>'would_create')::integer;v_evaluated:=v_evaluated+1;if v_wanted=0 then v_skipped:=v_skipped+1;continue;end if;
  for v_i in 1..v_wanted loop begin
   if c.use_show_defaults then select d.entry_fee,d.base_purse into v_fee,v_purse from get_show_economy_defaults(v_item->>'tier_id')d;else v_fee:=(v_item->>'entry_fee')::bigint;v_purse:=(v_item->>'base_purse')::bigint;end if;
   if coalesce(v_fee,0)<=0 or coalesce(v_purse,0)<=0 then raise exception'Valid Show economy defaults are required for tier %',v_item->>'tier_id';end if;
   select p.names into v_names from show_auto_host_name_pools p where p.discipline_id=v_item->>'discipline_id';v_show_name:=coalesce(v_names[1+mod(v_created+v_i-1,greatest(cardinality(v_names),1))],'Legacy '||(v_item->>'discipline')||' Classic');
   if exists(select 1 from player_shows ps where ps.name=v_show_name and ps.run_date=v_run_day)then v_show_name:=left(v_show_name||' '||(select count(*)+1 from player_shows ps where ps.name like v_show_name||'%'and ps.run_date=v_run_day),80);end if;
   select * into v_fund from system_funds sf where sf.id='show_fund'for update;if v_fund.balance<v_purse then raise exception'Show Fund balance is insufficient for configured purse';end if;
   update system_funds sf set balance=sf.balance-v_purse,lifetime_outflow=sf.lifetime_outflow+v_purse where sf.id='show_fund';
   insert into player_shows(creator_id,name,discipline_id,tier_id,run_date,run_at,entry_fee,max_entries,maximum_per_owner,description,show_fund_allocation,source,auto_host_run_id)values(v_owner_id,v_show_name,v_item->>'discipline_id',v_item->>'tier_id',v_run_day,v_run_at,v_fee,null,2147483647,'Hosted by Legacy Equine · Source: Auto Host',v_purse,'auto_host',v_run_id)returning id into v_show_id;
   insert into system_fund_ledger(fund_id,amount,transaction_type,source,destination,initiated_by,reason,related_id)values('show_fund',-v_purse,'show_funding','LE Show Fund',v_show_name,v_owner_id,'Auto Host authoritative base purse',v_show_id);
   v_created:=v_created+1;v_created_ids:=array_append(v_created_ids,v_show_id);
  exception when others then v_errors:=v_errors+1;end;end loop;
 end loop;
 v_result:=jsonb_build_object('run_id',v_run_id,'cycle_key',p_cycle_key,'trigger',p_trigger,'evaluated',v_evaluated,'created',v_created,'skipped',v_skipped,'errors',v_errors,'show_ids',v_created_ids,'run_at',v_run_at,'idempotent',false);
 update show_auto_host_runs r set shows_evaluated=v_evaluated,shows_created=v_created,shows_skipped=v_skipped,error_count=v_errors,result=v_result,completed_at=now()where r.id=v_run_id;
 insert into show_admin_audit(actor_id,action,details)values(coalesce(p_actor,v_owner_id),'auto_host_'||p_trigger,v_result-'show_ids');return v_result;
end$$;

-- Safe one-time repair: only future/open Auto Host Shows with no entries.
do $$declare v_owner uuid;v_a int;v_zf int;v_zp int;v_safe int;v_manual int;v_needed bigint;v_balance bigint;v_row record;begin
 select id into v_owner from stables where account_number=1;
 select count(*),count(*)filter(where ps.entry_fee=0),count(*)filter(where ps.entry_fee_purse+ps.show_fund_allocation+ps.treasury_allocation=0),count(*)filter(where not exists(select 1 from player_show_entries e where e.show_id=ps.id)),count(*)filter(where exists(select 1 from player_show_entries e where e.show_id=ps.id))into v_a,v_zf,v_zp,v_safe,v_manual from player_shows ps where ps.source='auto_host'and ps.status='open'and ps.run_at>now()and(ps.entry_fee=0 or ps.entry_fee_purse+ps.show_fund_allocation+ps.treasury_allocation=0);
 select coalesce(sum(st.default_base_purse),0)into v_needed from player_shows ps join show_tiers st on st.id=ps.tier_id where ps.source='auto_host'and ps.status='open'and ps.run_at>now()and(ps.entry_fee=0 or ps.entry_fee_purse+ps.show_fund_allocation+ps.treasury_allocation=0)and not exists(select 1 from player_show_entries e where e.show_id=ps.id);
 select balance into v_balance from system_funds where id='show_fund'for update;if v_balance<v_needed then raise exception'Show Fund lacks % LED required for safe Auto Host reconciliation',v_needed;end if;
 for v_row in select ps.id,ps.name,st.default_entry_fee,st.default_base_purse from player_shows ps join show_tiers st on st.id=ps.tier_id where ps.source='auto_host'and ps.status='open'and ps.run_at>now()and(ps.entry_fee=0 or ps.entry_fee_purse+ps.show_fund_allocation+ps.treasury_allocation=0)and not exists(select 1 from player_show_entries e where e.show_id=ps.id)for update loop
  update player_shows set entry_fee=v_row.default_entry_fee,show_fund_allocation=v_row.default_base_purse where id=v_row.id;update system_funds set balance=balance-v_row.default_base_purse,lifetime_outflow=lifetime_outflow+v_row.default_base_purse where id='show_fund';insert into system_fund_ledger(fund_id,amount,transaction_type,source,destination,initiated_by,reason,related_id)values('show_fund',-v_row.default_base_purse,'show_funding','LE Show Fund',v_row.name,v_owner,'Auto Host economy reconciliation',v_row.id);
 end loop;
 insert into show_economy_reconciliation_runs(audited,zero_fee,zero_purse,safely_reconciled,manual_review,details)values(v_a,v_zf,v_zp,v_safe,v_manual,jsonb_build_object('defaults',jsonb_build_object('entry_fee',25,'base_purse',200),'show_fund_debit',v_needed));
 insert into show_admin_audit(actor_id,action,details)values(v_owner,'auto_host_economy_reconciled',jsonb_build_object('audited',v_a,'zero_fee',v_zf,'zero_purse',v_zp,'safely_reconciled',v_safe,'manual_review',v_manual,'show_fund_debit',v_needed));
end$$;

-- Preserve the non-zero ledger constraint: only a positive calculated payout is posted.
create or replace function public.process_due_player_shows()returns integer language plpgsql security definer set search_path=public as $$declare sh player_shows;ent record;weights jsonb;purse bigint;rule show_placement_rules;rank_no int;processed int:=0;breakdown jsonb;score numeric;base_score numeric;inserted uuid;payout bigint;begin
 for sh in select*from player_shows where status in('open','processing')and run_at<=now()order by run_at for update skip locked loop update player_shows set status='processing'where id=sh.id;perform revalidate_show_entries(sh.id);rank_no:=0;purse:=sh.entry_fee_purse+sh.show_fund_allocation+sh.treasury_allocation;select stat_weights into weights from show_disciplines where id=sh.discipline_id;for ent in select e.*,h.stats,h.tack_bonuses from player_show_entries e join horses h on h.id=e.horse_id where e.show_id=sh.id order by e.id loop breakdown:=show_score_breakdown(ent.horse_id,weights,sh.run_at);score:=(select sum((breakdown->key->>'effective')::numeric*(value::text)::numeric)/nullif(sum((value::text)::numeric),0)from jsonb_each(weights));base_score:=(select sum(((breakdown->key->>'base')::numeric+(breakdown->key->>'training')::numeric)*(value::text)::numeric)/nullif(sum((value::text)::numeric),0)from jsonb_each(weights));update player_show_entries set eligibility_snapshot=coalesce(eligibility_snapshot,'{}')||jsonb_build_object('competition_score',score,'base_score',base_score,'score_breakdown',breakdown,'permanent_average_at_run',horse_permanent_stat_average(ent.horse_id),'show_level_at_run',get_horse_show_level(ent.horse_id))where id=ent.id;end loop;
  for ent in select e.*,(e.eligibility_snapshot->>'competition_score')::numeric score,(e.eligibility_snapshot->>'base_score')::numeric base_score,e.eligibility_snapshot->'score_breakdown'breakdown from player_show_entries e where e.show_id=sh.id order by score desc,base_score desc,e.career_points_snapshot desc,e.entered_at,e.horse_id loop rank_no:=rank_no+1;select*into rule from show_placement_rules where placement=rank_no;payout:=floor(purse*coalesce(rule.prize_percent,0)/100);inserted:=null;insert into player_show_results(show_id,entry_id,horse_id,owner_id,placement,competition_score,base_contribution,tack_contribution,service_contribution,career_points_awarded,led_winnings,horse_name_snapshot,owner_name_snapshot,owner_account_snapshot,score_breakdown)values(sh.id,ent.id,ent.horse_id,ent.owner_id,rank_no,ent.score,ent.base_score,coalesce((select avg((value->>'tack')::numeric)from jsonb_each(ent.breakdown)),0),coalesce((select avg((value->>'service')::numeric)from jsonb_each(ent.breakdown)),0),coalesce(rule.career_points,0),payout,ent.horse_name_snapshot,ent.owner_name_snapshot,ent.owner_account_snapshot,ent.breakdown)on conflict(entry_id)do nothing returning id into inserted;if inserted is not null then update horses set career_points=career_points+coalesce(rule.career_points,0)where id=ent.horse_id;if payout>0 then update stables set balance=balance+payout where id=ent.owner_id;insert into currency_ledger(stable_id,amount,reason,horse_id)values(ent.owner_id,payout,'Show winnings: '||sh.name,ent.horse_id);end if;end if;end loop;update player_shows set status='complete',processed_at=coalesce(processed_at,now())where id=sh.id;processed:=processed+1;end loop;return processed;end$$;

revoke all on function public.get_show_economy_defaults(text),public.admin_save_show_economy_defaults(text,bigint,bigint),public.run_show_auto_host(text,text,uuid),public.process_due_player_shows()from public;
grant execute on function public.get_show_economy_defaults(text)to authenticated;
grant execute on function public.admin_save_show_economy_defaults(text,bigint,bigint)to authenticated;
grant execute on function public.run_show_auto_host(text,text,uuid),public.process_due_player_shows()to service_role;
