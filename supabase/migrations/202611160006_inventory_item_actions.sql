-- Player-controlled use/discard actions for Legacy Finds and other owned inventory.

create table if not exists public.inventory_item_actions(
 id uuid primary key default gen_random_uuid(),
 stable_id uuid not null references public.stables(id)on delete cascade,
 item_id uuid not null references public.player_store_items(id),
 product_id text not null references public.store_products(id),
 action text not null check(action in('used','discarded')),
 created_at timestamptz not null default now()
);

alter table public.inventory_item_actions enable row level security;
drop policy if exists "own inventory item actions" on public.inventory_item_actions;
create policy "own inventory item actions" on public.inventory_item_actions for select to authenticated using(stable_id=auth.uid());
revoke all on public.inventory_item_actions from anon,authenticated;
grant select on public.inventory_item_actions to authenticated;

create or replace function public.use_stable_supply(p_item uuid)returns jsonb language plpgsql security definer set search_path=public as $$
declare item player_store_items;product store_products;
begin
 select*into item from player_store_items where id=p_item and stable_id=auth.uid()and consumed_at is null for update;
 if not found then raise exception'Item unavailable';end if;
 select*into product from store_products where id=item.product_id and department='stable_supplies';
 if not found then raise exception'Only Stable Supply items can be used here';end if;
 update player_store_items set consumed_at=now()where id=item.id;
 insert into inventory_item_actions(stable_id,item_id,product_id,action)values(auth.uid(),item.id,item.product_id,'used');
 return jsonb_build_object('item_id',item.id,'name',product.name,'action','used');
end$$;

create or replace function public.discard_inventory_item(p_item uuid)returns jsonb language plpgsql security definer set search_path=public as $$
declare item player_store_items;product store_products;
begin
 select*into item from player_store_items where id=p_item and stable_id=auth.uid()and consumed_at is null for update;
 if not found then raise exception'Item unavailable';end if;
 if exists(select 1 from horse_equipment e where e.item_id=item.id)then raise exception'Unequip this item before discarding it';end if;
 if item.listed_price is not null then raise exception'Unlist this item before discarding it';end if;
 select*into product from store_products where id=item.product_id;
 update player_store_items set consumed_at=now(),listed_price=null,listed_at=null where id=item.id;
 insert into inventory_item_actions(stable_id,item_id,product_id,action)values(auth.uid(),item.id,item.product_id,'discarded');
 return jsonb_build_object('item_id',item.id,'name',product.name,'action','discarded');
end$$;

revoke all on function public.use_stable_supply(uuid),public.discard_inventory_item(uuid)from public,anon;
grant execute on function public.use_stable_supply(uuid),public.discard_inventory_item(uuid)to authenticated;
