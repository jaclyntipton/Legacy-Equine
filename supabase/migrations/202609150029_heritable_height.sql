create table public.breed_height_ranges(
 breed text primary key,
 minimum_hands numeric(4,1) not null,
 maximum_hands numeric(4,1) not null,
 check(minimum_hands>=8 and maximum_hands<=22 and minimum_hands<maximum_hands)
);
insert into public.breed_height_ranges values
 ('Arabian',14.1,15.1),('Quarter Horse',14.2,16.0),('Thoroughbred',15.2,17.0),('Hanoverian',15.3,17.2),
 ('Appaloosa',14.2,16.0),('Morgan',14.1,15.2),('Rocky Mountain Horse',14.0,16.0),('Tennessee Walking Horse',14.3,17.0);
alter table public.breed_height_ranges enable row level security;
create policy "public breed height ranges" on public.breed_height_ranges for select using(true);

alter table public.horses add column height_genetics jsonb not null default '{}';
alter table public.horses add column mature_height_hands numeric(4,1);

create or replace function public.random_height_genetics()
returns jsonb language sql volatile as $$ select jsonb_build_object(
 'LCORL',jsonb_build_array(case when random()<.5 then 'L' else 'S' end,case when random()<.5 then 'L' else 'S' end),
 'HMGA2',jsonb_build_array(case when random()<.5 then 'L' else 'S' end,case when random()<.5 then 'L' else 'S' end),
 'ZFAT',jsonb_build_array(case when random()<.5 then 'L' else 'S' end,case when random()<.5 then 'L' else 'S' end),
 'LASP1',jsonb_build_array(case when random()<.5 then 'L' else 'S' end,case when random()<.5 then 'L' else 'S' end)
) $$;

create or replace function public.inherit_height_genetics(a jsonb,b jsonb)
returns jsonb language plpgsql volatile as $$
declare result jsonb='{}';locus text;av jsonb;bv jsonb;begin
 foreach locus in array array['LCORL','HMGA2','ZFAT','LASP1'] loop
  av:=coalesce(a->locus,'["S","L"]'::jsonb);bv:=coalesce(b->locus,'["S","L"]'::jsonb);
  result:=result||jsonb_build_object(locus,jsonb_build_array(av->(floor(random()*2)::int),bv->(floor(random()*2)::int)));
 end loop;return result;
end $$;

create or replace function public.height_large_alleles(g jsonb)
returns integer language sql immutable as $$
 select count(*)::int from jsonb_each(coalesce(g,'{}'::jsonb)) loci cross join lateral jsonb_array_elements_text(loci.value) allele where allele.value='L'
$$;

create or replace function public.express_mature_height(g jsonb,min_h numeric,max_h numeric)
returns numeric language plpgsql volatile as $$
declare midpoint numeric:=(min_h+max_h)/2;half_range numeric:=(max_h-min_h)/2;large_count integer:=height_large_alleles(g);result numeric;begin
 result:=midpoint+((large_count-4)::numeric/4)*(half_range*.88)+((random()-.5)*.20);
 return round(greatest(min_h,least(max_h,result)),1);
end $$;

create or replace function public.assign_horse_height()
returns trigger language plpgsql set search_path=public as $$
declare sire_h horses;dam_h horses;min_h numeric;max_h numeric;begin
 if new.sire_id is not null and new.dam_id is not null then
  select * into sire_h from horses where id=new.sire_id;select * into dam_h from horses where id=new.dam_id;
 end if;
 if new.height_genetics='{}'::jsonb then
  new.height_genetics:=case when sire_h.id is not null and dam_h.id is not null then inherit_height_genetics(sire_h.height_genetics,dam_h.height_genetics) else random_height_genetics() end;
 end if;
 select minimum_hands,maximum_hands into min_h,max_h from breed_height_ranges where breed=new.breed;
 if min_h is null then
  if sire_h.mature_height_hands is not null and dam_h.mature_height_hands is not null then min_h:=greatest(8,least(sire_h.mature_height_hands,dam_h.mature_height_hands)-1);max_h:=least(22,greatest(sire_h.mature_height_hands,dam_h.mature_height_hands)+1);else min_h:=14;max_h:=17;end if;
 end if;
 if new.mature_height_hands is null then new.mature_height_hands:=express_mature_height(new.height_genetics,min_h,max_h);end if;
 new.visual_phenotype:=jsonb_set(coalesce(new.visual_phenotype,'{}'::jsonb),'{height_hands}',to_jsonb(new.mature_height_hands),true);
 return new;
end $$;

create trigger assign_horse_height_before_insert before insert on public.horses for each row execute function public.assign_horse_height();

update public.horses h set height_genetics=random_height_genetics();
update public.horses h set mature_height_hands=express_mature_height(h.height_genetics,r.minimum_hands,r.maximum_hands)
from public.breed_height_ranges r where r.breed=h.breed;
update public.horses h set mature_height_hands=round(coalesce((select (s.mature_height_hands+d.mature_height_hands)/2 from horses s,horses d where s.id=h.sire_id and d.id=h.dam_id),15.0),1)
where h.mature_height_hands is null;
update public.horses set visual_phenotype=jsonb_set(visual_phenotype,'{height_hands}',to_jsonb(mature_height_hands),true);
alter table public.horses alter column mature_height_hands set not null;

drop function public.get_store_inventory();
create function public.get_store_inventory()
returns table(inventory_id uuid,horse_id uuid,name text,breed text,sex horse_sex,color text,birth_date timestamptz,stats jsonb,image_url text,mature_height_hands numeric,price integer,generated_at timestamptz,rotation_key timestamptz)
language plpgsql security definer set search_path=public as $$
begin perform refresh_store_inventory();return query select si.id,h.id,h.name,h.breed,h.sex,h.color,h.birth_date,h.stats,h.image_url,h.mature_height_hands,si.price,si.generated_at,si.rotation_key from store_inventory si join horses h on h.id=si.horse_id where si.status='active' order by si.generated_at,h.name;end $$;
grant execute on function public.get_store_inventory() to authenticated,anon;

update public.horses h set image_generation_status='pending',image_prompt_version='horse-v9'
where (h.owner_id is not null or exists(select 1 from public.store_inventory si where si.horse_id=h.id and si.status='active'))
and (coalesce(h.image_url,'') in ('','/foundation-horse.png') or h.image_url like '%/generated/%');
insert into public.store_horse_image_jobs(horse_id,status,attempts,next_attempt_at,last_error,completed_at)
select h.id,'pending',0,now(),null,null from public.horses h where (h.owner_id is not null or exists(select 1 from public.store_inventory si where si.horse_id=h.id and si.status='active')) and (coalesce(h.image_url,'') in ('','/foundation-horse.png') or h.image_url like '%/generated/%')
on conflict(horse_id) do update set status='pending',attempts=0,next_attempt_at=now(),last_error=null,completed_at=null;

revoke all on function public.random_height_genetics(),public.inherit_height_genetics(jsonb,jsonb),public.height_large_alleles(jsonb),public.express_mature_height(jsonb,numeric,numeric) from public;
comment on column public.horses.height_genetics is 'Inherited game model of major equine height loci; L/S are directional gameplay alleles, not diagnostic test calls.';
comment on column public.horses.mature_height_hands is 'Permanent genetically expressed adult height measured at the withers in hands.';
