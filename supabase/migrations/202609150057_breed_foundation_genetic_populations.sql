-- Breed-population frequencies constrain Foundation generation only. Once a
-- horse exists, its stored diploid genotype remains authoritative for breeding.
insert into public.foundation_breeds(name,sort_order) values('American Paint Horse',9) on conflict(name) do update set active=true;

insert into public.breed_visual_archetypes(breed,body_description,height_range,movement_description,temperament_description,breed_constraints,source_organization,source_url)
values('American Paint Horse','balanced, muscular American stock-horse conformation with a short strong back, deep chest, sloping shoulder and powerful rounded hindquarters','typically 14.2–16 hands','balanced agile stock-horse movement with strong drive from behind','willing, intelligent and versatile','Paint is a breed, not a color. Preserve practical stock-horse conformation while allowing registry-appropriate white pattern expression.','American Paint Horse Association','https://apha.com/')
on conflict(breed) do update set body_description=excluded.body_description,height_range=excluded.height_range,movement_description=excluded.movement_description,temperament_description=excluded.temperament_description,breed_constraints=excluded.breed_constraints,source_organization=excluded.source_organization,source_url=excluded.source_url;

create table public.breed_foundation_genetic_population(
 breed text not null references public.foundation_breeds(name) on update cascade,
 locus text not null,allele text not null,category text not null check(category in('base','dilution','white_pattern','modifier','health')),
 allele_frequency numeric(9,8) not null default 0 check(allele_frequency between 0 and 1),
 rarity text not null default 'not_generated' check(rarity in('common','uncommon','rare','exceptional','not_generated')),
 foundation_generated boolean not null default false,notes text not null default '',updated_at timestamptz not null default now(),updated_by uuid references public.stables(id),
 primary key(breed,locus)
);
alter table public.breed_foundation_genetic_population enable row level security;

with loci(locus,allele,category) as(values
 ('Extension','E','base'),('Agouti','A','base'),('Cream','Cr','dilution'),('Dun','D','dilution'),('Champagne','Ch','dilution'),('Silver','Z','dilution'),('Pearl','Prl','dilution'),
 ('Gray','G','modifier'),('Roan','Rn','modifier'),('Tobiano','TO','white_pattern'),('Frame','O','white_pattern'),('Sabino1','SB1','white_pattern'),
 ('Splash1','SW1','white_pattern'),('Splash2','SW2','white_pattern'),('Splash3','SW3','white_pattern'),('Splash5','SW5','white_pattern'),('Splash6','SW6','white_pattern'),('Splash7','SW7','white_pattern'),('Splash8','SW8','white_pattern'),
 ('Leopard','LP','white_pattern'),('PATN1','PATN1','white_pattern'),('Mushroom','Mu','dilution'),('W5','W5','white_pattern'),('W10','W10','white_pattern'),('W13','W13','white_pattern'),('W20','W20','white_pattern'),('W22','W22','white_pattern'),
 ('GBED','G','health'),('HERDA','H','health'),('HYPP','H','health'),('PSSM1','P1','health'),('SCID','S','health'),('LFS','L','health'),('CA','C','health'),('OAAM','O','health')
)
insert into public.breed_foundation_genetic_population(breed,locus,allele,category)
select b.name,l.locus,l.allele,l.category from public.foundation_breeds b cross join loci l on true on conflict do nothing;

-- Explicit per-allele frequencies. Values are adjustable by Admin and are not
-- breeding odds: each Foundation chromosome independently samples the allele.
with weights(breed,locus,frequency,rarity) as(values
 ('Quarter Horse','Extension',.75,'common'),('Quarter Horse','Agouti',.55,'common'),('Quarter Horse','Cream',.07,'uncommon'),('Quarter Horse','Dun',.05,'uncommon'),('Quarter Horse','Pearl',.008,'rare'),('Quarter Horse','Gray',.012,'rare'),('Quarter Horse','Roan',.06,'uncommon'),('Quarter Horse','Sabino1',.004,'rare'),('Quarter Horse','Tobiano',.00010,'exceptional'),('Quarter Horse','Frame',.00010,'exceptional'),('Quarter Horse','Splash1',.00025,'exceptional'),('Quarter Horse','W10',.0005,'exceptional'),('Quarter Horse','W20',.001,'exceptional'),('Quarter Horse','GBED',.02,'rare'),('Quarter Horse','HERDA',.02,'rare'),('Quarter Horse','HYPP',.01,'rare'),('Quarter Horse','PSSM1',.025,'rare'),
 ('Thoroughbred','Extension',.79,'common'),('Thoroughbred','Agouti',.69,'common'),('Thoroughbred','Gray',.105,'uncommon'),('Thoroughbred','Cream',.0002,'exceptional'),('Thoroughbred','Sabino1',.00010,'exceptional'),('Thoroughbred','Splash1',.00005,'exceptional'),('Thoroughbred','W5',.0005,'exceptional'),('Thoroughbred','W20',.001,'exceptional'),('Thoroughbred','PSSM1',.003,'rare'),
 ('American Paint Horse','Extension',.74,'common'),('American Paint Horse','Agouti',.54,'common'),('American Paint Horse','Cream',.07,'uncommon'),('American Paint Horse','Dun',.045,'uncommon'),('American Paint Horse','Gray',.015,'rare'),('American Paint Horse','Roan',.045,'uncommon'),('American Paint Horse','Tobiano',.32,'common'),('American Paint Horse','Frame',.10,'common'),('American Paint Horse','Sabino1',.07,'uncommon'),('American Paint Horse','Splash1',.07,'uncommon'),('American Paint Horse','Splash2',.008,'rare'),('American Paint Horse','W20',.012,'rare'),('American Paint Horse','GBED',.018,'rare'),('American Paint Horse','HERDA',.018,'rare'),('American Paint Horse','HYPP',.006,'rare'),('American Paint Horse','PSSM1',.022,'rare'),
 ('Arabian','Extension',.72,'common'),('Arabian','Agouti',.62,'common'),('Arabian','Gray',.16,'uncommon'),('Arabian','Sabino1',.004,'rare'),('Arabian','W20',.002,'exceptional'),('Arabian','SCID',.025,'rare'),('Arabian','LFS',.02,'rare'),('Arabian','CA',.02,'rare'),('Arabian','OAAM',.01,'rare'),
 ('Hanoverian','Extension',.76,'common'),('Hanoverian','Agouti',.67,'common'),('Hanoverian','Gray',.10,'uncommon'),('Hanoverian','Cream',.001,'exceptional'),('Hanoverian','W20',.001,'exceptional'),('Hanoverian','PSSM1',.004,'rare'),
 ('Appaloosa','Extension',.72,'common'),('Appaloosa','Agouti',.58,'common'),('Appaloosa','Cream',.045,'uncommon'),('Appaloosa','Dun',.055,'uncommon'),('Appaloosa','Gray',.02,'rare'),('Appaloosa','Roan',.05,'uncommon'),('Appaloosa','Leopard',.55,'common'),('Appaloosa','PATN1',.30,'common'),('Appaloosa','W10',.002,'exceptional'),('Appaloosa','GBED',.018,'rare'),('Appaloosa','HERDA',.018,'rare'),('Appaloosa','PSSM1',.022,'rare'),
 ('Morgan','Extension',.72,'common'),('Morgan','Agouti',.60,'common'),('Morgan','Cream',.045,'uncommon'),('Morgan','Silver',.035,'rare'),('Morgan','Roan',.012,'rare'),('Morgan','Sabino1',.004,'rare'),('Morgan','W20',.001,'exceptional'),('Morgan','PSSM1',.004,'rare'),
 ('Rocky Mountain Horse','Extension',.74,'common'),('Rocky Mountain Horse','Agouti',.58,'common'),('Rocky Mountain Horse','Champagne',.025,'rare'),('Rocky Mountain Horse','Silver',.16,'uncommon'),('Rocky Mountain Horse','Cream',.02,'rare'),
 ('Tennessee Walking Horse','Extension',.72,'common'),('Tennessee Walking Horse','Agouti',.58,'common'),('Tennessee Walking Horse','Cream',.06,'uncommon'),('Tennessee Walking Horse','Champagne',.025,'rare'),('Tennessee Walking Horse','Silver',.045,'rare'),('Tennessee Walking Horse','Gray',.025,'rare'),('Tennessee Walking Horse','Roan',.045,'uncommon'),('Tennessee Walking Horse','Tobiano',.025,'rare'),('Tennessee Walking Horse','Sabino1',.035,'rare'),('Tennessee Walking Horse','Splash1',.015,'rare')
)
update public.breed_foundation_genetic_population p set allele_frequency=w.frequency,rarity=w.rarity,foundation_generated=true,notes='Initial LE breed-population configuration'
from weights w where p.breed=w.breed and p.locus=w.locus;

create table public.breed_foundation_genetic_audit(id uuid primary key default gen_random_uuid(),breed text not null,locus text not null,old_frequency numeric,new_frequency numeric,old_generated boolean,new_generated boolean,old_rarity text,new_rarity text,changed_by uuid references public.stables(id),reason text not null default '',changed_at timestamptz not null default now());
alter table public.breed_foundation_genetic_audit enable row level security;

create or replace function public.population_gene_pair(p_breed text,p_locus text) returns jsonb language plpgsql volatile security definer set search_path=public as $$
declare f numeric:=0;a text:='N';begin select case when foundation_generated then allele_frequency else 0 end,allele into f,a from breed_foundation_genetic_population where breed=p_breed and locus=p_locus;return jsonb_build_array(case when random()<f then a else 'N' end,case when random()<f then a else 'N' end);end$$;

create or replace function public.random_foundation_genetics(b text) returns jsonb language sql volatile security definer set search_path=public as $$select jsonb_build_object(
 'Extension',population_gene_pair(b,'Extension'),'Agouti',population_gene_pair(b,'Agouti'),'Cream',population_gene_pair(b,'Cream'),'Dun',population_gene_pair(b,'Dun'),'Champagne',population_gene_pair(b,'Champagne'),'Silver',population_gene_pair(b,'Silver'),'Pearl',population_gene_pair(b,'Pearl'),'Gray',population_gene_pair(b,'Gray'),'Roan',population_gene_pair(b,'Roan'),'Tobiano',population_gene_pair(b,'Tobiano'),'Frame',population_gene_pair(b,'Frame'),'Sabino1',population_gene_pair(b,'Sabino1'),'Splash1',population_gene_pair(b,'Splash1'),'Splash2',population_gene_pair(b,'Splash2'),'Splash3',population_gene_pair(b,'Splash3'),'Splash5',population_gene_pair(b,'Splash5'),'Splash6',population_gene_pair(b,'Splash6'),'Splash7',population_gene_pair(b,'Splash7'),'Splash8',population_gene_pair(b,'Splash8'),'Leopard',population_gene_pair(b,'Leopard'),'PATN1',population_gene_pair(b,'PATN1'),'Mushroom',population_gene_pair(b,'Mushroom'),'W5',population_gene_pair(b,'W5'),'W10',population_gene_pair(b,'W10'),'W13',population_gene_pair(b,'W13'),'W20',population_gene_pair(b,'W20'),'W22',population_gene_pair(b,'W22'),'GBED',population_gene_pair(b,'GBED'),'HERDA',population_gene_pair(b,'HERDA'),'HYPP',population_gene_pair(b,'HYPP'),'PSSM1',population_gene_pair(b,'PSSM1'),'SCID',population_gene_pair(b,'SCID'),'LFS',population_gene_pair(b,'LFS'),'CA',population_gene_pair(b,'CA'),'OAAM',population_gene_pair(b,'OAAM'))$$;

create or replace function public.genetic_color(g jsonb) returns text language plpgsql immutable as $$declare c text;begin
 if gene_count(g,'Extension','E')=0 then c:='Chestnut';elsif gene_count(g,'Agouti','A')>0 then c:='Bay';else c:='Black';end if;
 if gene_count(g,'Cream','Cr')=1 then c:=case c when 'Chestnut' then 'Palomino' when 'Bay' then 'Buckskin' else 'Smoky Black' end;elsif gene_count(g,'Cream','Cr')=2 then c:=case c when 'Chestnut' then 'Cremello' when 'Bay' then 'Perlino' else 'Smoky Cream' end;end if;
 if gene_count(g,'Pearl','Prl')=2 or(gene_count(g,'Pearl','Prl')=1 and gene_count(g,'Cream','Cr')=1)then c:=c||' Pearl';end if;
 if gene_count(g,'Dun','D')>0 then c:=case c when 'Chestnut' then 'Red Dun' when 'Bay' then 'Bay Dun' when 'Black' then 'Grullo' else c||' Dun' end;end if;
 if gene_count(g,'Champagne','Ch')>0 then c:=c||' Champagne';end if;if gene_count(g,'Silver','Z')>0 then c:=c||' Silver';end if;if gene_count(g,'Gray','G')>0 then c:='Gray ('||c||' base)';end if;if gene_count(g,'Roan','Rn')>0 then c:=c||' Roan';end if;
 if gene_count(g,'Tobiano','TO')>0 then c:=c||' Tobiano';end if;if gene_count(g,'Frame','O')=1 then c:=c||' Frame Overo';end if;if gene_count(g,'Sabino1','SB1')>0 then c:=c||' Sabino';end if;if gene_count(g,'Splash1','SW1')>0 then c:=c||' Splash';end if;if gene_count(g,'Mushroom','Mu')=2 then c:='Mushroom '||c;end if;
 if gene_count(g,'Leopard','LP')>0 then c:=c||case when gene_count(g,'PATN1','PATN1')>0 then ' Leopard Appaloosa' else ' Appaloosa Pattern' end;end if;if gene_count(g,'W5','W5')=1 or gene_count(g,'W10','W10')=1 or gene_count(g,'W13','W13')=1 or gene_count(g,'W20','W20')>0 or gene_count(g,'W22','W22')=1 then c:=c||' Dominant White';end if;return trim(c);end$$;

create or replace function public.generate_store_horse(p_rotation timestamptz,p_preferred_breed text default null) returns uuid language plpgsql security definer set search_path=public as $$
declare h_id uuid;breed_name text;g jsonb;m jsonb;visual jsonb;horse_sex_value horse_sex;attempt integer:=0;begin
 select coalesce(p_preferred_breed,(select name from foundation_breeds where active order by random() limit 1)) into breed_name;
 loop attempt:=attempt+1;g:=random_foundation_genetics(breed_name);exit when not is_lethal_genotype(g);if attempt>=100 then raise exception 'Unable to generate a viable Foundation genotype';end if;end loop;
 m:=random_horse_markings(g,breed_name);horse_sex_value:=(case when random()<.5 then 'Mare' else 'Stallion' end)::horse_sex;visual:=build_visual_phenotype(breed_name,horse_sex_value,2,g,m);
 insert into horses(owner_id,name,breed,sex,color,origin,birth_date,stats,image_url,genetics,breed_composition,markings,visual_phenotype,image_generation_status,image_prompt_version)
 values(null,'Unnamed Foundation Horse',breed_name,horse_sex_value,genetic_color(g),'Foundation',now()-(interval '1 day'*(2*365.25/30)),random_foundation_stats(),'/foundation-horse.png',g,jsonb_build_object(breed_name,1),m,visual,'complete','breed-population-v1') returning id into h_id;
 perform assign_horse_visual(h_id);return h_id;
end$$;

create or replace function public.admin_list_foundation_genetics(p_breed text) returns setof public.breed_foundation_genetic_population language plpgsql stable security definer set search_path=public as $$begin perform require_admin();return query select * from breed_foundation_genetic_population where breed=p_breed order by category,locus;end$$;
create or replace function public.admin_update_foundation_genetic_weight(p_breed text,p_locus text,p_frequency numeric,p_generated boolean,p_rarity text,p_notes text default '') returns void language plpgsql security definer set search_path=public as $$
declare old_row breed_foundation_genetic_population;begin perform require_admin();if p_frequency<0 or p_frequency>1 then raise exception 'Frequency must be between 0 and 1';end if;if p_rarity not in('common','uncommon','rare','exceptional','not_generated')then raise exception 'Choose a valid rarity';end if;select * into old_row from breed_foundation_genetic_population where breed=p_breed and locus=p_locus for update;if not found then raise exception 'Breed genetic configuration not found';end if;update breed_foundation_genetic_population set allele_frequency=case when p_generated then p_frequency else 0 end,foundation_generated=p_generated,rarity=case when p_generated then p_rarity else 'not_generated' end,notes=left(coalesce(p_notes,''),500),updated_at=now(),updated_by=auth.uid() where breed=p_breed and locus=p_locus;insert into breed_foundation_genetic_audit(breed,locus,old_frequency,new_frequency,old_generated,new_generated,old_rarity,new_rarity,changed_by,reason)values(p_breed,p_locus,old_row.allele_frequency,case when p_generated then p_frequency else 0 end,old_row.foundation_generated,p_generated,old_row.rarity,case when p_generated then p_rarity else 'not_generated' end,auth.uid(),left(coalesce(p_notes,''),500));end$$;

revoke all on function public.population_gene_pair(text,text),public.random_foundation_genetics(text),public.admin_list_foundation_genetics(text),public.admin_update_foundation_genetic_weight(text,text,numeric,boolean,text,text) from public;
grant execute on function public.admin_list_foundation_genetics(text),public.admin_update_foundation_genetic_weight(text,text,numeric,boolean,text,text) to authenticated;
