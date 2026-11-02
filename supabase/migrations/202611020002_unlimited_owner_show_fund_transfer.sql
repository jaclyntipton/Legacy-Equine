-- Allow Owner Account #1 to transfer any positive whole-LED amount up to the
-- authoritative source balance without a 32-bit ledger or browser-number cap.

alter table public.currency_ledger
  alter column amount type bigint using amount::bigint;

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
      'balance',v_owner.balance,
      'balance_exact',v_owner.balance::text
    ),
    'show_fund',to_jsonb(v_fund),
    'show_fund_balance_exact',v_fund.balance::text,
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

revoke all on function public.get_owner_show_fund_workspace() from public;
grant execute on function public.get_owner_show_fund_workspace() to authenticated;
