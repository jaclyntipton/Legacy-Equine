create or replace function public.collect_weekly_allowances(p_ids uuid[] default null)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  row weekly_allowance_entitlements;
  total bigint:=0;
  counted integer:=0;
  new_balance bigint;
begin
  perform ensure_weekly_allowances();
  for row in
    select *
    from weekly_allowance_entitlements w
    where w.stable_id=auth.uid()
      and w.status='available'
      and (w.expires_at is null or w.expires_at>now())
      and (p_ids is null or w.id=any(p_ids))
    order by w.week_start
    for update
  loop
    update weekly_allowance_entitlements w
    set status='collected',collected_at=now()
    where w.id=row.id;

    insert into currency_ledger(stable_id,amount,reason)
    values(auth.uid(),row.total_amount,'Weekly Stable Allowance — week of '||row.week_start);

    total:=total+row.total_amount;
    counted:=counted+1;
  end loop;

  if counted=0 then
    raise exception 'No available weekly allowance to collect';
  end if;

  update stables
  set balance=balance+total
  where id=auth.uid()
  returning balance into new_balance;

  return jsonb_build_object('collected',counted,'amount',total,'balance',new_balance);
end
$$;

grant execute on function public.collect_weekly_allowances(uuid[]) to authenticated;
