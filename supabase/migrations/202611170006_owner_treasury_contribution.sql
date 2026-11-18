-- Owner Accounts #1 and #2 may move personal LED into the institutional
-- Treasury. The transfer is atomic, ledgered on both sides, and idempotent.
create or replace function public.get_owner_treasury_workspace()
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
 v_owner public.stables;
 v_fund public.system_funds;
begin
 if not public.is_owner_account() then raise exception 'Owner access required';end if;
 select * into v_owner from public.stables s where s.id=auth.uid();
 if not found then raise exception 'Owner account not found';end if;
 select * into v_fund from public.system_funds sf where sf.id='treasury';
 if not found then raise exception 'Treasury not found';end if;
 return jsonb_build_object(
  'owner_balance_exact',v_owner.balance::text,
  'treasury_balance_exact',v_fund.balance::text,
  'treasury_lifetime_inflow_exact',v_fund.lifetime_inflow::text,
  'treasury_lifetime_outflow_exact',v_fund.lifetime_outflow::text
 );
end
$$;

revoke all on function public.get_owner_treasury_workspace() from public,anon;
grant execute on function public.get_owner_treasury_workspace() to authenticated;

create or replace function public.owner_contribute_to_treasury(
 p_amount bigint,
 p_request_id uuid default gen_random_uuid(),
 p_reason text default 'Owner Treasury contribution',
 p_internal_note text default null
)returns jsonb
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
 v_reason text:=left(coalesce(nullif(trim(p_reason),''),'TREASURY_CONTRIBUTION'),200);
begin
 if not public.is_owner_account() then raise exception 'Owner access required';end if;
 if p_amount is null or p_amount<=0 then raise exception 'Transfer amount must be positive';end if;
 if p_request_id is null then raise exception 'Transfer request id is required';end if;

 select * into v_owner from public.stables s where s.id=auth.uid() for update;
 if not found then raise exception 'Owner account not found';end if;

 select * into v_existing from public.system_fund_ledger l
 where l.fund_id='treasury' and l.transaction_type='treasury_contribution' and l.related_id=p_request_id
 limit 1;
 if found then
  return jsonb_build_object('idempotent',true,'system_fund_ledger_id',v_existing.id,'amount',v_existing.amount,'owner_balance_after',v_owner.balance,'treasury_balance_after',(select sf.balance from public.system_funds sf where sf.id='treasury'));
 end if;

 if v_owner.balance<p_amount then raise exception 'Owner account has insufficient LED';end if;
 select * into v_fund from public.system_funds sf where sf.id='treasury' for update;
 if not found then raise exception 'Treasury not found';end if;
 v_owner_before:=v_owner.balance;
 v_fund_before:=v_fund.balance;

 update public.stables set balance=balance-p_amount where id=v_owner.id;
 insert into public.currency_ledger(stable_id,amount,reason)
 values(v_owner.id,-p_amount,'TREASURY_CONTRIBUTION: Legacy Equine Treasury')
 returning id into v_currency_entry;
 update public.system_funds set balance=balance+p_amount,lifetime_inflow=lifetime_inflow+p_amount where id='treasury';
 insert into public.system_fund_ledger(fund_id,amount,transaction_type,source,destination,initiated_by,reason,internal_note,related_id)
 values('treasury',p_amount,'treasury_contribution','Owner Account #'||v_owner.account_number,'Legacy Equine Treasury',v_owner.id,v_reason,p_internal_note,p_request_id)
 returning id into v_fund_entry;
 insert into public.admin_audit_log(actor_id,action_type,system,target_type,target_id,details)
 values(v_owner.id,'treasury.owner_contribution','economy','system_fund','treasury',jsonb_build_object('amount',p_amount,'request_id',p_request_id,'currency_ledger_id',v_currency_entry,'system_fund_ledger_id',v_fund_entry,'owner_balance_before',v_owner_before,'owner_balance_after',v_owner_before-p_amount,'treasury_before',v_fund_before,'treasury_after',v_fund_before+p_amount));

 return jsonb_build_object('idempotent',false,'amount',p_amount,'request_id',p_request_id,'currency_ledger_id',v_currency_entry,'system_fund_ledger_id',v_fund_entry,'owner_balance_before',v_owner_before,'owner_balance_after',v_owner_before-p_amount,'treasury_before',v_fund_before,'treasury_after',v_fund_before+p_amount);
end
$$;

revoke all on function public.owner_contribute_to_treasury(bigint,uuid,text,text) from public,anon;
grant execute on function public.owner_contribute_to_treasury(bigint,uuid,text,text) to authenticated;
