create or replace function public.owner_set_admin(target_stable uuid,make_admin boolean)
returns public.stables language plpgsql security definer set search_path=public as $$
declare result stables;caller_number bigint;
begin
  select account_number into caller_number from stables where id=auth.uid();
  if caller_number is distinct from 1 then raise exception 'Only the Legacy Equine owner account can designate administrators'; end if;
  if target_stable=auth.uid() and not make_admin then raise exception 'The owner account cannot remove its own administrator access'; end if;
  update stables set is_admin=make_admin where id=target_stable returning * into result;
  if not found then raise exception 'Stable not found'; end if;
  return result;
end $$;

revoke all on function public.owner_set_admin(uuid,boolean) from public;
grant execute on function public.owner_set_admin(uuid,boolean) to authenticated;
