-- Leatherworker uses the shared career/rates/provider engine. Only commission
-- fulfillment is tack-specific; LED movement remains on stables/currency_ledger.
insert into public.professions(id,name,description,sort_order)
values('leatherworker','Leatherworker','Craft custom tack with player-selected Effective Stat bonuses.',5)
on conflict(id)do update set name=excluded.name,description=excluded.description,sort_order=excluded.sort_order,active=true;

insert into public.study_modules(profession_id,level,title,summary,lessons,sort_order)values
('leatherworker',1,'Entry Tack Foundations','Build safe Entry tack and apply its one-point Effective Stat budget.','["Entry tack uses one total Effective Stat point from the seven approved horse stats.","A commission must match one equipment slot: Bridle, Saddle, Saddle Pad, or Leg Protection.","Crafted bonuses affect Effective Stats only and never genetics, breeding values, or permanent stats."]',1),
('leatherworker',2,'Quality Fit and Construction','Plan Quality tack within a two-point Effective Stat budget.','["Quality certification retains Entry access and unlocks a two-point Quality budget.","Clear commission records preserve the selected slot, tier, bonuses, price, and maker.","Fit and construction choices never override LE equipment-slot limits."]',1),
('leatherworker',3,'Elite Commission Design','Create Elite commissions with controlled three-point allocations.','["Elite certification retains lower tiers and unlocks a three-point Elite budget.","Every allocated stat must be an approved horse stat and the total cannot exceed the tier budget.","Maker provenance is captured when the item is completed and does not follow later Brand changes."]',1),
('leatherworker',4,'Professional Leatherwork Practice','Manage Legendary commissions and permanent provenance.','["Professional certification unlocks Legendary tack with a four-point Effective Stat budget.","A Legendary allocation may divide four points across approved stats while remaining Effective-only.","Professional records preserve payment, crafted item delivery, certification tier, and permanent maker provenance."]',1);

insert into public.certification_questions(profession_id,level,prompt,choices,correct_index,explanation)values
('leatherworker',1,'What is the total Entry tack Effective Stat budget?','["One point","Two points","Four points"]',0,'Entry tack has a one-point budget.'),
('leatherworker',1,'Which equipment rule applies to a crafted Bridle?','["It uses the existing Bridle slot","It adds a fifth tack slot","It replaces genetics"]',0,'Crafted tack uses existing equipment slots.'),
('leatherworker',1,'What can crafted tack change?','["Effective Stats only","Permanent breeding stats","Foal inheritance"]',0,'Crafted tack is Effective-only.'),
('leatherworker',2,'What does Quality certification unlock?','["Quality plus retained Entry access","Legendary only","A new equipment slot"]',0,'Higher certification retains lower tiers.'),
('leatherworker',2,'What is the Quality stat budget?','["Two points","One point","Five points"]',0,'Quality tack has a two-point budget.'),
('leatherworker',2,'What should a commission record preserve?','["Slot, tier, bonuses, price, and maker","Only its current owner","A genetic value"]',0,'The commission is a durable transaction record.'),
('leatherworker',3,'What is the Elite stat budget?','["Three points","Two points","Unlimited points"]',0,'Elite tack has a three-point budget.'),
('leatherworker',3,'Which allocation is server-valid?','["Approved stats within the tier budget","Any custom stat name","A permanent-stat increase"]',0,'Keys and total are server controlled.'),
('leatherworker',3,'When is maker provenance captured?','["When the item is completed","Whenever ownership changes","Only when equipped"]',0,'Provenance is a creation-time snapshot.'),
('leatherworker',4,'What does Professional Leatherworker unlock?','["Legendary tack with four Effective Stat points","A fifth equipment slot","Permanent genetic editing"]',0,'Professional unlocks Legendary crafting.'),
('leatherworker',4,'May Legendary points be divided across approved stats?','["Yes, within the four-point budget","No, bonuses are unlimited","Only by changing genetics"]',0,'The budget may be allocated among approved stats.'),
('leatherworker',4,'What must a completed Professional commission preserve?','["Payment, delivery, tier, and maker provenance","Only a temporary provider name","No transaction history"]',0,'Professional commission records remain auditable.');

insert into public.profession_level_requirements(profession_id,level,required_services)
select 'leatherworker',l.level,case l.level when 1 then 5 when 2 then 10 when 3 then 25 else 50 end
from public.certification_levels l on conflict(profession_id,level)do nothing;

alter table public.service_catalog add column if not exists tack_slot text;
alter table public.service_catalog add column if not exists tack_tier text;
alter table public.service_catalog add column if not exists stat_budget integer;

create table public.leatherwork_tier_config(
 level integer primary key references public.certification_levels(level),
 tier text not null unique check(tier in('Entry','Quality','Elite','Legendary')),
 stat_budget integer not null check(stat_budget>0),active boolean not null default true
);
insert into public.leatherwork_tier_config values(1,'Entry',1,true),(2,'Quality',2,true),(3,'Elite',3,true),(4,'Legendary',4,true)
on conflict(level)do update set tier=excluded.tier,stat_budget=excluded.stat_budget;

insert into public.service_catalog(id,profession_id,name,minimum_level,min_price,max_price,cooldown_hours,effect,duration_hours,active,tack_slot,tack_tier,stat_budget)
select 'craft_'||lower(t.tier)||'_'||x.slug,'leatherworker',t.tier||' '||x.label,t.level,
 case t.level when 1 then 50 when 2 then 100 when 3 then 175 else 250 end,
 case t.level when 1 then 500 when 2 then 750 when 3 then 1000 else 1500 end,0,'{}',0,true,x.slot,t.tier,t.stat_budget
from public.leatherwork_tier_config t cross join(values
 ('bridle','bridle','Bridle'),('saddle','saddle','Saddle'),('saddle_pad','saddle_pad','Saddle Pad'),('leg_protection','leg_protection','Leg Protection')
)x(slug,slot,label) on conflict(id)do update set name=excluded.name,minimum_level=excluded.minimum_level,active=true,tack_slot=excluded.tack_slot,tack_tier=excluded.tack_tier,stat_budget=excluded.stat_budget;

alter table public.player_store_items add column if not exists custom_name text;
alter table public.player_store_items add column if not exists custom_tack_bonuses jsonb;
alter table public.player_store_items add column if not exists maker_account_id uuid;
alter table public.player_store_items add column if not exists maker_stable_id uuid;
alter table public.player_store_items add column if not exists maker_brand_id uuid;
alter table public.player_store_items add column if not exists maker_brand_code text;
alter table public.player_store_items add column if not exists maker_stable_name text;
alter table public.player_store_items add column if not exists maker_account_number bigint;
alter table public.player_store_items add column if not exists crafted_at timestamptz;
alter table public.player_store_items add column if not exists crafted_certification_level integer;
alter table public.player_store_items add column if not exists crafted_tier text;

create table public.leatherwork_commissions(
 id uuid primary key default gen_random_uuid(),request_key uuid not null unique,
 client_id uuid not null references public.stables(id),provider_id uuid not null references public.stables(id),
 service_id text not null references public.service_catalog(id),crafted_item_id uuid references public.player_store_items(id),
 provider_level integer not null,price integer not null,custom_name text,bonuses jsonb not null,
 maker_brand_id uuid,maker_brand_code text,maker_stable_name text not null,maker_account_number bigint not null,
 owner_qa boolean not null default false,status text not null default 'completed',created_at timestamptz not null default now()
);
alter table public.leatherwork_commissions enable row level security;
create policy "commission participants readable" on public.leatherwork_commissions for select using(client_id=auth.uid()or provider_id=auth.uid());
alter table public.leatherwork_tier_config enable row level security;
create policy "leatherwork tier config readable" on public.leatherwork_tier_config for select using(true);

create or replace function public.recalculate_horse_tack(p_horse uuid)returns jsonb language plpgsql security definer set search_path=public as $$
declare bonuses jsonb;begin
 select coalesce(jsonb_object_agg(stat,total),'{}')into bonuses from(
  select stat,sum(value::numeric)total from horse_equipment e join player_store_items i on i.id=e.item_id join store_products p on p.id=i.product_id
  cross join lateral jsonb_each_text(coalesce(i.custom_tack_bonuses,p.tack_bonuses))j(stat,value)where e.horse_id=p_horse group by stat)x;
 update horses set tack_bonuses=bonuses where id=p_horse;return bonuses;
end$$;

create or replace function public.preview_leatherwork_commission(target_provider uuid,target_service text,p_bonuses jsonb,p_custom_name text default null)
returns jsonb language plpgsql security definer set search_path=public as $$
declare svc service_catalog;offering player_service_offerings;earned integer;budget integer;total integer;provider stables;
begin
 select * into svc from service_catalog where id=target_service and profession_id='leatherworker'and active;
 if not found then raise exception 'Leatherwork commission unavailable';end if;
 select max(level)into earned from player_profession_certifications where stable_id=target_provider and profession_id='leatherworker';
 select * into offering from player_service_offerings where stable_id=target_provider and service_id=svc.id and enabled;
 select * into provider from stables where id=target_provider and account_status='active';
 if provider.id is null or coalesce(earned,0)<svc.minimum_level or offering.service_id is null or offering.price not between svc.min_price and svc.max_price then raise exception 'Provider is not available for this commission';end if;
 if jsonb_typeof(p_bonuses)<>'object'then raise exception 'Choose Effective Stat bonuses';end if;
 if exists(select 1 from jsonb_each_text(p_bonuses)e where e.key<>all(array['Agility','Speed','Endurance','Temperament','Strength','Intelligence','Conformation'])or e.value::integer<0)then raise exception 'Invalid Effective Stat allocation';end if;
 select coalesce(sum(value::integer),0)into total from jsonb_each_text(p_bonuses);
 budget:=svc.stat_budget;if total<1 or total>budget then raise exception 'Allocate between 1 and % Effective Stat points',budget;end if;
 return jsonb_build_object('provider_id',provider.id,'provider_name',provider.name,'service_id',svc.id,'service_name',svc.name,'slot',svc.tack_slot,'tier',svc.tack_tier,'budget',budget,'allocated',total,'bonuses',p_bonuses,'custom_name',nullif(trim(p_custom_name),''),'price',offering.price);
end$$;

create or replace function public.purchase_leatherwork_commission(target_provider uuid,target_service text,p_bonuses jsonb,p_custom_name text,p_request_key uuid,expected_rate integer)
returns jsonb language plpgsql security definer set search_path=public as $$
declare existing leatherwork_commissions;preview jsonb;svc service_catalog;client stables;maker stables;brand stable_brands;item_id uuid;product_id text;rate integer;lvl integer;display_name text;
begin
 select * into existing from leatherwork_commissions where request_key=p_request_key;
 if found then return jsonb_build_object('item_id',existing.crafted_item_id,'price',existing.price,'delivered',true,'idempotent',true);end if;
 if target_provider=auth.uid()then raise exception 'Choose another player as Leatherworker';end if;
 preview:=preview_leatherwork_commission(target_provider,target_service,p_bonuses,p_custom_name);rate:=(preview->>'price')::integer;
 if rate<>expected_rate then return preview||jsonb_build_object('changed',true);end if;
 select * into svc from service_catalog where id=target_service;
 select max(level)into lvl from player_profession_certifications where stable_id=target_provider and profession_id='leatherworker';
 perform 1 from stables where id in(auth.uid(),target_provider)order by id for update;
 select * into client from stables where id=auth.uid();select * into maker from stables where id=target_provider;
 if client.balance<rate then raise exception 'Insufficient LED balance';end if;
 -- Revalidate the offering after both balances are locked.
 if not exists(select 1 from player_service_offerings where stable_id=target_provider and service_id=target_service and enabled and price=rate)then return preview_leatherwork_commission(target_provider,target_service,p_bonuses,p_custom_name)||jsonb_build_object('changed',true);end if;
 select * into brand from stable_brands where stable_id=target_provider and active order by created_at desc limit 1;
 select id into product_id from store_products where department='tack'and tack_slot=svc.tack_slot and quality=svc.tack_tier order by id limit 1;
 if product_id is null then raise exception 'Crafted tack base product is not configured';end if;
 display_name:=coalesce(nullif(trim(p_custom_name),''),'Custom '||svc.tack_tier||' '||case svc.tack_slot when'bridle'then'Bridle'when'saddle'then'Saddle'when'saddle_pad'then'Saddle Pad'else'Leg Protection'end);
 update stables set balance=balance-rate where id=client.id;update stables set balance=balance+rate where id=maker.id;
 insert into currency_ledger(stable_id,amount,reason)values(client.id,-rate,'Leatherwork commission — '||display_name),(maker.id,rate,'Leatherwork commission earned — '||display_name);
 insert into player_store_items(stable_id,product_id,purchased_price,custom_name,custom_tack_bonuses,maker_account_id,maker_stable_id,maker_brand_id,maker_brand_code,maker_stable_name,maker_account_number,crafted_at,crafted_certification_level,crafted_tier)
 values(client.id,product_id,rate,display_name,p_bonuses,maker.id,maker.id,brand.id,brand.code,maker.name,maker.account_number,now(),lvl,svc.tack_tier)returning id into item_id;
 insert into leatherwork_commissions(request_key,client_id,provider_id,service_id,crafted_item_id,provider_level,price,custom_name,bonuses,maker_brand_id,maker_brand_code,maker_stable_name,maker_account_number)
 values(p_request_key,client.id,maker.id,svc.id,item_id,lvl,rate,display_name,p_bonuses,brand.id,brand.code,maker.name,maker.account_number);
 update player_professions set lifetime_client_services=lifetime_client_services+1,qualifying_credit=qualifying_credit+1 where stable_id=maker.id and profession_id='leatherworker';
 return jsonb_build_object('item_id',item_id,'price',rate,'name',display_name,'tier',svc.tack_tier,'delivered',true,'balance',client.balance-rate);
end$$;

create or replace function public.legitimate_profession_service_count(target_stable uuid,target_profession text,target_level integer)
returns integer language sql security definer set search_path=public stable as $$
 select (select count(*)from horse_service_records where provider_id=target_stable and profession_id=target_profession and provider_level=target_level and status='completed'and not self_service and price>0)
      +(select count(*)from leatherwork_commissions where provider_id=target_stable and target_profession='leatherworker'and provider_level=target_level and status='completed'and not owner_qa and client_id<>provider_id and price>0)
$$;

create or replace function public.get_service_directory(target_profession text default null)
returns table(provider_id uuid,stable_name text,account_number bigint,profession_id text,profession_name text,certification text,certification_level integer,completed_services integer,service_id text,service_name text,price integer,owner_qa boolean)
language sql security definer set search_path=public stable as $$
 select s.id,s.name,s.account_number,p.id,p.name,cl.name||' Certified',earned.level,
  case when p.id='leatherworker' then coalesce(crafts.total,0)else coalesce(care.total,0)end,
  sc.id,sc.name,o.price,false
 from player_service_offerings o join stables s on s.id=o.stable_id and s.account_status='active'
 join service_catalog sc on sc.id=o.service_id and sc.active join professions p on p.id=sc.profession_id and p.active
 join lateral(select max(c.level)::integer level from player_profession_certifications c where c.stable_id=o.stable_id and c.profession_id=sc.profession_id)earned on earned.level is not null and earned.level>=sc.minimum_level
 join certification_levels cl on cl.level=earned.level
 left join lateral(select count(*)::integer total from horse_service_records r where r.provider_id=o.stable_id and r.profession_id=sc.profession_id and r.status='completed'and not r.self_service and r.price>0)care on true
 left join lateral(select count(*)::integer total from leatherwork_commissions c where c.provider_id=o.stable_id and c.status='completed'and not c.owner_qa and c.client_id<>c.provider_id and c.price>0)crafts on true
 where o.enabled and o.price between sc.min_price and sc.max_price and(target_profession is null or p.id=target_profession)
 order by earned.level desc,case when p.id='leatherworker'then coalesce(crafts.total,0)else coalesce(care.total,0)end desc,o.price,s.name,sc.name
$$;

revoke all on function public.preview_leatherwork_commission(uuid,text,jsonb,text),public.purchase_leatherwork_commission(uuid,text,jsonb,text,uuid,integer)from public;
grant execute on function public.preview_leatherwork_commission(uuid,text,jsonb,text),public.purchase_leatherwork_commission(uuid,text,jsonb,text,uuid,integer)to authenticated;
