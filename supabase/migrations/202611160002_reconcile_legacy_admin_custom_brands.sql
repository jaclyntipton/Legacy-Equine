-- Older Admin Custom horses were inserted with an owner but without an
-- ownership-history row. That made the original provenance-safe Brand backfill
-- skip legitimate origin horses created before the Brand trigger was deployed.

create or replace function public.brand_origin_horse_on_insert()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if new.owner_id is not null and new.origin='Admin Custom' then
    insert into horse_ownership_history(
      horse_id,owner_id,acquired_at,acquisition_method
    )
    select new.id,new.owner_id,new.created_at,'Admin Custom'
    where not exists(
      select 1 from horse_ownership_history where horse_id=new.id
    );
  end if;

  if new.owner_id is not null
     and new.origin<>'Bred'
     and coalesce(current_setting('app.skip_origin_brand',true),'off')<>'on' then
    perform assign_horse_brand(
      new.id,
      new.owner_id,
      case when new.origin='Admin Custom'
        then 'Owner Custom Creation'
        else new.origin::text
      end
    );
  end if;
  return new;
end
$$;

drop trigger if exists assign_origin_brand_on_insert on public.horses;
create trigger assign_origin_brand_on_insert
after insert on public.horses
for each row execute function public.brand_origin_horse_on_insert();

-- Reconcile only unbranded legacy Admin Custom horses whose current Stable is
-- also their sole provable owner. Horses with evidence of another owner are
-- intentionally excluded so current ownership never rewrites origin provenance.
do $$
declare
  item record;
begin
  for item in
    select h.id,h.owner_id,h.created_at
    from horses h
    join stable_brands b on b.stable_id=h.owner_id and b.active
    where h.origin='Admin Custom'
      and h.owner_id is not null
      and h.horse_brand_id is null
      and has_brand_privilege(h.owner_id)
      and not exists(
        select 1
        from horse_ownership_history oh
        where oh.horse_id=h.id and oh.owner_id is distinct from h.owner_id
      )
      and not exists(
        select 1
        from horse_ownership_history oh
        where oh.horse_id=h.id and oh.disposition is not null
      )
  loop
    insert into horse_ownership_history(
      horse_id,owner_id,acquired_at,acquisition_method
    )
    select item.id,item.owner_id,item.created_at,'Admin Custom'
    where not exists(
      select 1 from horse_ownership_history where horse_id=item.id
    );

    perform assign_horse_brand(
      item.id,item.owner_id,'Owner Custom Creation Reconciliation'
    );
  end loop;
end
$$;

