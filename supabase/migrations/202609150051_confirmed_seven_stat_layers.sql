-- Confirmed seven-stat architecture: immutable Birth, permanent Developed, contextual Effective.
alter table public.horses add column if not exists birth_stats jsonb not null default '{}'::jsonb;
update public.stat_definitions set is_provisional=true where active;

update public.horses h set birth_stats=(
  select jsonb_object_agg(d.key,greatest(0,coalesce((h.stats->>d.key)::bigint,0)-coalesce(t.gain,0)))
  from public.stat_definitions d
  left join lateral(select sum(l.gain)::bigint gain from public.training_log l where l.horse_id=h.id and l.stat_key=d.key) t on true
  where d.active
) where birth_stats='{}'::jsonb;

create table if not exists public.stat_system_config(
 id boolean primary key default true check(id),
 confirmed_stat_count integer not null check(confirmed_stat_count=7),
 inheritance_variance_min integer not null,
 inheritance_variance_max integer not null,
 updated_at timestamptz not null default now(),
 check(inheritance_variance_min<=inheritance_variance_max)
);
insert into public.stat_system_config(id,confirmed_stat_count,inheritance_variance_min,inheritance_variance_max)
values(true,7,-6,6) on conflict(id) do update set confirmed_stat_count=excluded.confirmed_stat_count;
alter table public.stat_system_config enable row level security;
drop policy if exists "public stat system config" on public.stat_system_config;
create policy "public stat system config" on public.stat_system_config for select using(true);

create or replace function public.protect_horse_birth_stats() returns trigger language plpgsql set search_path=public as $$
begin
 if tg_op='INSERT' and coalesce(new.birth_stats,'{}'::jsonb)='{}'::jsonb then new.birth_stats:=new.stats;
 elsif tg_op='UPDATE' and new.birth_stats is distinct from old.birth_stats then raise exception 'Birth stats are permanent historical values';
 end if;
 return new;
end$$;
drop trigger if exists horse_birth_stats_immutable on public.horses;
create trigger horse_birth_stats_immutable before insert or update of birth_stats on public.horses for each row execute function public.protect_horse_birth_stats();

create or replace function public.breed_horses(stallion_id uuid,mare_id uuid) returns public.horses language plpgsql security definer set search_path=public as $$
declare sire horses;dam horses;foal horses;s stables;child_stats jsonb='{}';child_genetics jsonb;child_markings jsonb;child_visual jsonb;d record;baseline bigint;variance int;variance_min int;variance_max int;fee int;child_breed text;child_sex horse_sex;sire_age numeric;dam_age numeric;
begin
 if stallion_id=mare_id then raise exception 'Choose two different horses';end if;
 select * into sire from horses where id=stallion_id for update;select * into dam from horses where id=mare_id for update;
 if sire.id is null or dam.id is null or sire.owner_id<>auth.uid() or dam.owner_id<>auth.uid() then raise exception 'Both horses must be owned by you';end if;
 if sire.sanctuary_retired_at is not null or dam.sanctuary_retired_at is not null then raise exception 'Sanctuary horses are permanently retired';end if;
 if sire.sex<>'Stallion' or dam.sex<>'Mare' then raise exception 'Breeding requires a stallion and mare';end if;
 sire_age:=greatest(0,extract(epoch from(now()-sire.birth_date))/86400*30/365.25);dam_age:=greatest(0,extract(epoch from(now()-dam.birth_date))/86400*30/365.25);
 if sire_age<3 then raise exception 'The stallion is too young to breed. Eligible at age 3.';end if;if dam_age<3 then raise exception 'The mare is too young to breed. Eligible at age 3.';end if;
 if sire_age>=26 or sire.retired then raise exception 'The stallion is retired from breeding.';end if;if dam_age>=26 or dam.retired then raise exception 'The mare is retired from breeding.';end if;
 if dam.last_bred_at is not null and dam.last_bred_at>now()-interval '10 days' then raise exception 'Mare cooldown active';end if;
 select * into s from stables where id=auth.uid() for update;perform require_available_stall(s.id);
 child_genetics:=inherit_genetics(sire.genetics,dam.genetics);if is_lethal_genotype(child_genetics) then raise exception 'This breeding produced a non-viable lethal genotype. No foal was created and no fee was charged.';end if;
 fee:=sire.stud_fee;if s.balance<fee then raise exception 'Insufficient funds';end if;
 select inheritance_variance_min,inheritance_variance_max into variance_min,variance_max from stat_system_config where id=true;
 for d in select key from stat_definitions where active order by sort_order loop
  baseline:=round(((sire.stats->>d.key)::numeric+(dam.stats->>d.key)::numeric)/2)::bigint;
  variance:=variance_min+floor(random()*(variance_max-variance_min+1))::int;
  child_stats:=child_stats||jsonb_build_object(d.key,greatest(1,baseline+variance));
 end loop;
 child_breed:=resolve_crossbreed(sire.breed,dam.breed);child_sex:=(case when random()<.5 then 'Mare' else 'Stallion' end)::horse_sex;child_markings:=random_horse_markings(child_genetics,child_breed);child_visual:=build_visual_phenotype(child_breed,child_sex,0,child_genetics,child_markings);
 insert into horses(owner_id,name,breed,sex,color,origin,birth_date,sire_id,dam_id,generation,birth_stats,stats,genetics,breed_composition,image_url,markings,visual_phenotype,image_generation_status,image_prompt_version)
 values(s.id,'Unnamed Foal',child_breed,child_sex,genetic_color(child_genetics),'Bred',now(),sire.id,dam.id,greatest(sire.generation,dam.generation)+1,child_stats,child_stats,child_genetics,combine_breed_composition(sire.breed_composition,dam.breed_composition),'/foundation-horse.png',child_markings,child_visual,'pending','horse-v22') returning * into foal;
 insert into horse_ownership_history(horse_id,owner_id,acquired_at,acquisition_method) values(foal.id,s.id,now(),'Bred by Player');insert into store_horse_image_jobs(horse_id) values(foal.id);update horses set last_bred_at=now() where id=dam.id;update stables set balance=balance-fee where id=s.id;if fee>0 then insert into currency_ledger(stable_id,amount,reason,horse_id) values(s.id,-fee,'Stud fee',foal.id);end if;insert into breeding_records(owner_id,sire_id,dam_id,foal_id,stud_fee) values(s.id,sire.id,dam.id,foal.id,fee);return foal;
end$$;

create or replace function public.show_score_breakdown(target_horse uuid,weights jsonb,score_time timestamptz)
returns jsonb language sql stable security definer set search_path=public as $$
select coalesce(jsonb_object_agg(w.key,jsonb_build_object(
 'birth',coalesce((h.birth_stats->>w.key)::numeric,(h.stats->>w.key)::numeric,0),
 'development',greatest(0,coalesce((h.stats->>w.key)::numeric,0)-coalesce((h.birth_stats->>w.key)::numeric,(h.stats->>w.key)::numeric,0)),
 'developed',coalesce((h.stats->>w.key)::numeric,0),
 'base',coalesce((h.birth_stats->>w.key)::numeric,(h.stats->>w.key)::numeric,0),
 'training',greatest(0,coalesce((h.stats->>w.key)::numeric,0)-coalesce((h.birth_stats->>w.key)::numeric,(h.stats->>w.key)::numeric,0)),
 'tack',coalesce((h.tack_bonuses->>w.key)::numeric,0),
 'farrier',coalesce(sv.farrier,0),'massage',coalesce(sv.massage,0),'service',coalesce(sv.total,0),
 'effective',coalesce((h.stats->>w.key)::numeric,0)+coalesce((h.tack_bonuses->>w.key)::numeric,0)+coalesce(sv.total,0)
)),'{}'::jsonb)
from horses h cross join lateral jsonb_each(weights) w
left join lateral(select sum(coalesce((effect->>w.key)::numeric,0)) total,sum(coalesce((effect->>w.key)::numeric,0)) filter(where profession_id='farrier') farrier,sum(coalesce((effect->>w.key)::numeric,0)) filter(where profession_id='massage') massage from horse_service_records where horse_id=h.id and status='completed' and(effect_expires_at is null or effect_expires_at>score_time)) sv on true
where h.id=target_horse group by h.id
$$;

revoke all on function public.protect_horse_birth_stats(),public.breed_horses(uuid,uuid),public.show_score_breakdown(uuid,jsonb,timestamptz) from public;
grant execute on function public.breed_horses(uuid,uuid) to authenticated;
grant execute on function public.show_score_breakdown(uuid,jsonb,timestamptz) to service_role;
