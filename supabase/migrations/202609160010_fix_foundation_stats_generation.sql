-- Generate the immutable birth stats once and insert the same non-null values
-- into both birth_stats and developed stats.
create or replace function public.generate_store_horse(p_rotation timestamptz,p_preferred_breed text default null) returns uuid language plpgsql security definer set search_path=public as $$
declare h_id uuid;breed_name text;g jsonb;m jsonb;visual jsonb;generated_stats jsonb;horse_sex_value horse_sex;attempt integer:=0;begin
 select coalesce(p_preferred_breed,(select name from foundation_breeds where active order by random() limit 1)) into breed_name;
 loop attempt:=attempt+1;g:=random_foundation_genetics(breed_name);exit when not is_lethal_genotype(g);if attempt>=100 then raise exception 'Unable to generate a viable Foundation genotype';end if;end loop;
 m:=random_horse_markings(g,breed_name);horse_sex_value:=(case when random()<.5 then 'Mare' else 'Stallion' end)::horse_sex;visual:=build_visual_phenotype(breed_name,horse_sex_value,2,g,m);generated_stats:=random_foundation_stats();
 insert into horses(owner_id,name,breed,sex,color,origin,birth_date,birth_stats,stats,image_url,genetics,breed_composition,markings,visual_phenotype,image_generation_status,image_prompt_version)
 values(null,'Unnamed Foundation Horse',breed_name,horse_sex_value,genetic_color(g),'Foundation',now()-interval '56 days',generated_stats,generated_stats,'/foundation-horse.png',g,jsonb_build_object(breed_name,1),m,visual,'complete','breed-population-v1') returning id into h_id;
 perform assign_horse_visual(h_id);return h_id;
end$$;
