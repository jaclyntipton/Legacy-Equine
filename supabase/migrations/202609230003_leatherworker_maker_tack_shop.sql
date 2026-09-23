-- Leatherworkers create unique tack for their own inventory, then list the
-- completed item. The existing unique inventory/provenance and commission
-- sale record remain authoritative; no parallel inventory system is added.
alter table public.leatherwork_tier_config add column if not exists weekly_craft_limit integer check(weekly_craft_limit is null or weekly_craft_limit>0);
alter table public.player_store_items add column if not exists craft_request_key uuid unique;
alter table public.player_store_items add column if not exists listed_price integer check(listed_price is null or listed_price>0);
alter table public.player_store_items add column if not exists listed_at timestamptz;
alter table public.player_store_items add column if not exists sold_at timestamptz;

create or replace function public.craft_leatherwork_item(target_service text,p_bonuses jsonb,p_custom_name text,p_request_key uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare svc service_catalog;maker stables;brand stable_brands;earned integer;total integer;product text;item player_store_items;display_name text;limit_count integer;
begin
 if auth.uid()is null then raise exception 'Sign in to create tack';end if;
 select * into item from player_store_items where craft_request_key=p_request_key and stable_id=auth.uid();
 if found then return jsonb_build_object('item_id',item.id,'name',item.custom_name,'idempotent',true);end if;
 select * into svc from service_catalog where id=target_service and profession_id='leatherworker'and active;
 if not found then raise exception 'Leatherwork design unavailable';end if;
 select max(level)into earned from player_profession_certifications where stable_id=auth.uid()and profession_id='leatherworker';
 if coalesce(earned,0)<svc.minimum_level then raise exception '% certification is required',svc.tack_tier;end if;
 if jsonb_typeof(p_bonuses)<>'object'then raise exception 'Choose Effective Stat bonuses';end if;
 begin
  if exists(select 1 from jsonb_each_text(p_bonuses)e where e.key<>all(array['Agility','Speed','Endurance','Temperament','Strength','Intelligence','Conformation'])or e.value::integer<0)then raise exception 'Invalid Effective Stat allocation';end if;
  select coalesce(sum(value::integer),0)into total from jsonb_each_text(p_bonuses);
 exception when invalid_text_representation then raise exception 'Effective Stat bonuses must be whole numbers';end;
 if total<1 or total>svc.stat_budget then raise exception 'Allocate between 1 and % Effective Stat points',svc.stat_budget;end if;
 select weekly_craft_limit into limit_count from leatherwork_tier_config where level=svc.minimum_level and active;
 if limit_count is not null and(select count(*)from player_store_items where maker_stable_id=auth.uid()and crafted_at>=date_trunc('week',now()at time zone'America/New_York')at time zone'America/New_York')>=limit_count then raise exception 'Weekly crafting limit reached';end if;
 select * into maker from stables where id=auth.uid()and account_status='active'for update;
 if not found then raise exception 'Stable unavailable';end if;
 select * into brand from stable_brands where stable_id=maker.id and active order by created_at desc limit 1;
 select id into product from store_products where department='tack'and tack_slot=svc.tack_slot and quality=svc.tack_tier and active order by id limit 1;
 if product is null then raise exception 'Crafted tack base product is not configured';end if;
 display_name:=coalesce(nullif(trim(p_custom_name),''),'Custom '||svc.tack_tier||' '||case svc.tack_slot when'bridle'then'Bridle'when'saddle'then'Saddle'when'saddle_pad'then'Saddle Pad'else'Leg Protection'end);
 insert into player_store_items(stable_id,product_id,purchased_price,custom_name,custom_tack_bonuses,maker_account_id,maker_stable_id,maker_brand_id,maker_brand_code,maker_stable_name,maker_account_number,crafted_at,crafted_certification_level,crafted_tier,craft_request_key)
 values(maker.id,product,0,display_name,p_bonuses,maker.id,maker.id,brand.id,brand.code,maker.name,maker.account_number,now(),svc.minimum_level,svc.tack_tier,p_request_key)returning * into item;
 return jsonb_build_object('item_id',item.id,'name',display_name,'tier',svc.tack_tier,'bonuses',p_bonuses,'delivered_to_maker',true);
end$$;

create or replace function public.get_leatherwork_shop_inventory()
returns jsonb language sql security definer set search_path=public stable as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'name',i.custom_name,'tier',i.crafted_tier,'slot',p.tack_slot,'bonuses',i.custom_tack_bonuses,'price',i.listed_price,'listed',i.listed_price is not null,'crafted_at',i.crafted_at,'maker_brand_code',i.maker_brand_code,'maker_stable_name',i.maker_stable_name,'maker_account_number',i.maker_account_number)order by i.crafted_at desc),'[]')
 from player_store_items i join store_products p on p.id=i.product_id
 where i.stable_id=auth.uid()and i.maker_stable_id=auth.uid()and i.custom_tack_bonuses is not null and i.consumed_at is null
$$;

create or replace function public.set_leatherwork_item_listing(p_item uuid,p_price integer,p_list boolean)
returns jsonb language plpgsql security definer set search_path=public as $$
declare item player_store_items;svc service_catalog;
begin
 select * into item from player_store_items where id=p_item and stable_id=auth.uid()and maker_stable_id=auth.uid()and custom_tack_bonuses is not null and consumed_at is null for update;
 if not found then raise exception 'Crafted tack item unavailable';end if;
 if exists(select 1 from horse_equipment where item_id=item.id)then raise exception 'Unequip this item before listing it';end if;
 select sc.* into svc from service_catalog sc join store_products p on p.tack_slot=sc.tack_slot and p.quality=sc.tack_tier where p.id=item.product_id and sc.profession_id='leatherworker'and sc.active limit 1;
 if p_list and(p_price is null or p_price not between svc.min_price and svc.max_price)then raise exception 'Price must be between % and % LED',svc.min_price,svc.max_price;end if;
 update player_store_items set listed_price=case when p_list then p_price else null end,listed_at=case when p_list then now()else null end where id=item.id;
 return jsonb_build_object('item_id',item.id,'listed',p_list,'price',case when p_list then p_price else null end);
end$$;

create or replace function public.get_public_leatherwork_inventory(p_stable uuid)
returns jsonb language sql security definer set search_path=public stable as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'name',i.custom_name,'tier',i.crafted_tier,'slot',p.tack_slot,'bonuses',i.custom_tack_bonuses,'price',i.listed_price,'maker_brand_code',i.maker_brand_code,'maker_stable_name',i.maker_stable_name,'maker_account_number',i.maker_account_number)order by i.listed_at desc),'[]')
 from player_store_items i join store_products p on p.id=i.product_id join stables s on s.id=i.stable_id and s.account_status='active'
 where i.stable_id=p_stable and i.maker_stable_id=p_stable and i.listed_price is not null and i.consumed_at is null and not exists(select 1 from horse_equipment e where e.item_id=i.id)
$$;

create or replace function public.purchase_listed_leatherwork_item(p_item uuid,p_request_key uuid,p_expected_price integer)
returns jsonb language plpgsql security definer set search_path=public as $$
declare existing leatherwork_commissions;item player_store_items;buyer stables;seller stables;svc service_catalog;rate integer;
begin
 select * into existing from leatherwork_commissions where request_key=p_request_key;
 if found then return jsonb_build_object('item_id',existing.crafted_item_id,'price',existing.price,'delivered',true,'idempotent',true);end if;
 select * into item from player_store_items where id=p_item for update;
 if not found or item.listed_price is null or item.consumed_at is not null then raise exception 'This tack is no longer available';end if;
 if item.stable_id=auth.uid()then raise exception 'This tack already belongs to you';end if;
 perform 1 from stables where id in(auth.uid(),item.stable_id)order by id for update;
 select * into buyer from stables where id=auth.uid();select * into seller from stables where id=item.stable_id;
 select sc.* into svc from service_catalog sc join store_products p on p.tack_slot=sc.tack_slot and p.quality=sc.tack_tier where p.id=item.product_id and sc.profession_id='leatherworker'and sc.active limit 1;
 rate:=item.listed_price;
 if rate<>p_expected_price then return jsonb_build_object('changed',true,'price',rate);end if;
 if buyer.balance<rate then raise exception 'Insufficient LED balance';end if;
 if exists(select 1 from horse_equipment where item_id=item.id)then raise exception 'This tack is no longer available';end if;
 update stables set balance=balance-rate where id=buyer.id;update stables set balance=balance+rate where id=seller.id;
 insert into currency_ledger(stable_id,amount,reason)values(buyer.id,-rate,'Player-crafted tack purchase — '||item.custom_name),(seller.id,rate,'Player-crafted tack sale — '||item.custom_name);
 update player_store_items set stable_id=buyer.id,purchased_price=rate,listed_price=null,listed_at=null,sold_at=now()where id=item.id;
 insert into leatherwork_commissions(request_key,client_id,provider_id,service_id,crafted_item_id,provider_level,price,custom_name,bonuses,maker_brand_id,maker_brand_code,maker_stable_name,maker_account_number)
 values(p_request_key,buyer.id,seller.id,svc.id,item.id,item.crafted_certification_level,rate,item.custom_name,item.custom_tack_bonuses,item.maker_brand_id,item.maker_brand_code,item.maker_stable_name,item.maker_account_number);
 update player_professions set lifetime_client_services=lifetime_client_services+1,qualifying_credit=qualifying_credit+1 where stable_id=seller.id and profession_id='leatherworker';
 return jsonb_build_object('item_id',item.id,'price',rate,'delivered',true,'balance',buyer.balance-rate);
end$$;

revoke all on function public.craft_leatherwork_item(text,jsonb,text,uuid),public.get_leatherwork_shop_inventory(),public.set_leatherwork_item_listing(uuid,integer,boolean),public.get_public_leatherwork_inventory(uuid),public.purchase_listed_leatherwork_item(uuid,uuid,integer)from public;
grant execute on function public.craft_leatherwork_item(text,jsonb,text,uuid),public.get_leatherwork_shop_inventory(),public.set_leatherwork_item_listing(uuid,integer,boolean),public.get_public_leatherwork_inventory(uuid),public.purchase_listed_leatherwork_item(uuid,uuid,integer)to authenticated;
