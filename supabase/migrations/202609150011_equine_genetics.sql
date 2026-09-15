alter table public.horses add column genetics jsonb not null default '{}';
alter table public.horses add column breed_composition jsonb not null default '{}';

create table public.breed_cross_rules(parent_a text not null,parent_b text not null,result_breed text not null,minimum_a numeric,maximum_a numeric,source_note text,primary key(parent_a,parent_b));
insert into public.breed_cross_rules values
('Arabian','Thoroughbred','Anglo-Arabian',0.25,0.75,'AHA 25–75% Arabian rule'),
('Quarter Horse','Thoroughbred','Appendix Quarter Horse',null,null,'AQHA Appendix cross'),
('Arabian','Quarter Horse','Quarab',0.125,0.875,'Quarab registry founding breeds'),
('Arabian','Morgan','Morab',null,null,'Morgan-Arabian cross'),
('Appaloosa','Arabian','AraAppaloosa',null,null,'Arabian-Appaloosa cross');

create or replace function public.gene_pair(mutant text,frequency numeric)
returns jsonb language sql volatile as $$ select jsonb_build_array(case when random()<frequency then mutant else 'N' end,case when random()<frequency then mutant else 'N' end) $$;
create or replace function public.random_foundation_genetics(b text)
returns jsonb language sql volatile as $$ select jsonb_build_object(
 'Extension',gene_pair('E',0.72),'Agouti',gene_pair('A',0.60),'Cream',gene_pair('Cr',case when b in('Quarter Horse','Morgan','Tennessee Walking Horse') then .08 else .01 end),
 'Dun',gene_pair('D',case when b='Quarter Horse' then .08 else .01 end),'Champagne',gene_pair('Ch',case when b in('Tennessee Walking Horse','Rocky Mountain Horse') then .035 else .004 end),
 'Silver',gene_pair('Z',case when b in('Rocky Mountain Horse','Morgan','Tennessee Walking Horse') then .07 else .005 end),'Pearl',gene_pair('Prl',case when b in('Quarter Horse','Andalusian') then .025 else .003 end),
 'Gray',gene_pair('G',case when b in('Arabian','Thoroughbred','Hanoverian') then .14 else .03 end),'Roan',gene_pair('Rn',case when b in('Quarter Horse','Morgan','Tennessee Walking Horse') then .08 else .015 end),
 'Tobiano',gene_pair('TO',.02),'Frame',gene_pair('O',case when b in('Quarter Horse','Appaloosa') then .025 else .002 end),'Sabino1',gene_pair('SB1',.025),'Splash1',gene_pair('SW1',.025),
 'Splash2',gene_pair('SW2',.004),'Splash3',gene_pair('SW3',.002),'Splash5',gene_pair('SW5',.002),'Splash6',gene_pair('SW6',.002),'Splash7',gene_pair('SW7',.002),'Splash8',gene_pair('SW8',.002),
 'Leopard',gene_pair('LP',case when b='Appaloosa' then .55 else .002 end),'PATN1',gene_pair('PATN1',case when b='Appaloosa' then .30 else .003 end),
 'Mushroom',gene_pair('Mu',case when b='Shetland Pony' then .04 else .001 end),'W5',gene_pair('W5',case when b='Thoroughbred' then .003 else 0 end),'W10',gene_pair('W10',case when b in('Quarter Horse','Appaloosa') then .003 else 0 end),'W13',gene_pair('W13',.001),'W20',gene_pair('W20',.006),'W22',gene_pair('W22',.001),
 'GBED',gene_pair('G',case when b in('Quarter Horse','Appaloosa') then .02 else 0 end),'HERDA',gene_pair('H',case when b in('Quarter Horse','Appaloosa') then .02 else 0 end),
 'HYPP',gene_pair('H',case when b='Quarter Horse' then .01 else 0 end),'PSSM1',gene_pair('P1',case when b in('Quarter Horse','Appaloosa') then .025 else .003 end),
 'SCID',gene_pair('S',case when b in('Arabian','Anglo-Arabian','Quarab','Morab') then .025 else 0 end),'LFS',gene_pair('L',case when b in('Arabian','Anglo-Arabian','Quarab','Morab') then .02 else 0 end),
 'CA',gene_pair('C',case when b in('Arabian','Anglo-Arabian','Quarab','Morab') then .02 else 0 end),'OAAM',gene_pair('O',case when b in('Arabian','Anglo-Arabian','Quarab','Morab') then .01 else 0 end)) $$;

create or replace function public.gene_count(g jsonb,locus text,allele text)
returns integer language sql immutable as $$ select count(*)::int from jsonb_array_elements_text(coalesce(g->locus,'["N","N"]'::jsonb)) x where x=allele $$;
create or replace function public.inherit_genetics(a jsonb,b jsonb)
returns jsonb language plpgsql volatile as $$ declare result jsonb='{}'; k text; av jsonb; bv jsonb; begin for k in select jsonb_object_keys(a||b) loop av:=coalesce(a->k,'["N","N"]');bv:=coalesce(b->k,'["N","N"]');result:=result||jsonb_build_object(k,jsonb_build_array(av -> (floor(random()*2)::int),bv -> (floor(random()*2)::int)));end loop;return result;end $$;

create or replace function public.genetic_color(g jsonb)
returns text language plpgsql immutable as $$ declare c text; begin
 if gene_count(g,'Extension','E')=0 then c:='Chestnut'; elsif gene_count(g,'Agouti','A')>0 then c:='Bay'; else c:='Black'; end if;
 if gene_count(g,'Cream','Cr')=1 then c:=case c when 'Chestnut' then 'Palomino' when 'Bay' then 'Buckskin' else 'Smoky Black' end; elsif gene_count(g,'Cream','Cr')=2 then c:=case c when 'Chestnut' then 'Cremello' when 'Bay' then 'Perlino' else 'Smoky Cream' end; end if;
 if gene_count(g,'Pearl','Prl')=2 or (gene_count(g,'Pearl','Prl')=1 and gene_count(g,'Cream','Cr')=1) then c:=c||' Pearl'; end if;
 if gene_count(g,'Dun','D')>0 then c:=c||' Dun'; end if; if gene_count(g,'Champagne','Ch')>0 then c:=c||' Champagne'; end if; if gene_count(g,'Silver','Z')>0 then c:=c||' Silver'; end if;
 if gene_count(g,'Gray','G')>0 then c:='Gray ('||c||' base)'; end if; if gene_count(g,'Roan','Rn')>0 then c:=c||' Roan'; end if;
 if gene_count(g,'Tobiano','TO')>0 then c:=c||' Tobiano'; end if; if gene_count(g,'Frame','O')=1 then c:=c||' Frame Overo'; end if; if gene_count(g,'Sabino1','SB1')>0 then c:=c||' Sabino'; end if; if gene_count(g,'Splash1','SW1')>0 then c:=c||' Splash'; end if;
 if gene_count(g,'Mushroom','Mu')=2 then c:='Mushroom '||c; end if;
 if gene_count(g,'Leopard','LP')>0 then c:=c||case when gene_count(g,'PATN1','PATN1')>0 then ' Leopard Appaloosa' else ' Appaloosa Pattern' end; end if; if gene_count(g,'W5','W5')=1 or gene_count(g,'W10','W10')=1 or gene_count(g,'W13','W13')=1 or gene_count(g,'W20','W20')>0 or gene_count(g,'W22','W22')=1 then c:=c||' Dominant White'; end if; return trim(c); end $$;

create or replace function public.is_lethal_genotype(g jsonb)
returns boolean language sql immutable as $$ select gene_count(g,'Frame','O')=2 or gene_count(g,'W5','W5')=2 or gene_count(g,'W10','W10')=2 or gene_count(g,'W13','W13')=2 or gene_count(g,'W22','W22')=2 or gene_count(g,'GBED','G')=2 or gene_count(g,'SCID','S')=2 or gene_count(g,'LFS','L')=2 or gene_count(g,'OAAM','O')=2 $$;

create or replace function public.combine_breed_composition(a jsonb,b jsonb)
returns jsonb language sql immutable as $$
 select coalesce(jsonb_object_agg(breed,share),'{}'::jsonb) from (
  select breed,sum(part)::numeric as share from (
   select key breed,(value::text)::numeric/2 part from jsonb_each(coalesce(a,'{}'))
   union all select key,(value::text)::numeric/2 from jsonb_each(coalesce(b,'{}'))
  ) portions group by breed
 ) combined
$$;

create or replace function public.resolve_crossbreed(a text,b text)
returns text language sql stable as $$ select coalesce((select result_breed from breed_cross_rules where (parent_a=a and parent_b=b) or (parent_a=b and parent_b=a) limit 1),case when a=b then a else a||' × '||b||' Cross' end) $$;

create or replace function public.get_breeding_genetic_preview(stallion_id uuid,mare_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$ declare s horses;d horses; risks jsonb='[]'; variants jsonb='{}'; rec record; ca int;cb int;p numeric;survival numeric:=1; begin
 select * into s from horses where id=stallion_id;select * into d from horses where id=mare_id;if s.owner_id<>auth.uid() or d.owner_id<>auth.uid() then raise exception 'Both horses must be owned by you';end if;
 for rec in select * from (values('Frame','O','Lethal White Overo'),('W5','W5','W5 embryonic lethal'),('W10','W10','W10 embryonic lethal'),('W13','W13','W13 embryonic lethal'),('W22','W22','W22 embryonic lethal'),('GBED','G','Glycogen Branching Enzyme Deficiency'),('SCID','S','Severe Combined Immunodeficiency'),('LFS','L','Lavender Foal Syndrome'),('OAAM','O','Occipitoatlantoaxial Malformation')) x(locus,allele,label) loop ca:=gene_count(s.genetics,rec.locus,rec.allele);cb:=gene_count(d.genetics,rec.locus,rec.allele);p:=(ca::numeric/2)*(cb::numeric/2);if p>0 then risks:=risks||jsonb_build_array(jsonb_build_object('condition',rec.label,'chance_percent',round(p*100,2)));survival:=survival*(1-p);end if;end loop;
 for rec in select * from (values('Cream','Cr',false),('Dun','D',false),('Champagne','Ch',false),('Silver','Z',false),('Gray','G',false),('Roan','Rn',false),('Tobiano','TO',false),('Frame','O',false),('Sabino1','SB1',false),('Splash1','SW1',false),('Splash2','SW2',false),('Splash3','SW3',false),('Splash5','SW5',false),('Splash6','SW6',false),('Splash7','SW7',false),('Splash8','SW8',false),('Leopard','LP',false),('Pearl','Prl',true),('Mushroom','Mu',true),('W20','W20',false)) x(locus,allele,recessive) loop ca:=gene_count(s.genetics,rec.locus,rec.allele);cb:=gene_count(d.genetics,rec.locus,rec.allele);p:=case when rec.recessive then (ca::numeric/2)*(cb::numeric/2) else 1-(1-ca::numeric/2)*(1-cb::numeric/2) end;if p>0 then variants:=variants||jsonb_build_object(rec.locus,round(p*100,2));end if;end loop;
 return jsonb_build_object('lethal_risks',risks,'total_lethal_percent',round((1-survival)*100,2),'survival_percent',round(survival*100,2),'variant_chances',variants,'result_breed',resolve_crossbreed(s.breed,d.breed));end $$;

update horses set genetics=random_foundation_genetics(breed),breed_composition=jsonb_build_object(breed,1) where genetics='{}';
update horses h set birth_date=now()-(interval '1 day'*(2*365.25/30)),color=genetic_color(h.genetics) from store_inventory si where si.horse_id=h.id and si.status='active';

create or replace function public.generate_store_horse(p_rotation timestamptz,p_preferred_breed text default null)
returns uuid language plpgsql security definer set search_path=public as $$ declare h_id uuid;breed_name text;g jsonb;begin select coalesce(p_preferred_breed,(select name from foundation_breeds where active order by random() limit 1)) into breed_name;g:=random_foundation_genetics(breed_name);insert into horses(owner_id,name,breed,sex,color,origin,birth_date,stats,image_url,genetics,breed_composition) values(null,'Unnamed Foundation Horse',breed_name,(case when random()<.5 then 'Mare' else 'Stallion' end)::horse_sex,genetic_color(g),'Foundation',now()-(interval '1 day'*(2*365.25/30)),random_foundation_stats(),'/foundation-horse.png',g,jsonb_build_object(breed_name,1)) returning id into h_id;return h_id;end $$;

create or replace function public.breed_horses(stallion_id uuid,mare_id uuid)
returns public.horses language plpgsql security definer set search_path=public as $$ declare sire horses;dam horses;foal horses;s stables;child_stats jsonb='{}';child_genetics jsonb;d record;baseline int;variance int;fee int;child_breed text;begin
 if stallion_id=mare_id then raise exception 'Choose two different horses';end if;select * into sire from horses where id=stallion_id for update;select * into dam from horses where id=mare_id for update;if sire.owner_id<>auth.uid() or dam.owner_id<>auth.uid() then raise exception 'Both horses must be owned by you';end if;if sire.sex<>'Stallion' or dam.sex<>'Mare' then raise exception 'Breeding requires a stallion and mare';end if;if dam.last_bred_at is not null and dam.last_bred_at>now()-interval '10 days' then raise exception 'Mare cooldown active';end if;
 child_genetics:=inherit_genetics(sire.genetics,dam.genetics);if is_lethal_genotype(child_genetics) then raise exception 'This breeding produced a non-viable lethal genotype. No foal was created and no fee was charged.';end if;fee:=sire.stud_fee;select * into s from stables where id=auth.uid() for update;if s.balance<fee then raise exception 'Insufficient funds';end if;
 for d in select key from stat_definitions where active order by sort_order loop baseline:=round(((sire.stats->>d.key)::numeric+(dam.stats->>d.key)::numeric)/2)::int;variance:=floor(random()*13)::int-6;if random()<.25 then variance:=variance-1;end if;child_stats:=child_stats||jsonb_build_object(d.key,greatest(1,baseline+variance));end loop;child_breed:=resolve_crossbreed(sire.breed,dam.breed);
 insert into horses(owner_id,name,breed,sex,color,origin,birth_date,sire_id,dam_id,generation,stats,genetics,breed_composition) values(auth.uid(),'Unnamed Foal',child_breed,(case when random()<.5 then 'Mare' else 'Stallion' end)::horse_sex,genetic_color(child_genetics),'Bred',now(),sire.id,dam.id,greatest(sire.generation,dam.generation)+1,child_stats,child_genetics,combine_breed_composition(sire.breed_composition,dam.breed_composition)) returning * into foal;update horses set last_bred_at=now() where id=dam.id;update stables set balance=balance-fee where id=auth.uid();if fee>0 then insert into currency_ledger(stable_id,amount,reason,horse_id) values(auth.uid(),-fee,'Stud fee',foal.id);end if;insert into breeding_records(owner_id,sire_id,dam_id,foal_id,stud_fee) values(auth.uid(),sire.id,dam.id,foal.id,fee);return foal;end $$;

revoke all on function public.gene_pair(text,numeric),public.random_foundation_genetics(text),public.inherit_genetics(jsonb,jsonb),public.combine_breed_composition(jsonb,jsonb),public.get_breeding_genetic_preview(uuid,uuid) from public;
grant execute on function public.get_breeding_genetic_preview(uuid,uuid) to authenticated;
