-- The Alpha player baseline is 4,000 LED. Keep the table default and every
-- supported stable-creation path aligned with the application configuration.
alter table public.stables alter column balance set default 4000;

create or replace function public.initialize_stable(stable_name text)
returns public.stables language plpgsql security definer set search_path=public as $$
declare result public.stables;is_test boolean;
begin
  if auth.uid() is null then raise exception 'Authentication required';end if;
  select * into result from stables where id=auth.uid();if found then return result;end if;
  if length(trim(stable_name)) not between 2 and 60 then raise exception 'Stable name must be 2–60 characters';end if;
  is_test:=coalesce((auth.jwt()->>'email') ilike '%+test@%',false) or coalesce((auth.jwt()->>'email') ilike '%@example.%',false);
  insert into stables(id,name,balance,account_number) values(auth.uid(),trim(stable_name),4000,case when is_test then null else nextval('account_number_seq') end) returning * into result;
  insert into currency_ledger(stable_id,amount,reason) values(auth.uid(),4000,'Starting funds');
  return result;
exception when unique_violation then select * into result from stables where id=auth.uid();return result;
end $$;

-- Restore every genuine current player to the promised Alpha baseline. This is
-- ledgered, idempotent, and does not alter or erase prior transactions.
with targets as(
 select id,4000-balance as adjustment from public.stables where account_number is not null and balance<4000
),updated as(
 update public.stables s set balance=4000 from targets t where s.id=t.id returning s.id,t.adjustment
)
insert into public.currency_ledger(stable_id,amount,reason)
select id,adjustment,'Alpha balance restored to 4,000 LED' from updated where adjustment>0;

revoke all on function public.initialize_stable(text) from public;
grant execute on function public.initialize_stable(text) to authenticated;
comment on column public.stables.balance is 'Server-controlled LED balance; new genuine Alpha accounts begin with 4,000 LED.';
