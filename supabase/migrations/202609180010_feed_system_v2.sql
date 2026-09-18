-- Feed System V2: independent Hay/Grain feeding, combined stable storage,
-- daily global stock, and atomic bulk purchasing.

alter table public.store_products add column if not exists feed_type text check(feed_type in('hay','grain'));
alter table public.store_products add column if not exists daily_starting_stock integer not null default 500 check(daily_starting_stock>=0);

update public.store_products set name='Grass Hay',description='A dependable daily grass hay with an optional development opportunity.',feed_type='hay',quality='Entry',daily_starting_stock=500,sort_order=1 where id='basic_hay';
update public.store_products set name='Orchard Grass Hay',description='Soft orchard grass hay with an optional development opportunity.',feed_type='hay',quality='Quality',daily_starting_stock=500,sort_order=2 where id='quality_hay';
update public.store_products set name='LE Performance Feed',description='Performance grain with an optional development opportunity.',feed_type='grain',quality='Elite',daily_starting_stock=500,sort_order=8 where id='performance_feed';
update public.store_products set name='LE Elite Performance Feed',description='Elite performance grain with an optional development opportunity.',feed_type='grain',quality='Legendary',daily_starting_stock=500,sort_order=9 where id='premium_performance_feed';

insert into public.store_products(id,department,name,description,price,feed_success_probability,development_min,development_max,eligible_stats,quality,sort_order,feed_type,daily_starting_stock,active) values
 ('alfalfa_hay','feed','Alfalfa Hay','Rich alfalfa hay with its own optional development roll.',75,.34,1,2,array['Agility','Speed','Endurance','Temperament','Strength','Intelligence','Conformation'],'Quality',3,'hay',500,true),
 ('teff_hay','feed','Teff Hay','Fine-stem teff hay with its own optional development roll.',90,.39,1,2,array['Agility','Speed','Endurance','Temperament','Strength','Intelligence','Conformation'],'Elite',4,'hay',500,true),
 ('timothy_hay','feed','Timothy Hay','Premium timothy hay with its own optional development roll.',110,.45,1,2,array['Agility','Speed','Endurance','Temperament','Strength','Intelligence','Conformation'],'Legendary',5,'hay',500,true),
 ('le_basic_feed','feed','LE Basic Feed','Everyday grain with an optional development opportunity.',50,.22,1,1,array['Agility','Speed','Endurance','Temperament','Strength','Intelligence','Conformation'],'Entry',6,'grain',500,true),
 ('le_advanced_feed','feed','LE Advanced Feed','Advanced grain with an optional development opportunity.',75,.32,1,2,array['Agility','Speed','Endurance','Temperament','Strength','Intelligence','Conformation'],'Quality',7,'grain',500,true)
on conflict(id) do update set department=excluded.department,name=excluded.name,description=excluded.description,feed_type=excluded.feed_type,quality=excluded.quality,sort_order=excluded.sort_order,active=true;

update public.store_products set feed_type=case when id in('basic_hay','quality_hay','alfalfa_hay','teff_hay','timothy_hay')then'hay'else'grain'end where department='feed'and feed_type is null;

create table if not exists public.feed_system_config(
 id boolean primary key default true check(id),
 base_storage integer not null default 10 check(base_storage>=0),
 storage_per_five_levels integer not null default 10 check(storage_per_five_levels>=0),
 subscriber_storage_bonus integer not null default 5 check(subscriber_storage_bonus>=0),
 updated_by uuid references public.stables(id),updated_at timestamptz not null default now()
);
insert into public.feed_system_config(id)values(true)on conflict(id)do nothing;
alter table public.feed_system_config enable row level security;
drop policy if exists "feed config readable" on public.feed_system_config;
create policy "feed config readable" on public.feed_system_config for select using(true);

create table if not exists public.store_daily_stock(
 product_id text not null references public.store_products(id),
 le_day date not null,
 starting_stock integer not null check(starting_stock>=0),
 remaining_stock integer not null check(remaining_stock>=0),
 updated_at timestamptz not null default now(),
 primary key(product_id,le_day),
 check(remaining_stock<=starting_stock)
);
alter table public.store_daily_stock enable row level security;
drop policy if exists "daily store stock readable" on public.store_daily_stock;
create policy "daily store stock readable" on public.store_daily_stock for select using(true);

alter table public.horse_feed_log add column if not exists feed_type text;
update public.horse_feed_log f set feed_type=coalesce(p.feed_type,'hay') from public.store_products p where p.id=f.product_id and f.feed_type is null;
update public.horse_feed_log set feed_type='hay'where feed_type is null;
alter table public.horse_feed_log alter column feed_type set not null;
alter table public.horse_feed_log drop constraint if exists horse_feed_log_feed_type_check;
alter table public.horse_feed_log add constraint horse_feed_log_feed_type_check check(feed_type in('hay','grain'));
alter table public.horse_feed_log drop constraint if exists horse_feed_log_horse_id_le_day_key;
create unique index if not exists horse_feed_log_horse_day_type on public.horse_feed_log(horse_id,le_day,feed_type);

create or replace function public.feed_storage_summary(p_stable uuid default auth.uid())returns jsonb language plpgsql stable security definer set search_path=public as $$
declare s stables;cfg feed_system_config;lvl integer;sub boolean;used integer;cap integer;unlim boolean;
begin
 select * into s from stables where id=p_stable;if not found then return null;end if;
 select * into cfg from feed_system_config where id=true;
 lvl:=account_level_for_xp(s.account_xp);sub:=is_active_subscriber(s.id);unlim:=s.account_number=1;
 select count(*)into used from player_store_items i join store_products p on p.id=i.product_id where i.stable_id=s.id and i.consumed_at is null and p.department='feed';
 cap:=cfg.base_storage+floor(lvl/5.0)::integer*cfg.storage_per_five_levels+case when sub then cfg.subscriber_storage_bonus else 0 end;
 return jsonb_build_object('used',used,'capacity',case when unlim then null else cap end,'unlimited',unlim,'over_capacity',not unlim and used>cap,'available',case when unlim then null else greatest(cap-used,0)end,'level',lvl,'subscriber',sub,'subscriber_bonus',case when sub then cfg.subscriber_storage_bonus else 0 end);
end$$;

create or replace function public.get_store_feed_catalog()returns jsonb language plpgsql security definer set search_path=public as $$
declare today date:=(now()at time zone'America/New_York')::date;storage jsonb;
begin
 insert into store_daily_stock(product_id,le_day,starting_stock,remaining_stock)
 select p.id,today,p.daily_starting_stock,p.daily_starting_stock from store_products p where p.department='feed'and p.active
 on conflict(product_id,le_day)do nothing;
 storage:=feed_storage_summary(auth.uid());
 return coalesce((select jsonb_agg(jsonb_build_object(
  'id',p.id,'department',p.department,'name',p.name,'description',p.description,'price',p.price,
  'feed_success_probability',p.feed_success_probability,'development_min',p.development_min,'development_max',p.development_max,
  'eligible_stats',p.eligible_stats,'tack_slot',p.tack_slot,'quality',p.quality,'tack_bonuses',p.tack_bonuses,'icon_url',p.icon_url,'sort_order',p.sort_order,
  'feed_type',p.feed_type,'daily_starting_stock',s.starting_stock,'remaining_stock',s.remaining_stock,'le_day',today,
  'storage_used',(storage->>'used')::integer,'storage_capacity',case when storage->>'capacity'is null then null else(storage->>'capacity')::integer end,
  'storage_unlimited',(storage->>'unlimited')::boolean,'storage_available',case when storage->>'available'is null then null else(storage->>'available')::integer end
 )order by p.sort_order)from store_products p join store_daily_stock s on s.product_id=p.id and s.le_day=today where p.department='feed'and p.active),'[]'::jsonb);
end$$;

create or replace function public.get_feed_room_eligibility()returns jsonb language plpgsql security definer set search_path=public as $$
declare today date:=(now()at time zone'America/New_York')::date;
begin
 return jsonb_build_object('le_day',today,'storage',feed_storage_summary(auth.uid()),
  'hay_eligible_horse_ids',coalesce((select jsonb_agg(h.id order by h.name,h.id)from horses h where h.owner_id=auth.uid()and not exists(select 1 from horse_feed_log f where f.horse_id=h.id and f.le_day=today and f.feed_type='hay')),'[]'::jsonb),
  'grain_eligible_horse_ids',coalesce((select jsonb_agg(h.id order by h.name,h.id)from horses h where h.owner_id=auth.uid()and not exists(select 1 from horse_feed_log f where f.horse_id=h.id and f.le_day=today and f.feed_type='grain')),'[]'::jsonb));
end$$;

create or replace function public.feed_horses(p_horses uuid[],p_product text)returns jsonb language plpgsql security definer set search_path=public as $$
declare today date:=(now()at time zone'America/New_York')::date;requested integer;owned integer;product store_products;horse_record horses;item_record player_store_items;v_horse_id uuid;stat text;gain integer;before_stats jsonb;after_stats jsonb;success boolean;results jsonb:='[]'::jsonb;
begin
 if auth.uid()is null then raise exception'Authentication required';end if;requested:=coalesce(cardinality(p_horses),0);
 if requested<1 then raise exception'Select at least one eligible horse';end if;
 if requested<>(select count(distinct value)from unnest(p_horses)value)then raise exception'Each horse may only be selected once';end if;
 select * into product from store_products where id=p_product and department='feed'and feed_type in('hay','grain')and active for share;
 if not found then raise exception'This Feed product is unavailable';end if;
 for horse_record in select h.* from horses h where h.id=any(p_horses)order by h.id for update loop if horse_record.owner_id<>auth.uid()then raise exception'Choose horses you own';end if;end loop;
 if(select count(*)from horses h where h.id=any(p_horses)and h.owner_id=auth.uid())<>requested then raise exception'Choose horses you own';end if;
 if exists(select 1 from horse_feed_log f where f.horse_id=any(p_horses)and f.le_day=today and f.feed_type=product.feed_type)then raise exception'One or more selected horses already received today''s %',initcap(product.feed_type);end if;
 select count(*)into owned from player_store_items i where i.stable_id=auth.uid()and i.product_id=p_product and i.consumed_at is null;
 if owned<requested then raise exception'% units required • % available',requested,owned;end if;
 for v_horse_id in select value from unnest(p_horses)value order by value loop
  select * into item_record from player_store_items i where i.stable_id=auth.uid()and i.product_id=p_product and i.consumed_at is null order by i.purchased_at,i.id limit 1 for update skip locked;
  if not found then raise exception'% units required • fewer than % available',requested,requested;end if;
  select * into horse_record from horses where id=v_horse_id;before_stats:=horse_record.stats;success:=random()<product.feed_success_probability;stat:=null;gain:=0;after_stats:=before_stats;
  if success then stat:=product.eligible_stats[1+floor(random()*cardinality(product.eligible_stats))::integer];gain:=product.development_min+floor(random()*(product.development_max-product.development_min+1))::integer;after_stats:=jsonb_set(before_stats,array[stat],to_jsonb(coalesce((before_stats->>stat)::integer,0)+gain));update horses set stats=after_stats where id=v_horse_id;end if;
  update player_store_items set consumed_at=now()where id=item_record.id;
  insert into horse_feed_log(horse_id,stable_id,item_id,product_id,le_day,feed_type,result,stat_affected,development_amount,stats_before,stats_after)values(v_horse_id,auth.uid(),item_record.id,product.id,today,product.feed_type,case when success then'development'else'no_change'end,stat,gain,before_stats,after_stats);
  results:=results||jsonb_build_array(jsonb_build_object('horse_id',v_horse_id,'success',success,'stat',stat,'gain',gain));
 end loop;
 return jsonb_build_object('fed',requested,'feed_type',product.feed_type,'le_day',today,'results',results,'next_eligible',((today+1)::timestamp at time zone'America/New_York'));
end$$;

-- Keep the original single-item API category-aware for older clients while
-- routing all enforcement through the same authoritative batch feeder.
create or replace function public.feed_horse(p_horse uuid,p_item uuid)returns jsonb language plpgsql security definer set search_path=public as $$
declare item player_store_items;bulk jsonb;result jsonb;
begin
 select * into item from player_store_items where id=p_item and stable_id=auth.uid()and consumed_at is null;
 if not found then raise exception'Feed item unavailable';end if;
 bulk:=feed_horses(array[p_horse],item.product_id);result:=bulk->'results'->0;
 return result||jsonb_build_object('feed_type',bulk->'feed_type','next_eligible',bulk->'next_eligible');
end$$;

create or replace function public.purchase_store_product_bulk(p_product text,p_quantity integer,p_request uuid)returns jsonb language plpgsql security definer set search_path=public as $$
declare product store_products;s stables;i integer;ids uuid[]:='{}';new_id uuid;total integer;prior store_purchase_requests;today date:=(now()at time zone'America/New_York')::date;stock store_daily_stock;storage jsonb;storage_available integer;affordable bigint;maximum bigint;
begin
 if auth.uid()is null then raise exception'Authentication required';end if;if p_request is null then raise exception'Purchase request ID is required';end if;if p_quantity<1 then raise exception'Quantity must be at least 1';end if;
 select * into prior from store_purchase_requests where stable_id=auth.uid()and request_key=p_request;if found then return jsonb_build_object('items',prior.item_ids,'quantity',prior.quantity,'unit_price',prior.unit_price,'total',prior.total,'duplicate',true);end if;
 select * into product from store_products where id=p_product and active for update;if not found or product.department not in('feed','tack')then raise exception'Product unavailable';end if;
 if product.department='tack'and p_quantity>10 then raise exception'Tack quantity must be 1–10';end if;
 select * into s from stables where id=auth.uid()for update;if not found then raise exception'Create your stable first';end if;
 total:=product.price*p_quantity;if total<0 then raise exception'Invalid purchase total';end if;affordable:=case when product.price=0 then p_quantity else floor(s.balance/product.price)::integer end;
 if product.department='feed'then
  insert into store_daily_stock(product_id,le_day,starting_stock,remaining_stock)values(product.id,today,product.daily_starting_stock,product.daily_starting_stock)on conflict(product_id,le_day)do nothing;
  select * into stock from store_daily_stock where product_id=product.id and le_day=today for update;
  storage:=feed_storage_summary(s.id);storage_available:=case when(storage->>'unlimited')::boolean then p_quantity else(storage->>'available')::integer end;
  maximum:=least(stock.remaining_stock,storage_available,affordable);
  if p_quantity>maximum then
   if maximum=stock.remaining_stock then raise exception'Store stock limit: maximum purchasable is %',maximum;
   elsif maximum=storage_available then raise exception'Feed Storage limit: maximum purchasable is %',maximum;
   else raise exception'LED balance limit: maximum purchasable is %',maximum;end if;
  end if;
 end if;
 if s.balance<total then raise exception'Insufficient LED balance';end if;
 insert into store_purchase_requests(stable_id,request_key,product_id,unit_price,quantity,total)values(s.id,p_request,product.id,product.price,p_quantity,total)on conflict(stable_id,request_key)do nothing;
 if not found then select * into prior from store_purchase_requests where stable_id=s.id and request_key=p_request;return jsonb_build_object('items',prior.item_ids,'quantity',prior.quantity,'unit_price',prior.unit_price,'total',prior.total,'duplicate',true);end if;
 update stables set balance=balance-total where id=s.id;
 if product.department='feed'then update store_daily_stock set remaining_stock=remaining_stock-p_quantity,updated_at=now()where product_id=product.id and le_day=today;end if;
 insert into currency_ledger(stable_id,amount,reason)values(s.id,-total,'LE Store — '||product.name||case when p_quantity>1 then' ×'||p_quantity else''end);
 for i in 1..p_quantity loop insert into player_store_items(stable_id,product_id,purchased_price)values(s.id,product.id,product.price)returning id into new_id;ids:=array_append(ids,new_id);end loop;
 update store_purchase_requests set item_ids=ids where stable_id=s.id and request_key=p_request;
 return jsonb_build_object('items',ids,'quantity',p_quantity,'unit_price',product.price,'total',total,'balance',s.balance-total,'remaining_stock',case when product.department='feed'then stock.remaining_stock-p_quantity else null end,'duplicate',false);
end$$;

create or replace function public.admin_update_feed_v2_product(p_id text,p_active boolean,p_price integer,p_probability numeric,p_min integer,p_max integer,p_daily_stock integer)returns void language plpgsql security definer set search_path=public as $$
begin perform require_super_admin();if p_price<0 or p_probability<0 or p_probability>1 or p_min<0 or p_max<p_min or p_daily_stock<0 then raise exception'Product values are outside supported ranges';end if;
 update store_products set active=p_active,price=p_price,feed_success_probability=p_probability,development_min=p_min,development_max=p_max,daily_starting_stock=p_daily_stock where id=p_id and department='feed';if not found then raise exception'Feed product not found';end if;
 insert into admin_audit_log(actor_id,action_type,system,target_type,target_id,details)values(auth.uid(),'feed.product_updated','store','product',p_id,jsonb_build_object('price',p_price,'probability',p_probability,'min',p_min,'max',p_max,'daily_stock',p_daily_stock));
end$$;
create or replace function public.admin_update_feed_storage_config(p_base integer,p_per_five integer,p_subscriber_bonus integer)returns void language plpgsql security definer set search_path=public as $$
begin perform require_super_admin();if least(p_base,p_per_five,p_subscriber_bonus)<0 then raise exception'Capacity values cannot be negative';end if;update feed_system_config set base_storage=p_base,storage_per_five_levels=p_per_five,subscriber_storage_bonus=p_subscriber_bonus,updated_by=auth.uid(),updated_at=now()where id=true;insert into admin_audit_log(actor_id,action_type,system,details)values(auth.uid(),'feed.storage_config_updated','store',jsonb_build_object('base',p_base,'per_five',p_per_five,'subscriber_bonus',p_subscriber_bonus));end$$;
create or replace function public.admin_restock_feed_product(p_product text)returns jsonb language plpgsql security definer set search_path=public as $$
declare p store_products;today date:=(now()at time zone'America/New_York')::date;before integer;
begin perform require_super_admin();select * into p from store_products where id=p_product and department='feed';if not found then raise exception'Feed product not found';end if;select remaining_stock into before from store_daily_stock where product_id=p.id and le_day=today;insert into store_daily_stock(product_id,le_day,starting_stock,remaining_stock)values(p.id,today,p.daily_starting_stock,p.daily_starting_stock)on conflict(product_id,le_day)do update set starting_stock=excluded.starting_stock,remaining_stock=excluded.remaining_stock,updated_at=now();insert into admin_audit_log(actor_id,action_type,system,target_type,target_id,details)values(auth.uid(),'feed.manual_restock','store','product',p.id,jsonb_build_object('le_day',today,'before',before,'after',p.daily_starting_stock));return jsonb_build_object('product',p.id,'remaining',p.daily_starting_stock,'le_day',today);end$$;

revoke all on function public.feed_storage_summary(uuid),public.get_store_feed_catalog(),public.get_feed_room_eligibility(),public.feed_horses(uuid[],text),public.feed_horse(uuid,uuid),public.admin_update_feed_v2_product(text,boolean,integer,numeric,integer,integer,integer),public.admin_update_feed_storage_config(integer,integer,integer),public.admin_restock_feed_product(text)from public;
grant execute on function public.feed_storage_summary(uuid),public.get_store_feed_catalog(),public.get_feed_room_eligibility(),public.feed_horses(uuid[],text),public.feed_horse(uuid,uuid)to authenticated;
grant execute on function public.admin_update_feed_v2_product(text,boolean,integer,numeric,integer,integer,integer),public.admin_update_feed_storage_config(integer,integer,integer),public.admin_restock_feed_product(text)to authenticated;
