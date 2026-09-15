alter table public.horses alter column owner_id drop not null;

create table public.foundation_breeds(
  name text primary key,
  active boolean not null default true,
  sort_order integer not null unique
);
insert into public.foundation_breeds(name,sort_order) values
('Thoroughbred',1),('Arabian',2),('Quarter Horse',3),('Hanoverian',4),
('Appaloosa',5),('Morgan',6),('Rocky Mountain Horse',7),('Tennessee Walking Horse',8);
alter table public.foundation_breeds enable row level security;
create policy "public foundation breeds" on public.foundation_breeds for select using(true);

create type public.store_inventory_status as enum ('active','sold','expired');
create table public.store_inventory(
  id uuid primary key default gen_random_uuid(),
  horse_id uuid not null unique references public.horses(id) on delete restrict,
  price integer not null default 1000 check(price>=0),
  status public.store_inventory_status not null default 'active',
  generated_at timestamptz not null default now(),
  sold_at timestamptz,
  sold_to uuid references public.stables(id),
  rotation_key timestamptz not null
);
create index store_inventory_active_idx on public.store_inventory(status,generated_at);
alter table public.store_inventory enable row level security;
create policy "public active inventory" on public.store_inventory for select using(status='active');

create table public.store_settings(
  singleton boolean primary key default true check(singleton),
  inventory_size integer not null default 6 check(inventory_size between 5 and 8),
  rotation_minutes integer not null default 60 check(rotation_minutes between 15 and 1440),
  foundation_price integer not null default 1000 check(foundation_price>=0)
);
insert into public.store_settings(singleton) values(true);
alter table public.store_settings enable row level security;
create policy "public store settings" on public.store_settings for select using(true);

create or replace function public.generate_store_horse(p_rotation timestamptz,p_preferred_breed text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare h_id uuid; breed_name text; names text[]:=array['Amethyst Sky','Bright Promise','Clover Song','Dancing Willow','Evening Star','Golden Echo','Lavender Lane','Moonlit Wish','Pepperberry','Silver Thistle','Summer Melody','Velvet Comet']; colors text[]:=array['Bay','Chestnut','Black','Gray','Palomino'];
begin
  select coalesce(p_preferred_breed,(select name from foundation_breeds where active order by random() limit 1)) into breed_name;
  insert into horses(owner_id,name,breed,sex,color,origin,birth_date,stats,image_url)
  values(null,names[1+floor(random()*array_length(names,1))::int],breed_name,(case when random()<0.5 then 'Mare' else 'Stallion' end)::horse_sex,colors[1+floor(random()*array_length(colors,1))::int],'Foundation',now()-(interval '1 day'*(49+floor(random()*49))),random_foundation_stats(),'/foundation-horse.png') returning id into h_id;
  return h_id;
end $$;

create or replace function public.refresh_store_inventory()
returns void language plpgsql security definer set search_path=public as $$
declare cfg store_settings; active_count integer; oldest timestamptz; rotation timestamptz; horse uuid; breed_name text; i integer;
begin
  perform pg_advisory_xact_lock(674381); select * into cfg from store_settings where singleton;
  select count(*),min(generated_at) into active_count,oldest from store_inventory where status='active';
  if active_count=0 or oldest<=now()-(cfg.rotation_minutes||' minutes')::interval then
    update store_inventory set status='expired' where status='active'; active_count:=0; rotation:=now();
  else rotation:=(select max(rotation_key) from store_inventory where status='active'); end if;
  for i in active_count+1..cfg.inventory_size loop
    select fb.name into breed_name from foundation_breeds fb where fb.active and not exists(select 1 from store_inventory si join horses h on h.id=si.horse_id where si.status='active' and h.breed=fb.name) order by random() limit 1;
    horse:=generate_store_horse(coalesce(rotation,now()),breed_name);
    insert into store_inventory(horse_id,price,rotation_key) values(horse,cfg.foundation_price,coalesce(rotation,now()));
  end loop;
end $$;

create or replace function public.get_store_inventory()
returns table(inventory_id uuid,horse_id uuid,name text,breed text,sex horse_sex,color text,birth_date timestamptz,stats jsonb,image_url text,price integer,generated_at timestamptz,rotation_key timestamptz)
language plpgsql security definer set search_path=public as $$
begin perform refresh_store_inventory(); return query select si.id,h.id,h.name,h.breed,h.sex,h.color,h.birth_date,h.stats,h.image_url,si.price,si.generated_at,si.rotation_key from store_inventory si join horses h on h.id=si.horse_id where si.status='active' order by si.generated_at,h.name; end $$;

drop function if exists public.purchase_foundation_horse();
create or replace function public.purchase_store_horse(target_inventory uuid)
returns public.horses language plpgsql security definer set search_path=public as $$
declare item store_inventory; h horses; s stables;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  perform pg_advisory_xact_lock(674381);
  select * into item from store_inventory where id=target_inventory for update;
  if not found or item.status<>'active' then raise exception 'That horse was just purchased by another stable. A new Foundation horse has arrived in the LE Store!'; end if;
  select * into s from stables where id=auth.uid() for update;
  if not found then raise exception 'Create your stable first'; end if;
  if s.foundation_purchases>=3 then raise exception 'Foundation purchase limit reached'; end if;
  if s.balance<item.price then raise exception 'Insufficient funds'; end if;
  update horses set owner_id=auth.uid() where id=item.horse_id and owner_id is null returning * into h;
  if not found then raise exception 'That horse is no longer available'; end if;
  update store_inventory set status='sold',sold_at=now(),sold_to=auth.uid() where id=item.id;
  update stables set balance=balance-item.price,foundation_purchases=foundation_purchases+1 where id=auth.uid();
  insert into currency_ledger(stable_id,amount,reason,horse_id) values(auth.uid(),-item.price,'LE Store purchase: '||h.name,h.id);
  perform refresh_store_inventory();
  return h;
end $$;

revoke all on function public.generate_store_horse(timestamptz,text),public.refresh_store_inventory(),public.get_store_inventory(),public.purchase_store_horse(uuid) from public;
grant execute on function public.get_store_inventory(),public.purchase_store_horse(uuid) to authenticated;
comment on table public.store_inventory is 'Shared global rotating LE Store inventory; sold and expired rows are permanent audit history.';
