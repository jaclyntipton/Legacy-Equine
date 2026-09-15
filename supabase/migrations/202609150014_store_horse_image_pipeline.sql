alter table public.horses add column markings jsonb not null default '{"face":"none","left_front":"none","right_front":"none","left_hind":"none","right_hind":"none"}';
alter table public.horses add column visual_phenotype jsonb not null default '{}';
alter table public.horses add column image_generation_status text not null default 'not_requested' check(image_generation_status in ('not_requested','pending','processing','complete','failed'));
alter table public.horses add column image_prompt_version text;

create table public.breed_visual_archetypes(
  breed text primary key,
  body_description text not null
);
insert into public.breed_visual_archetypes values
('Quarter Horse','compact stock-horse build, powerful rounded hindquarters, substantial shoulder, balanced medium bone'),
('Arabian','refined light frame, subtly dished refined head, arched neck, short back, naturally high tail carriage'),
('Thoroughbred','lean athletic sport and racing build, long legs, deep heartgirth, refined head, long clean lines'),
('Hanoverian','substantial elegant warmblood sport-horse frame, athletic hindquarters, long balanced lines'),
('Appaloosa','balanced stock-horse build, strong hindquarters, solid bone, practical athletic conformation'),
('Morgan','compact substantial build, expressive head, upright arched neck, deep body, powerful hindquarters'),
('Rocky Mountain Horse','medium refined gaited-horse build, sloping shoulder, compact body, graceful neck'),
('Tennessee Walking Horse','tall smooth-lined gaited-horse build, long sloping shoulder, refined neck and athletic hindquarters');

create table public.store_horse_image_jobs(
  id uuid primary key default gen_random_uuid(),
  horse_id uuid not null unique references public.horses(id) on delete cascade,
  status text not null default 'pending' check(status in ('pending','processing','complete','failed')),
  attempts integer not null default 0,
  prompt text,
  last_error text,
  next_attempt_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  completed_at timestamptz
);
alter table public.store_horse_image_jobs enable row level security;

create or replace function public.random_horse_markings(g jsonb)
returns jsonb language plpgsql volatile as $$
declare white_bias numeric:=case when gene_count(g,'Sabino1','SB1')>0 or gene_count(g,'Splash1','SW1')>0 or gene_count(g,'Frame','O')>0 then .55 else .22 end;
face_options text[]:=array['star','snip','stripe','blaze','bald face'];leg_options text[]:=array['coronet','pastern','sock','stocking'];
begin return jsonb_build_object(
 'face',case when random()<white_bias then face_options[1+floor(random()*array_length(face_options,1))::int] else 'none' end,
 'left_front',case when random()<white_bias then leg_options[1+floor(random()*array_length(leg_options,1))::int] else 'none' end,
 'right_front',case when random()<white_bias then leg_options[1+floor(random()*array_length(leg_options,1))::int] else 'none' end,
 'left_hind',case when random()<white_bias then leg_options[1+floor(random()*array_length(leg_options,1))::int] else 'none' end,
 'right_hind',case when random()<white_bias then leg_options[1+floor(random()*array_length(leg_options,1))::int] else 'none' end);end $$;

create or replace function public.genetic_color(g jsonb)
returns text language plpgsql immutable as $$
declare base text;result text;cream int:=gene_count(g,'Cream','Cr');begin
 if gene_count(g,'Extension','E')=0 then base:='Chestnut';elsif gene_count(g,'Agouti','A')>0 then base:='Bay';else base:='Black';end if;
 result:=base;
 if cream=1 then result:=case base when 'Chestnut' then 'Palomino' when 'Bay' then 'Buckskin' else 'Smoky Black' end;
 elsif cream=2 then result:=case base when 'Chestnut' then 'Cremello' when 'Bay' then 'Perlino' else 'Smoky Cream' end;end if;
 if gene_count(g,'Pearl','Prl')=2 or (gene_count(g,'Pearl','Prl')=1 and cream=1) then result:=result||' Pearl';end if;
 if gene_count(g,'Dun','D')>0 then result:=case when cream=0 then case base when 'Chestnut' then 'Red Dun' when 'Bay' then 'Bay Dun' else 'Grullo' end else result||' Dun' end;end if;
 if gene_count(g,'Champagne','Ch')>0 then result:=result||' Champagne';end if;
 if gene_count(g,'Silver','Z')>0 and base<>'Chestnut' then result:=result||' Silver';end if;
 if gene_count(g,'Mushroom','Mu')=2 and base='Chestnut' then result:='Mushroom Chestnut';end if;
 if gene_count(g,'Roan','Rn')>0 then result:=case when cream=0 and base='Black' then 'Blue Roan' when cream=0 and base='Bay' then 'Bay Roan' when cream=0 and base='Chestnut' then 'Red Roan' else result||' Roan' end;end if;
 if gene_count(g,'Gray','G')>0 then result:='Gray ('||result||' base)';end if;
 if gene_count(g,'Tobiano','TO')>0 then result:=result||' Tobiano';end if;
 if gene_count(g,'Frame','O')=1 then result:=result||' Frame Overo';end if;
 if gene_count(g,'Sabino1','SB1')>0 then result:=result||' Sabino';end if;
 if gene_count(g,'Splash1','SW1')>0 or gene_count(g,'Splash2','SW2')>0 or gene_count(g,'Splash3','SW3')>0 or gene_count(g,'Splash5','SW5')>0 or gene_count(g,'Splash6','SW6')>0 or gene_count(g,'Splash7','SW7')>0 or gene_count(g,'Splash8','SW8')>0 then result:=result||' Splashed White';end if;
 if gene_count(g,'Leopard','LP')>0 then result:=result||case when gene_count(g,'PATN1','PATN1')>0 then ' Leopard Appaloosa' else ' Appaloosa Pattern' end;end if;
 if gene_count(g,'W5','W5')=1 or gene_count(g,'W10','W10')=1 or gene_count(g,'W13','W13')=1 or gene_count(g,'W20','W20')>0 or gene_count(g,'W22','W22')=1 then result:=result||' Dominant White';end if;
 return trim(result);end $$;

create or replace function public.build_visual_phenotype(b text,s horse_sex,age_years numeric,g jsonb,m jsonb)
returns jsonb language plpgsql stable as $$
declare color_name text:=genetic_color(g);body text;pattern text:='solid';mane text:='coat-appropriate dark mane and tail';begin
 select body_description into body from breed_visual_archetypes where breed=b;
 body:=coalesce(body,'realistic balanced medium sport-horse build appropriate to the named breed, without caricature');
 if color_name ilike '%Palomino%' or color_name ilike '%Cremello%' or color_name ilike '%Perlino%' then mane:='light cream to flaxen mane and tail';
 elsif color_name ilike '%Silver%' then mane:='genetically silver-diluted mane and tail';elsif color_name ilike '%Chestnut%' or color_name ilike '%Red Dun%' or color_name ilike '%Red Roan%' then mane:='red or flaxen coat-appropriate mane and tail';end if;
 if gene_count(g,'Tobiano','TO')>0 then pattern:='tobiano white spotting';elsif gene_count(g,'Frame','O')=1 then pattern:='frame overo white spotting';elsif gene_count(g,'Sabino1','SB1')>0 then pattern:='sabino white pattern';elsif gene_count(g,'Splash1','SW1')>0 then pattern:='splashed white pattern';elsif gene_count(g,'Leopard','LP')>0 then pattern:='leopard complex Appaloosa pattern';end if;
 return jsonb_build_object('breed',b,'sex',s,'age_years',age_years,'color',color_name,'body',body,'coat',color_name,'mane_tail',mane,'pattern',pattern,'face_marking',m->>'face','left_front',m->>'left_front','right_front',m->>'right_front','left_hind',m->>'left_hind','right_hind',m->>'right_hind','pose','standing square','view','side or subtle three-quarter profile','background','neutral light Legacy Equine studio');end $$;

create or replace function public.generate_store_horse(p_rotation timestamptz,p_preferred_breed text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare h_id uuid;breed_name text;g jsonb;m jsonb;visual jsonb;horse_sex_value horse_sex;begin
 select coalesce(p_preferred_breed,(select name from foundation_breeds where active order by random() limit 1)) into breed_name;
 g:=random_foundation_genetics(breed_name);m:=random_horse_markings(g);horse_sex_value:=(case when random()<.5 then 'Mare' else 'Stallion' end)::horse_sex;visual:=build_visual_phenotype(breed_name,horse_sex_value,2,g,m);
 insert into horses(owner_id,name,breed,sex,color,origin,birth_date,stats,image_url,genetics,breed_composition,markings,visual_phenotype,image_generation_status,image_prompt_version)
 values(null,'Unnamed Foundation Horse',breed_name,horse_sex_value,genetic_color(g),'Foundation',now()-(interval '1 day'*(2*365.25/30)),random_foundation_stats(),'/foundation-horse.png',g,jsonb_build_object(breed_name,1),m,visual,'pending','store-horse-v1') returning id into h_id;
 insert into store_horse_image_jobs(horse_id) values(h_id);return h_id;end $$;

update horses h set color=genetic_color(h.genetics),markings=random_horse_markings(h.genetics),image_generation_status='pending',image_prompt_version='store-horse-v1'
from store_inventory si where si.horse_id=h.id and si.status='active' and h.image_url='/foundation-horse.png';
update horses h set visual_phenotype=build_visual_phenotype(h.breed,h.sex,2,h.genetics,h.markings)
from store_inventory si where si.horse_id=h.id and si.status='active' and h.image_generation_status='pending';
insert into store_horse_image_jobs(horse_id) select h.id from horses h join store_inventory si on si.horse_id=h.id where si.status='active' and h.image_generation_status='pending' on conflict(horse_id) do nothing;

create or replace function public.genetics_for_visual(desired_color text,desired_pattern text)
returns jsonb language plpgsql immutable as $$
declare c text:=lower(trim(desired_color));p text:=lower(trim(desired_pattern));g jsonb:=jsonb_build_object('Extension','["E","E"]'::jsonb,'Agouti','["A","A"]'::jsonb,'Cream','["N","N"]'::jsonb,'Dun','["N","N"]'::jsonb,'Gray','["N","N"]'::jsonb,'Roan','["N","N"]'::jsonb,'Tobiano','["N","N"]'::jsonb,'Frame','["N","N"]'::jsonb,'Silver','["N","N"]'::jsonb,'Champagne','["N","N"]'::jsonb,'Pearl','["N","N"]'::jsonb,'Sabino1','["N","N"]'::jsonb,'Splash1','["N","N"]'::jsonb);begin
 if c in('chestnut','sorrel','palomino','cremello','red dun','red roan','strawberry roan') then g:=g||'{"Extension":["N","N"],"Agouti":["A","A"]}'::jsonb;elsif c in('black','smoky black','smoky cream','grullo','blue roan') then g:=g||'{"Extension":["E","E"],"Agouti":["N","N"]}'::jsonb;end if;
 if c in('palomino','buckskin','smoky black') then g:=g||'{"Cream":["Cr","N"]}'::jsonb;elsif c in('cremello','perlino','smoky cream') then g:=g||'{"Cream":["Cr","Cr"]}'::jsonb;end if;
 if c in('bay dun','red dun','grullo') then g:=g||'{"Dun":["D","N"]}'::jsonb;end if;if c='gray' then g:=g||'{"Gray":["G","N"]}'::jsonb;end if;if c in('blue roan','bay roan','red roan','strawberry roan') then g:=g||'{"Roan":["Rn","N"]}'::jsonb;end if;
 if p='tobiano' then g:=g||'{"Tobiano":["TO","N"]}'::jsonb;elsif p='frame overo' then g:=g||'{"Frame":["O","N"]}'::jsonb;elsif p='sabino' then g:=g||'{"Sabino1":["SB1","N"]}'::jsonb;elsif p='splashed white' then g:=g||'{"Splash1":["SW1","N"]}'::jsonb;end if;return g;end $$;

create or replace function public.admin_create_visual_horse(target_owner uuid,horse_name text,horse_species text,horse_breed text,horse_sex text,horse_age_years numeric,desired_color text,desired_pattern text,desired_markings jsonb,horse_stats jsonb,advanced_genetics jsonb default '{}',horse_image_url text default '')
returns public.horses language plpgsql security definer set search_path=public as $$
declare result horses;stat record;g jsonb;visual jsonb;m jsonb;sex_value horse_sex;begin
 perform require_admin();if not exists(select 1 from stables where id=target_owner) then raise exception 'Owner stable not found';end if;
 if length(trim(horse_name)) not between 1 and 80 or length(trim(horse_breed)) not between 1 and 80 or length(trim(horse_species)) not between 1 and 80 then raise exception 'Name, species, and breed are required';end if;if horse_sex not in('Mare','Stallion') then raise exception 'Sex must be Mare or Stallion';end if;if horse_age_years<0 or horse_age_years>100 then raise exception 'Age must be between 0 and 100';end if;
 for stat in select key from stat_definitions where active loop if jsonb_typeof(horse_stats->stat.key)<>'number' or (horse_stats->>stat.key)::numeric<0 or (horse_stats->>stat.key)::numeric>1000000 then raise exception 'Every stat must be a number between 0 and 1,000,000';end if;end loop;
 g:=case when coalesce(advanced_genetics,'{}')<>'{}' then advanced_genetics else genetics_for_visual(desired_color,desired_pattern) end;m:=coalesce(desired_markings,'{}');sex_value:=horse_sex::horse_sex;visual:=build_visual_phenotype(trim(horse_breed),sex_value,horse_age_years,g,m);
 insert into horses(owner_id,name,species,breed,sex,color,origin,birth_date,stats,genetics,breed_composition,image_url,custom_traits,is_admin_custom,markings,visual_phenotype,image_generation_status,image_prompt_version)
 values(target_owner,trim(horse_name),trim(horse_species),trim(horse_breed),sex_value,genetic_color(g),'Admin Custom',now()-(interval '1 day'*(horse_age_years*365.25/30)),horse_stats,g,jsonb_build_object(trim(horse_breed),1),coalesce(nullif(horse_image_url,''),'/foundation-horse.png'),'[]',true,m,visual,case when coalesce(horse_image_url,'')='' then 'pending' else 'complete' end,'store-horse-v1') returning * into result;
 if coalesce(horse_image_url,'')='' then insert into store_horse_image_jobs(horse_id) values(result.id);end if;return result;end $$;

create or replace function public.claim_store_horse_image_job()
returns table(job_id uuid,horse_id uuid,visual_phenotype jsonb,markings jsonb) language plpgsql security definer set search_path=public as $$
declare chosen uuid;begin
 if auth.role()<>'service_role' then raise exception 'Service role required';end if;
 select j.id into chosen from store_horse_image_jobs j join horses h on h.id=j.horse_id left join store_inventory si on si.horse_id=j.horse_id and si.status='active' where j.status='pending' and j.next_attempt_at<=now() and (si.id is not null or h.is_admin_custom) order by j.created_at for update of j skip locked limit 1;
 if chosen is null then return;end if;
 update store_horse_image_jobs set status='processing',attempts=attempts+1 where id=chosen;
 update horses set image_generation_status='processing' where id=(select j.horse_id from store_horse_image_jobs j where j.id=chosen);
 return query select j.id,h.id,h.visual_phenotype,h.markings from store_horse_image_jobs j join horses h on h.id=j.horse_id where j.id=chosen;end $$;

revoke all on function public.random_horse_markings(jsonb),public.build_visual_phenotype(text,horse_sex,numeric,jsonb,jsonb),public.genetics_for_visual(text,text),public.admin_create_visual_horse(uuid,text,text,text,text,numeric,text,text,jsonb,jsonb,jsonb,text),public.claim_store_horse_image_job() from public;
grant execute on function public.admin_create_visual_horse(uuid,text,text,text,text,numeric,text,text,jsonb,jsonb,jsonb,text) to authenticated;
grant execute on function public.claim_store_horse_image_job() to service_role;
