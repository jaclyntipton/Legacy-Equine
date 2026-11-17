-- Keep owned items and ledger history intact while simplifying the player-facing Store.
update public.store_products set active=false where department='stable_supplies';

-- Retire the small pre-catalog tack set. Owned copies remain visible and equippable.
update public.store_products set active=false
where id in ('basic_bridle','quality_saddle','racing_saddle','comfort_pad','performance_boots');

-- Preserve the configured prices and bonuses while normalizing the four tack tiers.
update public.store_products as product
set name=normalized.name,
    quality=normalized.quality,
    description=normalized.description,
    discipline_orientation='{}'
from (values
 ('bridle_basic','Entry Bridle','Entry','A dependable everyday bridle.'),
 ('bridle_quality_english','Quality Bridle','Quality','A well-made bridle with balanced support.'),
 ('bridle_performance_hunter','Elite Bridle','Elite','An advanced bridle with stronger effective-stat support.'),
 ('bridle_elite_competition','Legendary Bridle','Legendary','Top-tier bridle craftsmanship.'),
 ('saddle_basic','Entry Saddle','Entry','A practical general-purpose saddle.'),
 ('saddle_quality_hunter','Quality Saddle','Quality','A well-made saddle with balanced support.'),
 ('saddle_performance_jumper','Elite Saddle','Elite','An advanced saddle with stronger effective-stat support.'),
 ('saddle_elite_dressage','Legendary Saddle','Legendary','Top-tier saddle craftsmanship.'),
 ('pad_basic','Entry Saddle Pad','Entry','A simple protective saddle pad.'),
 ('pad_quality_show','Quality Saddle Pad','Quality','A well-made saddle pad with added comfort.'),
 ('pad_performance','Elite Saddle Pad','Elite','An advanced pad for demanding work.'),
 ('pad_elite','Legendary Saddle Pad','Legendary','Top-tier saddle pad craftsmanship.'),
 ('legs_basic_wraps','Entry Leg Protection','Entry','Dependable everyday leg protection.'),
 ('legs_quality_boots','Quality Leg Protection','Quality','Well-made protective boots.'),
 ('legs_performance_sport','Elite Leg Protection','Elite','Advanced protection for demanding work.'),
 ('legs_elite_competition','Legendary Leg Protection','Legendary','Top-tier protective boots.')
) as normalized(id,name,quality,description)
where product.id=normalized.id;

-- Feed quality is display/filter metadata only; mechanics and prices are unchanged.
update public.store_products set quality=case id
 when 'basic_hay' then 'Entry'
 when 'quality_hay' then 'Quality'
 when 'performance_feed' then 'Elite'
 when 'premium_performance_feed' then 'Legendary'
 else quality end
where department='feed';

-- An item retired from new sales must still work for the player who already owns it.
create or replace function public.equip_tack(p_horse uuid,p_item uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare h horses;i player_store_items;p store_products;old uuid;
begin
 select * into h from horses where id=p_horse for update;
 if not found or h.owner_id<>auth.uid() then raise exception 'Choose a horse you own';end if;
 select * into i from player_store_items where id=p_item and stable_id=auth.uid() and consumed_at is null for update;
 if not found then raise exception 'Tack item unavailable';end if;
 select * into p from store_products where id=i.product_id and department='tack';
 if not found then raise exception 'This item is not tack';end if;
 delete from horse_equipment where horse_id=h.id and slot=p.tack_slot returning item_id into old;
 insert into horse_equipment(horse_id,item_id,slot)values(h.id,i.id,p.tack_slot);
 return jsonb_build_object('bonuses',recalculate_horse_tack(h.id),'replaced_item',old);
end$$;
