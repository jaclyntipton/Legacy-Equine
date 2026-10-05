-- Owner Account #1 can fund the LE Show Fund from personal LED through the
-- existing player currency ledger + system fund ledger. This does not mint LED.

create or replace function public.get_owner_show_fund_workspace()
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_owner public.stables;
  v_fund public.system_funds;
  v_plan jsonb;
  v_item jsonb;
  v_config public.show_auto_host_config;
  v_wanted integer;
  v_purse bigint;
  v_required bigint:=0;
begin
  if not public.is_owner_account() then
    raise exception 'Owner Account #1 access required';
  end if;

  select * into v_owner from public.stables s where s.id=auth.uid();
  if not found then raise exception 'Owner account not found';end if;

  select * into v_fund from public.system_funds sf where sf.id='show_fund';
  if not found then raise exception 'Show Fund not found';end if;

  select * into v_config from public.show_auto_host_config where id=true;
  v_plan:=public.show_auto_host_plan();

  for v_item in select value from jsonb_array_elements(coalesce(v_plan->'items','[]'::jsonb)) loop
    v_wanted:=coalesce((v_item->>'would_create')::integer,0);
    if v_wanted<=0 then continue;end if;
    if coalesce(v_config.use_show_defaults,true) then
      select d.base_purse into v_purse from public.get_show_economy_defaults(v_item->>'tier_id') d;
    else
      v_purse:=coalesce((v_item->>'base_purse')::bigint,0);
    end if;
    v_required:=v_required+(v_wanted*coalesce(v_purse,0));
  end loop;

  return jsonb_build_object(
    'owner',jsonb_build_object(
      'stable_id',v_owner.id,
      'account_number',v_owner.account_number,
      'name',v_owner.name,
      'balance',v_owner.balance
    ),
    'show_fund',to_jsonb(v_fund),
    'auto_host',jsonb_build_object(
      'enabled',coalesce((v_plan->>'enabled')::boolean,false),
      'daily_enabled',coalesce((v_plan->>'daily_enabled')::boolean,false),
      'next_run',v_plan->>'next_run',
      'shows_needed',coalesce((v_plan->>'would_create')::integer,0),
      'combination_count',coalesce((v_plan->>'combination_count')::integer,0),
      'required_show_fund',v_required,
      'available_show_fund',v_fund.balance,
      'shortfall',greatest(v_required-v_fund.balance,0)
    )
  );
end$$;

create or replace function public.owner_contribute_to_show_fund(
  p_amount bigint,
  p_request_id uuid default gen_random_uuid(),
  p_reason text default 'Owner Show Fund contribution',
  p_internal_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_owner public.stables;
  v_fund public.system_funds;
  v_existing public.system_fund_ledger;
  v_owner_before bigint;
  v_fund_before bigint;
  v_currency_entry uuid;
  v_fund_entry uuid;
  v_reason text:=left(coalesce(nullif(trim(p_reason),''),'SHOW_FUND_CONTRIBUTION'),200);
begin
  if not public.is_owner_account() then
    raise exception 'Owner Account #1 access required';
  end if;
  if p_amount is null or p_amount<=0 then
    raise exception 'Transfer amount must be positive';
  end if;
  if p_request_id is null then
    raise exception 'Transfer request id is required';
  end if;

  select * into v_owner from public.stables s where s.id=auth.uid() and s.account_number=1 for update;
  if not found then raise exception 'Owner Account #1 not found';end if;

  select * into v_existing
    from public.system_fund_ledger l
    where l.fund_id='show_fund'
      and l.transaction_type='show_fund_contribution'
      and l.related_id=p_request_id
    limit 1;
  if found then
    return jsonb_build_object(
      'idempotent',true,
      'system_fund_ledger_id',v_existing.id,
      'amount',v_existing.amount,
      'owner_balance_after',v_owner.balance,
      'show_fund_balance_after',(select sf.balance from public.system_funds sf where sf.id='show_fund')
    );
  end if;

  if v_owner.balance<p_amount then
    raise exception 'Owner account has insufficient LED';
  end if;

  select * into v_fund from public.system_funds sf where sf.id='show_fund' for update;
  if not found then raise exception 'Show Fund not found';end if;

  v_owner_before:=v_owner.balance;
  v_fund_before:=v_fund.balance;

  update public.stables
    set balance=balance-p_amount
    where id=v_owner.id;

  insert into public.currency_ledger(stable_id,amount,reason)
  values(v_owner.id,-p_amount,'SHOW_FUND_CONTRIBUTION: Legacy Equine Show Fund')
  returning id into v_currency_entry;

  update public.system_funds
    set balance=balance+p_amount,
        lifetime_inflow=lifetime_inflow+p_amount
    where id='show_fund';

  insert into public.system_fund_ledger(
    fund_id,amount,transaction_type,source,destination,initiated_by,reason,internal_note,related_id
  )
  values(
    'show_fund',
    p_amount,
    'show_fund_contribution',
    'Owner Account #1',
    'LE Show Fund',
    v_owner.id,
    v_reason,
    p_internal_note,
    p_request_id
  )
  returning id into v_fund_entry;

  insert into public.admin_audit_log(actor_id,action_type,system,target_type,target_id,details)
  values(
    v_owner.id,
    'show_fund.owner_contribution',
    'economy',
    'system_fund',
    'show_fund',
    jsonb_build_object(
      'amount',p_amount,
      'request_id',p_request_id,
      'currency_ledger_id',v_currency_entry,
      'system_fund_ledger_id',v_fund_entry,
      'owner_balance_before',v_owner_before,
      'owner_balance_after',v_owner_before-p_amount,
      'show_fund_before',v_fund_before,
      'show_fund_after',v_fund_before+p_amount
    )
  );

  return jsonb_build_object(
    'idempotent',false,
    'amount',p_amount,
    'request_id',p_request_id,
    'currency_ledger_id',v_currency_entry,
    'system_fund_ledger_id',v_fund_entry,
    'owner_balance_before',v_owner_before,
    'owner_balance_after',v_owner_before-p_amount,
    'show_fund_before',v_fund_before,
    'show_fund_after',v_fund_before+p_amount
  );
end$$;

revoke all on function public.get_owner_show_fund_workspace() from public;
revoke all on function public.owner_contribute_to_show_fund(bigint,uuid,text,text) from public;
grant execute on function public.get_owner_show_fund_workspace(),public.owner_contribute_to_show_fund(bigint,uuid,text,text) to authenticated;
