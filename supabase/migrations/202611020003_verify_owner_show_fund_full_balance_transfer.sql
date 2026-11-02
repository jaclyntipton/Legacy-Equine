-- Prove the deployed Owner contribution path accepts the full authoritative
-- source balance. The nested exception rolls every test write back.
do $verification$
declare
  v_owner public.stables;
  v_fund_before bigint;
  v_test_id uuid:=gen_random_uuid();
  v_result jsonb;
begin
  select * into v_owner
  from public.stables s
  where s.account_number=1;

  if not found then raise exception 'Owner Account #1 not found';end if;
  if v_owner.balance<=0 then raise exception 'Owner Account #1 has no transferable LED';end if;

  select sf.balance into v_fund_before
  from public.system_funds sf
  where sf.id='show_fund';

  perform set_config('request.jwt.claim.sub',v_owner.id::text,true);

  begin
    v_result:=public.owner_contribute_to_show_fund(
      v_owner.balance,
      v_test_id,
      'ROLLBACK-ONLY FULL-BALANCE VERIFICATION',
      'No production balance or ledger change is retained'
    );

    if (v_result->>'amount')::bigint<>v_owner.balance then
      raise exception 'Full-balance transfer returned an incorrect amount';
    end if;
    if (v_result->>'owner_balance_after')::bigint<>0 then
      raise exception 'Full-balance transfer did not resolve to zero source balance';
    end if;
    if (v_result->>'show_fund_after')::bigint<>v_fund_before+v_owner.balance then
      raise exception 'Full-balance transfer returned an incorrect destination balance';
    end if;

    raise exception 'ROLLBACK_FULL_BALANCE_VERIFICATION';
  exception
    when raise_exception then
      if sqlerrm<>'ROLLBACK_FULL_BALANCE_VERIFICATION' then raise;end if;
  end;

  if (select s.balance from public.stables s where s.id=v_owner.id)<>v_owner.balance then
    raise exception 'Owner balance changed during rollback-only verification';
  end if;
  if (select sf.balance from public.system_funds sf where sf.id='show_fund')<>v_fund_before then
    raise exception 'Show Fund balance changed during rollback-only verification';
  end if;
  if exists(select 1 from public.system_fund_ledger l where l.related_id=v_test_id) then
    raise exception 'Rollback-only verification retained a ledger record';
  end if;
end
$verification$;
