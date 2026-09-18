-- Public Horse Profiles may display the exact equipped items that contribute to
-- Effective Stats, without exposing private inventory records.
create or replace function public.get_horse_equipped_tack(p_horse uuid)
returns table(
  item_id uuid,
  slot text,
  item_name text,
  quality text,
  bonuses jsonb,
  icon_url text,
  maker_brand_code text,
  maker_stable_name text,
  maker_account_number bigint
)
language sql
stable
security definer
set search_path=public
as $$
  select
    i.id,
    e.slot,
    coalesce(i.custom_name,p.name),
    coalesce(i.crafted_tier,p.quality),
    coalesce(i.custom_tack_bonuses,p.tack_bonuses,'{}'::jsonb),
    p.icon_url,
    i.maker_brand_code,
    i.maker_stable_name,
    i.maker_account_number
  from horse_equipment e
  join player_store_items i on i.id=e.item_id
  join store_products p on p.id=i.product_id
  join horses h on h.id=e.horse_id
  where e.horse_id=p_horse
    and h.id is not null
  order by case e.slot
    when 'bridle' then 1
    when 'saddle' then 2
    when 'saddle_pad' then 3
    when 'leg_protection' then 4
    when 'shoes' then 5
    else 99 end;
$$;

revoke all on function public.get_horse_equipped_tack(uuid) from public;
grant execute on function public.get_horse_equipped_tack(uuid) to authenticated;
