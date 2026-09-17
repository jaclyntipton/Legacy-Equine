-- Unified show creation/entry workflows and auditable Show Fund destinations.
alter table public.player_shows add column if not exists creation_batch_id uuid;
alter table public.system_fund_ledger add column if not exists batch_id uuid;

create table if not exists public.show_action_requests(
 id uuid primary key,
 stable_id uuid not null references public.stables(id),
 action_type text not null check(action_type in('create_shows','enter_shows')),
 result jsonb,
 created_at timestamptz not null default now(),
 unique(stable_id,action_type,id)
);
alter table public.show_action_requests enable row level security;
create policy "owners read show action requests" on public.show_action_requests for select using(stable_id=auth.uid());

create table if not exists public.show_fund_reconciliation(
 currency_ledger_id uuid primary key references public.currency_ledger(id),
 system_fund_ledger_id uuid not null references public.system_fund_ledger(id),
 source_category text not null,
 amount bigint not null,
 reconciled_by uuid references public.stables(id),
 reconciled_at timestamptz not null default now()
);
alter table public.show_fund_reconciliation enable row level security;
create policy "admins read show reconciliation" on public.show_fund_reconciliation for select using(public.has_admin_permission('admin.economy.view'));

create or replace function public.create_shows(
 p_name text,p_discipline_id text,p_tier_id text,p_run_date date,p_entry_fee bigint,
 p_max_entries integer,p_description text,p_count integer default 1,
 p_schedule text default 'same_date',p_request_id uuid default gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_stable stables;v_cfg economy_config;v_progress jsonb;v_total bigint;v_batch uuid:=gen_random_uuid();v_ids uuid[]:='{}';v_id uuid;v_date date;v_i integer;v_result jsonb;v_name text;
begin
 if auth.uid() is null then raise exception 'Authentication required';end if;
 select result into v_result from show_action_requests where id=p_request_id and stable_id=auth.uid() and action_type='create_shows';if found then return v_result;end if;
 select * into v_stable from stables where id=auth.uid() for update;if not found then raise exception 'Stable not found';end if;
 select * into v_cfg from economy_config where id=true;v_progress:=get_account_progression();
 if p_count<1 or p_count>100 then raise exception 'Number of Shows must be between 1 and 100';end if;
 if p_count>1 and not (v_progress->>'bulk_show_creation')::boolean then raise exception 'Creating multiple Shows is not available for this account';end if;
 if length(trim(p_name)) not between 3 and 70 then raise exception 'Show name must be 3–70 characters';end if;
 if not exists(select 1 from show_disciplines where id=p_discipline_id and active) or not exists(select 1 from show_tiers where id=p_tier_id and active) then raise exception 'Choose an available discipline and Career Point tier';end if;
 if p_entry_fee<0 or p_entry_fee>v_cfg.show_entry_fee_max then raise exception 'Entry fee is outside the permitted range';end if;
 if p_max_entries is not null and p_max_entries not between 2 and 1000 then raise exception 'Maximum entries must be 2–1,000';end if;
 if p_schedule not in('same_date','consecutive') then raise exception 'Choose a valid schedule';end if;
 if (p_run_date::timestamp at time zone 'America/New_York')<=now() then raise exception 'Run date must be in the future';end if;
 perform assert_show_host_quota(v_stable.id,p_count,array(select p_run_date+case when p_schedule='consecutive' then i else 0 end from generate_series(0,p_count-1)i));
 v_total:=v_cfg.show_hosting_fee*p_count;if v_stable.balance<v_total then raise exception 'You do not have enough LE Dollars to create these Shows';end if;
 for v_i in 1..p_count loop
  v_date:=p_run_date+case when p_schedule='consecutive' then v_i-1 else 0 end;
  v_name:=case when p_count=1 then trim(p_name) else left(trim(p_name)||' #'||v_i,80) end;
  insert into player_shows(creator_id,name,discipline_id,tier_id,run_date,run_at,entry_fee,max_entries,description,maximum_per_owner,creation_batch_id)
  values(v_stable.id,v_name,p_discipline_id,p_tier_id,v_date,v_date::timestamp at time zone 'America/New_York',p_entry_fee,p_max_entries,left(coalesce(p_description,''),1000),1000,v_batch) returning id into v_id;
  v_ids:=array_append(v_ids,v_id);
  if v_cfg.show_hosting_fee>0 then
   insert into currency_ledger(stable_id,amount,reason) values(v_stable.id,-v_cfg.show_hosting_fee,'Show hosting fee: '||v_name);
   insert into system_fund_ledger(fund_id,amount,transaction_type,source,destination,initiated_by,reason,related_id,batch_id)
   values('show_fund',v_cfg.show_hosting_fee,'show_creation_fee',v_stable.name,'LE Show Fund',v_stable.id,'Show creation fee: '||v_name,v_id,v_batch);
  end if;
 end loop;
 if v_total>0 then update stables set balance=balance-v_total where id=v_stable.id;update system_funds set balance=balance+v_total,lifetime_inflow=lifetime_inflow+v_total where id='show_fund';end if;
 v_result:=jsonb_build_object('shows_created',p_count,'show_ids',v_ids,'batch_id',v_batch,'cost_per_show',v_cfg.show_hosting_fee,'total_cost',v_total,'balance_after',v_stable.balance-v_total);
 insert into show_action_requests(id,stable_id,action_type,result) values(p_request_id,v_stable.id,'create_shows',v_result);return v_result;
end$$;

create or replace function public.preview_show_entries(p_pairs jsonb) returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_progress jsonb;v_item jsonb;v_show player_shows;v_horse horses;v_eligible jsonb:='[]';v_skipped jsonb:='[]';v_fee bigint:=0;v_count integer;v_seen text[]:='{}';v_key text;v_selected jsonb:='{}';v_selected_for_show integer;
begin
 v_progress:=get_account_progression();
 if (select count(distinct x->>'show_id') from jsonb_array_elements(coalesce(p_pairs,'[]')) x)>1 and not (v_progress->>'advanced_bulk_entry')::boolean then raise exception 'Multiple-Show entry is not available for this account';end if;
 for v_item in select * from jsonb_array_elements(coalesce(p_pairs,'[]')) loop
  v_key:=(v_item->>'show_id')||':'||(v_item->>'horse_id');if v_key=any(v_seen) then continue;end if;v_seen:=array_append(v_seen,v_key);
  select * into v_show from player_shows where id=(v_item->>'show_id')::uuid;select * into v_horse from horses where id=(v_item->>'horse_id')::uuid and owner_id=auth.uid();
  if v_show.id is null or v_horse.id is null then v_skipped:=v_skipped||jsonb_build_array(v_item||jsonb_build_object('reason','Horse or Show unavailable'));
  elsif v_show.status<>'open' or v_show.run_at<=now() then v_skipped:=v_skipped||jsonb_build_array(v_item||jsonb_build_object('horse_name',v_horse.name,'show_name',v_show.name,'reason','Show is closed'));
  elsif exists(select 1 from player_show_entries e where e.show_id=v_show.id and e.horse_id=v_horse.id) then v_skipped:=v_skipped||jsonb_build_array(v_item||jsonb_build_object('horse_name',v_horse.name,'show_name',v_show.name,'reason','Already entered'));
  elsif v_horse.sanctuary_retired_at is not null then v_skipped:=v_skipped||jsonb_build_array(v_item||jsonb_build_object('horse_name',v_horse.name,'show_name',v_show.name,'reason','Horse is retired to Sanctuary'));
  elsif get_horse_competition_tier(v_horse.career_points)<>v_show.tier_id then v_skipped:=v_skipped||jsonb_build_array(v_item||jsonb_build_object('horse_name',v_horse.name,'show_name',v_show.name,'reason','Career Point tier'));
  else select count(*) into v_count from player_show_entries where show_id=v_show.id;v_selected_for_show:=coalesce((v_selected->>v_show.id::text)::integer,0);if v_show.max_entries is not null and v_count+v_selected_for_show>=v_show.max_entries then v_skipped:=v_skipped||jsonb_build_array(v_item||jsonb_build_object('horse_name',v_horse.name,'show_name',v_show.name,'reason','Show is full'));
  else v_eligible:=v_eligible||jsonb_build_array(v_item||jsonb_build_object('horse_name',v_horse.name,'show_name',v_show.name,'fee',v_show.entry_fee));v_fee:=v_fee+v_show.entry_fee;v_selected:=jsonb_set(v_selected,array[v_show.id::text],to_jsonb(v_selected_for_show+1),true);end if;end if;
 end loop;
 return jsonb_build_object('eligible',v_eligible,'skipped',v_skipped,'total_fee',v_fee,'balance',(select balance from stables where id=auth.uid()),'previewed_at',now());
end$$;

create or replace function public.confirm_show_entries(p_pairs jsonb,p_request_id uuid default gen_random_uuid()) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_preview jsonb;v_item jsonb;v_stable stables;v_show player_shows;v_horse horses;v_entry uuid;v_ids uuid[]:='{}';v_total bigint;v_result jsonb;v_batch uuid:=gen_random_uuid();
begin
 if auth.uid() is null then raise exception 'Authentication required';end if;
 select result into v_result from show_action_requests where id=p_request_id and stable_id=auth.uid() and action_type='enter_shows';if found then return v_result;end if;
 select * into v_stable from stables where id=auth.uid() for update;
 perform 1 from player_shows ps where ps.id in(select (x->>'show_id')::uuid from jsonb_array_elements(coalesce(p_pairs,'[]')) x) order by ps.id for update;
 perform 1 from horses h where h.id in(select (x->>'horse_id')::uuid from jsonb_array_elements(coalesce(p_pairs,'[]')) x) order by h.id for update;
 v_preview:=preview_show_entries(p_pairs);
 if jsonb_array_length(v_preview->'skipped')>0 then return v_preview||jsonb_build_object('changed',true,'entries_created',0);end if;
 if jsonb_array_length(v_preview->'eligible')=0 then raise exception 'No eligible entries selected';end if;v_total:=(v_preview->>'total_fee')::bigint;
 if v_stable.balance<v_total then raise exception 'You do not have enough LE Dollars for these entries';end if;
 for v_item in select * from jsonb_array_elements(v_preview->'eligible') loop
  select * into v_show from player_shows where id=(v_item->>'show_id')::uuid for update;select * into v_horse from horses where id=(v_item->>'horse_id')::uuid for update;
  insert into player_show_entries(show_id,horse_id,owner_id,tier_id,career_points_snapshot,horse_name_snapshot,owner_name_snapshot,owner_account_snapshot,eligibility_snapshot)
  values(v_show.id,v_horse.id,v_stable.id,v_show.tier_id,v_horse.career_points,v_horse.name,v_stable.name,v_stable.account_number,jsonb_build_object('career_points_at_entry',v_horse.career_points,'tier_at_entry',v_show.tier_id)) returning id into v_entry;v_ids:=array_append(v_ids,v_entry);
  if v_show.entry_fee>0 then
   update player_shows set entry_fee_purse=entry_fee_purse+v_show.entry_fee where id=v_show.id;
   insert into currency_ledger(stable_id,amount,reason,horse_id) values(v_stable.id,-v_show.entry_fee,'Show entry: '||v_show.name,v_horse.id);
   insert into system_fund_ledger(fund_id,amount,transaction_type,source,destination,initiated_by,reason,related_id,batch_id) values('show_fund',v_show.entry_fee,'show_entry_fee',v_stable.name,v_show.name||' purse',v_stable.id,'Show entry fee: '||v_horse.name,v_show.id,v_batch);
   insert into system_fund_ledger(fund_id,amount,transaction_type,source,destination,initiated_by,reason,related_id,batch_id) values('show_fund',-v_show.entry_fee,'show_purse_allocation','LE Show Fund',v_show.name||' purse',v_stable.id,'Entry fee allocated to Show purse',v_show.id,v_batch);
   update system_funds set lifetime_inflow=lifetime_inflow+v_show.entry_fee,lifetime_outflow=lifetime_outflow+v_show.entry_fee where id='show_fund';
  end if;
 end loop;
 if v_total>0 then update stables set balance=balance-v_total where id=v_stable.id;end if;
 v_result:=v_preview||jsonb_build_object('changed',false,'entries_created',cardinality(v_ids),'entry_ids',v_ids,'batch_id',v_batch,'balance_after',v_stable.balance-v_total);
 insert into show_action_requests(id,stable_id,action_type,result) values(p_request_id,v_stable.id,'enter_shows',v_result);return v_result;
exception when unique_violation then raise exception 'One of these horses was just entered. Review your entries again';
end$$;

create or replace function public.reconcile_show_fund_history() returns jsonb language plpgsql security definer set search_path=public as $$
declare v_row record;v_total bigint:=0;v_creation bigint:=0;v_entry bigint:=0;v_profession bigint:=0;v_ledger uuid;v_category text;
begin
 perform require_super_admin();
 for v_row in select cl.* from currency_ledger cl left join show_fund_reconciliation r on r.currency_ledger_id=cl.id where cl.amount<0 and r.currency_ledger_id is null and (cl.reason ilike 'Show hosting fee%' or cl.reason ilike 'Bulk show hosting fees%' or cl.reason ilike 'Show entry:%' or cl.reason ilike '%enrollment fee' or cl.reason ilike '%certification exam fee') order by cl.created_at loop
  if v_row.reason ilike 'Show hosting fee%' or v_row.reason ilike 'Bulk show hosting fees%' then v_category:='show_creation_fee';
  elsif v_row.reason ilike 'Show entry:%' then v_category:='show_entry_fee';else v_category:='profession_fee_reconciliation';end if;
  if v_category='profession_fee_reconciliation' then continue;end if;
  insert into system_fund_ledger(fund_id,amount,transaction_type,source,destination,initiated_by,reason,internal_note,related_id,created_at)
  values('show_fund',-v_row.amount,v_category,'Historical player deduction','LE Show Fund',v_row.stable_id,'Historical reconciliation: '||v_row.reason,'Recovered from authoritative currency_ledger '||v_row.id,v_row.id,v_row.created_at) returning id into v_ledger;
  if v_category='show_entry_fee' then
   insert into system_fund_ledger(fund_id,amount,transaction_type,source,destination,initiated_by,reason,internal_note,related_id,created_at)
   values('show_fund',v_row.amount,'show_purse_allocation','LE Show Fund','Historical Show purse',v_row.stable_id,'Historical entry fee allocated to Show purse','Paired with authoritative currency_ledger '||v_row.id,v_row.id,v_row.created_at);
  end if;
  insert into show_fund_reconciliation(currency_ledger_id,system_fund_ledger_id,source_category,amount,reconciled_by,reconciled_at) values(v_row.id,v_ledger,v_category,-v_row.amount,auth.uid(),now());
  if v_category='show_creation_fee' then
   update system_funds set balance=balance-v_row.amount,lifetime_inflow=lifetime_inflow-v_row.amount where id='show_fund';v_creation:=v_creation-v_row.amount;
  else
   update system_funds set lifetime_inflow=lifetime_inflow-v_row.amount,lifetime_outflow=lifetime_outflow-v_row.amount where id='show_fund';v_entry:=v_entry-v_row.amount;
  end if;v_total:=v_total-v_row.amount;
 end loop;
 return jsonb_build_object('recovered',v_total,'show_creation_fees',v_creation,'show_entry_fees',v_entry,'profession_contributions',v_profession,'already_reconciled',(select coalesce(sum(amount),0) from show_fund_reconciliation));
end$$;

revoke all on function public.create_shows(text,text,text,date,bigint,integer,text,integer,text,uuid),public.preview_show_entries(jsonb),public.confirm_show_entries(jsonb,uuid),public.reconcile_show_fund_history() from public;
grant execute on function public.create_shows(text,text,text,date,bigint,integer,text,integer,text,uuid),public.preview_show_entries(jsonb),public.confirm_show_entries(jsonb,uuid) to authenticated;
grant execute on function public.reconcile_show_fund_history() to authenticated;
