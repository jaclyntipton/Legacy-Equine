create table public.stat_definitions (
  key text primary key,
  display_name text not null,
  sort_order integer not null unique,
  is_provisional boolean not null default false,
  active boolean not null default true
);
insert into public.stat_definitions(key,display_name,sort_order,is_provisional) values
('Agility','Agility',1,false),('Speed','Speed',2,false),('Endurance','Endurance',3,false),
('Temperament','Temperament',4,false),('Strength','Strength',5,true),
('Intelligence','Intelligence',6,true),('Conformation','Conformation',7,true);

create table public.breeding_records (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.stables(id),
  sire_id uuid not null references public.horses(id) on delete restrict,
  dam_id uuid not null references public.horses(id) on delete restrict,
  foal_id uuid not null unique references public.horses(id) on delete restrict,
  stud_fee integer not null check(stud_fee >= 0),
  created_at timestamptz not null default now()
);
alter table public.breeding_records enable row level security;
create policy "public breeding records" on public.breeding_records for select using (true);
create policy "public stat definitions" on public.stat_definitions for select using (true);
alter table public.stat_definitions enable row level security;

drop policy if exists "public stable profiles" on public.stables;
create policy "owner stable" on public.stables for select using (auth.uid() = id);

create or replace function public.initialize_stable(stable_name text)
returns public.stables language plpgsql security definer set search_path=public as $$
declare result public.stables;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into result from stables where id=auth.uid();
  if found then return result; end if;
  if length(trim(stable_name)) not between 2 and 60 then raise exception 'Stable name must be 2–60 characters'; end if;
  insert into stables(id,name,balance) values(auth.uid(),trim(stable_name),3000) returning * into result;
  insert into currency_ledger(stable_id,amount,reason) values(auth.uid(),3000,'Starting funds');
  return result;
exception when unique_violation then select * into result from stables where id=auth.uid(); return result;
end $$;

create or replace function public.random_foundation_stats()
returns jsonb language plpgsql volatile set search_path=public as $$
declare result jsonb='{}'; d record; value integer;
begin
  for d in select key from stat_definitions where active order by sort_order loop
    if random()<0.06 then value:=7+floor(random()*12)::int; else value:=10+floor(random()*6)::int; end if;
    result:=result||jsonb_build_object(d.key,value);
  end loop;
  return result;
end $$;

create or replace function public.purchase_foundation_horse()
returns public.horses language plpgsql security definer set search_path=public as $$
declare s stables; h horses; breeds text[]:=array['Thoroughbred','Arabian','Warmblood','Quarter Horse']; colors text[]:=array['Bay','Chestnut','Black','Gray','Palomino']; sexes horse_sex[]:=array['Mare','Stallion']::horse_sex[];
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into s from stables where id=auth.uid() for update;
  if not found then raise exception 'Create your stable first'; end if;
  if s.foundation_purchases>=3 then raise exception 'Foundation purchase limit reached'; end if;
  if s.balance<1000 then raise exception 'Insufficient funds'; end if;
  insert into horses(owner_id,name,breed,sex,color,origin,birth_date,stats,image_url)
  values(auth.uid(),'Unnamed Foundation Horse',breeds[1+floor(random()*array_length(breeds,1))::int],sexes[1+floor(random()*2)::int],colors[1+floor(random()*array_length(colors,1))::int],'Foundation',now()-(interval '1 day'*(49+floor(random()*49))),random_foundation_stats(),'/foundation-horse.png') returning * into h;
  update stables set balance=balance-1000,foundation_purchases=foundation_purchases+1 where id=auth.uid();
  insert into currency_ledger(stable_id,amount,reason,horse_id) values(auth.uid(),-1000,'Foundation horse purchase',h.id);
  return h;
end $$;

create or replace function public.train_horse(target_horse uuid, stat_name text)
returns public.horses language plpgsql security definer set search_path=public as $$
declare h horses;
begin
  select * into h from horses where id=target_horse for update;
  if not found or h.owner_id<>auth.uid() then raise exception 'Horse not found or not owned'; end if;
  if h.retired then raise exception 'Retired horses cannot train'; end if;
  if not exists(select 1 from stat_definitions where key=stat_name and active) then raise exception 'Invalid stat'; end if;
  if h.last_trained_at is not null and h.last_trained_at>now()-interval '20 hours' then raise exception 'Training cooldown active'; end if;
  update horses set stats=jsonb_set(stats,array[stat_name],to_jsonb(coalesce((stats->>stat_name)::int,0)+1)),last_trained_at=now() where id=h.id returning * into h;
  insert into training_log(horse_id,stable_id,stat_key,gain) values(h.id,auth.uid(),stat_name,1);
  return h;
end $$;

create or replace function public.breed_horses(stallion_id uuid, mare_id uuid)
returns public.horses language plpgsql security definer set search_path=public as $$
declare sire horses; dam horses; foal horses; s stables; child_stats jsonb='{}'; d record; baseline integer; variance integer; fee integer;
begin
  if stallion_id=mare_id then raise exception 'Choose two different horses'; end if;
  select * into sire from horses where id=stallion_id for update;
  select * into dam from horses where id=mare_id for update;
  if sire.owner_id<>auth.uid() or dam.owner_id<>auth.uid() then raise exception 'Both horses must be owned by you'; end if;
  if sire.sex<>'Stallion' or dam.sex<>'Mare' then raise exception 'Breeding requires a stallion and mare'; end if;
  if sire.retired or dam.retired then raise exception 'Retired horse is not eligible'; end if;
  if dam.last_bred_at is not null and dam.last_bred_at>now()-interval '10 days' then raise exception 'Mare cooldown active'; end if;
  fee:=sire.stud_fee; select * into s from stables where id=auth.uid() for update;
  if s.balance<fee then raise exception 'Insufficient funds'; end if;
  for d in select key from stat_definitions where active order by sort_order loop
    baseline:=round(((sire.stats->>d.key)::numeric+(dam.stats->>d.key)::numeric)/2)::int;
    variance:=floor(random()*13)::int-6; if random()<0.25 then variance:=variance-1; end if;
    child_stats:=child_stats||jsonb_build_object(d.key,greatest(1,baseline+variance));
  end loop;
  insert into horses(owner_id,name,breed,sex,color,origin,birth_date,sire_id,dam_id,generation,stats)
  values(auth.uid(),'Unnamed Foal',case when sire.breed=dam.breed then sire.breed else 'Crossbred' end,(case when random()<0.5 then 'Mare' else 'Stallion' end)::horse_sex,case when random()<0.5 then sire.color else dam.color end,'Bred',now(),sire.id,dam.id,greatest(sire.generation,dam.generation)+1,child_stats) returning * into foal;
  update horses set last_bred_at=now() where id=dam.id;
  update stables set balance=balance-fee where id=auth.uid();
  if fee>0 then insert into currency_ledger(stable_id,amount,reason,horse_id) values(auth.uid(),-fee,'Stud fee',foal.id); end if;
  insert into breeding_records(owner_id,sire_id,dam_id,foal_id,stud_fee) values(auth.uid(),sire.id,dam.id,foal.id,fee);
  return foal;
end $$;

create or replace function public.update_horse_profile(target_horse uuid,new_name text,new_biography text,new_image_url text)
returns public.horses language plpgsql security definer set search_path=public as $$
declare h horses;
begin
  if length(trim(new_name)) not between 1 and 80 then raise exception 'Horse name is required'; end if;
  update horses set name=trim(new_name),biography=left(coalesce(new_biography,''),1000),image_url=left(coalesce(new_image_url,''),2048)
  where id=target_horse and owner_id=auth.uid() returning * into h;
  if not found then raise exception 'Horse not found or not owned'; end if; return h;
end $$;

revoke all on function public.random_foundation_stats() from public;
revoke all on function public.initialize_stable(text) from public;
revoke all on function public.purchase_foundation_horse() from public;
revoke all on function public.train_horse(uuid,text) from public;
revoke all on function public.breed_horses(uuid,uuid) from public;
revoke all on function public.update_horse_profile(uuid,text,text,text) from public;
grant execute on function public.initialize_stable(text),public.purchase_foundation_horse(),public.train_horse(uuid,text),public.breed_horses(uuid,uuid),public.update_horse_profile(uuid,text,text,text) to authenticated;
