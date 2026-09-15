-- Account #1 is the permanent Legacy Equine owner account. Foundation purchase
-- counts are retained for history/analytics only and never restrict checkout.
alter table public.stables drop constraint if exists stables_foundation_purchases_check;

insert into public.stable_capacity_allocations(stable_id,source,quantity,unlimited,reason)
select s.id,'owner_unlimited',0,true,'Permanent Legacy Equine Owner privilege'
from public.stables s
where s.account_number=1
  and not exists(
    select 1 from public.stable_capacity_allocations a
    where a.stable_id=s.id and a.unlimited and a.status='active'
  );

create or replace function public.stable_capacity(target uuid)
returns table(occupied bigint,base_capacity bigint,purchased_capacity bigint,complimentary_capacity bigint,total_capacity bigint,unlimited boolean,available bigint)
language sql stable security definer set search_path=public as $$
 with c as(
   select
    coalesce(sum(a.quantity) filter(where a.status='active' and a.source='base'),0) base_capacity,
    coalesce(sum(a.quantity) filter(where a.status='active' and a.source='purchased'),0) purchased_capacity,
    coalesce(sum(a.quantity) filter(where a.status='active' and a.source in('admin','promotional','event')),0) complimentary_capacity,
    coalesce(bool_or(a.unlimited) filter(where a.status='active'),false) allocation_unlimited
   from public.stable_capacity_allocations a where a.stable_id=target
 ),o as(
   select count(*) occupied from public.horses h where h.owner_id=target and h.sanctuary_retired_at is null
 ),s as(
   select coalesce(st.account_number=1,false) owner_unlimited from public.stables st where st.id=target
 )
 select o.occupied,c.base_capacity,c.purchased_capacity,c.complimentary_capacity,
  c.base_capacity+c.purchased_capacity+c.complimentary_capacity,
  c.allocation_unlimited or coalesce(s.owner_unlimited,false),
  case when c.allocation_unlimited or coalesce(s.owner_unlimited,false) then null
   else greatest(0,c.base_capacity+c.purchased_capacity+c.complimentary_capacity-o.occupied) end
 from c,o left join s on true
$$;

create or replace function public.owner_set_unlimited_capacity(target_stable uuid,make_unlimited boolean,change_reason text default 'Owner capacity decision')
returns void language plpgsql security definer set search_path=public as $$
declare target_account bigint;
begin
 perform public.require_super_admin();
 select s.account_number into target_account from public.stables s where s.id=target_stable;
 if target_account is null then raise exception 'Stable not found';end if;
 if target_account=1 and not make_unlimited then raise exception 'Account #1 has permanent unlimited stable capacity';end if;
 if make_unlimited then
  insert into public.stable_capacity_allocations(stable_id,source,quantity,unlimited,reason,granted_by)
  values(target_stable,'owner_unlimited',0,true,left(change_reason,200),auth.uid()) on conflict do nothing;
 else
  update public.stable_capacity_allocations set status='reversed',reversed_by=auth.uid(),reversed_at=now()
  where stable_id=target_stable and source='owner_unlimited' and status='active';
 end if;
 insert into public.stable_capacity_audit(actor_id,stable_id,action,reason)
 values(auth.uid(),target_stable,case when make_unlimited then 'unlimited_granted' else 'unlimited_revoked' end,left(change_reason,200));
end$$;

comment on column public.stables.foundation_purchases is
'Lifetime Foundation-store purchase count for history and analytics only; never an eligibility limit.';
comment on function public.purchase_store_horse(uuid) is
'Purchases the exact available store horse transactionally. There is no per-account lifetime purchase limit; balance and stable capacity still apply.';

revoke all on function public.stable_capacity(uuid),public.owner_set_unlimited_capacity(uuid,boolean,text) from public;
grant execute on function public.owner_set_unlimited_capacity(uuid,boolean,text) to authenticated;
