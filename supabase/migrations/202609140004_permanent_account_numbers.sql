create sequence public.account_number_seq as bigint start with 1 increment by 1 no cycle;
alter table public.stables add column account_number bigint;
alter table public.stables add constraint stables_account_number_positive check (account_number is null or account_number > 0);
alter table public.stables add constraint stables_account_number_unique unique (account_number);

-- Pre-launch correction: the only genuine player stable is LE Account #1.
update public.stables set account_number=1 where name='Twisted Tree Ranch';
select setval('public.account_number_seq',1,true);

-- Service-role-only test identities receive no public number and consume no sequence value.
create table public.test_identities(user_id uuid primary key references auth.users(id) on delete cascade,created_at timestamptz not null default now());
alter table public.test_identities enable row level security;

drop function if exists public.create_stable(text);
create or replace function public.initialize_stable(stable_name text)
returns public.stables language plpgsql security definer set search_path=public as $$
declare result public.stables; is_test boolean;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into result from stables where id=auth.uid(); if found then return result; end if;
  if length(trim(stable_name)) not between 2 and 60 then raise exception 'Stable name must be 2–60 characters'; end if;
  select exists(select 1 from test_identities where user_id=auth.uid()) into is_test;
  insert into stables(id,name,balance,account_number) values(auth.uid(),trim(stable_name),3000,case when is_test then null else nextval('account_number_seq') end) returning * into result;
  insert into currency_ledger(stable_id,amount,reason) values(auth.uid(),3000,'Starting funds'); return result;
exception when unique_violation then select * into result from stables where id=auth.uid(); if found then return result; end if; raise;
end $$;
revoke all on function public.initialize_stable(text) from public;
grant execute on function public.initialize_stable(text) to authenticated;
comment on column public.stables.account_number is 'Permanent sequential public LE account number. Null only for explicitly marked automated test identities.';
