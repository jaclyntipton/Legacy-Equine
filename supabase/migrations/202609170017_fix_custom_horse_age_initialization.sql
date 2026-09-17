-- Use one authoritative conversion for every administrative age write:
-- one horse-year is exactly 28 real days.
create or replace function public.horse_birth_date_for_age(p_age_years numeric,p_anchor timestamptz default now())
returns timestamptz language plpgsql stable set search_path=public as $$
declare real_days numeric;
begin
 if p_age_years<0 or p_age_years>100 then raise exception 'Age must be between 0 and 100';end if;
 select real_days_per_horse_year into real_days from horse_game_config where id=true;
 if real_days is null then raise exception 'Horse aging configuration is unavailable';end if;
 return p_anchor-make_interval(secs=>(p_age_years*real_days*86400)::double precision);
end$$;

create or replace function public.admin_create_visual_horse(target_owner uuid,horse_name text,horse_species text,horse_breed text,horse_sex text,horse_age_years numeric,desired_color text,desired_pattern text,desired_markings jsonb,horse_stats jsonb,advanced_genetics jsonb default '{}',horse_image_url text default '')
returns public.horses language plpgsql security definer set search_path=public as $$
declare result horses;stat record;g jsonb;visual jsonb;m jsonb;sex_value horse_sex;actor_no bigint;anchor timestamptz:=clock_timestamp();begin
 perform require_admin();if not exists(select 1 from stables where id=target_owner)then raise exception 'Owner stable not found';end if;
 if length(trim(horse_name))not between 1 and 80 or length(trim(horse_breed))not between 1 and 80 or length(trim(horse_species))not between 1 and 80 then raise exception 'Name, species, and breed are required';end if;if horse_sex not in('Mare','Stallion')then raise exception 'Sex must be Mare or Stallion';end if;if horse_age_years<0 or horse_age_years>100 then raise exception 'Age must be between 0 and 100';end if;
 for stat in select key from stat_definitions where active loop if jsonb_typeof(horse_stats->stat.key)<>'number'or(horse_stats->>stat.key)::numeric<0 or(horse_stats->>stat.key)::numeric>1000000 then raise exception 'Every stat must be a number between 0 and 1,000,000';end if;end loop;
 g:=case when coalesce(advanced_genetics,'{}')<>'{}'then advanced_genetics else genetics_for_visual(desired_color,desired_pattern)end;m:=coalesce(desired_markings,'{}');sex_value:=horse_sex::horse_sex;visual:=build_visual_phenotype(trim(horse_breed),sex_value,horse_age_years,g,m);
 insert into horses(owner_id,name,species,breed,sex,color,origin,birth_date,stats,genetics,breed_composition,image_url,custom_traits,is_admin_custom,markings,visual_phenotype,image_generation_status,image_prompt_version,created_at)
 values(target_owner,trim(horse_name),trim(horse_species),trim(horse_breed),sex_value,genetic_color(g),'Admin Custom',horse_birth_date_for_age(horse_age_years,anchor),horse_stats,g,jsonb_build_object(trim(horse_breed),1),coalesce(nullif(horse_image_url,''),'/foundation-horse.png'),'[]',true,m,visual,case when coalesce(horse_image_url,'')=''then'pending'else'complete'end,'store-horse-v1',anchor)returning * into result;
 if coalesce(horse_image_url,'')=''then insert into store_horse_image_jobs(horse_id)values(result.id);end if;
 select account_number into actor_no from stables where id=auth.uid();
 insert into horse_edit_audit(horse_id,horse_name,actor_id,actor_account,action,changed_fields,old_values,new_values,reason)values(result.id,result.name,auth.uid(),actor_no,'custom_horse_created',array['birth_date','age'],'{}',jsonb_build_object('entered_age_years',horse_age_years,'birth_date',result.birth_date),'Owner/Admin custom horse creation');
 return result;
end$$;

create or replace function public.get_horse_editor_data(p_horse_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare result jsonb;begin perform require_horse_editor();
 select jsonb_build_object(
  'horse',to_jsonb(h),'calculated_age',horse_game_age(h.birth_date),
  'owner',case when s.id is null then null else jsonb_build_object('id',s.id,'name',s.name,'account_number',s.account_number)end,
  'stables',(select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'name',x.name,'account_number',x.account_number)order by x.account_number),'[]')from stables x where x.account_number is not null),
  'templates',(select coalesce(jsonb_agg(jsonb_build_object('asset_key',a.asset_key,'breed',a.breed,'sex',a.sex,'image_url',a.image_url)order by a.asset_key),'[]')from horse_visual_assets a where a.asset_type='body_template'and a.status='approved'and a.active),
  'traits',(select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'key',t.trait_key,'name',t.display_name,'description',t.description,'color',t.badge_color,'active',t.active,'assigned',ta.horse_id is not null)order by t.display_name),'[]')from horse_trait_definitions t left join horse_trait_assignments ta on ta.trait_id=t.id and ta.horse_id=h.id),
  'audit',(select coalesce(jsonb_agg(z order by z.created_at desc),'[]')from(select id,action,changed_fields,reason,actor_account,created_at from horse_edit_audit where horse_id=h.id order by created_at desc limit 50)z)
 )into result from horses h left join stables s on s.id=h.owner_id where h.id=p_horse_id;
 if result is null then raise exception 'Horse not found';end if;return result;
end$$;

create or replace function public.owner_set_horse_age(p_horse uuid,p_age_years numeric,p_reason text default 'Owner age correction')returns timestamptz language plpgsql security definer set search_path=public as $$
declare dob timestamptz;before_age numeric;horse_name text;actor_no bigint;begin perform require_super_admin();select horse_game_age(birth_date),name into before_age,horse_name from horses where id=p_horse for update;if not found then raise exception 'Horse not found';end if;select account_number into actor_no from stables where id=auth.uid();dob:=horse_birth_date_for_age(p_age_years,clock_timestamp());perform set_config('app.horse_editor','on',true);update horses set birth_date=dob where id=p_horse;insert into horse_edit_audit(horse_id,horse_name,actor_id,actor_account,action,changed_fields,old_values,new_values,reason)values(p_horse,horse_name,auth.uid(),actor_no,'age_change',array['birth_date','age'],jsonb_build_object('age',before_age),jsonb_build_object('age',p_age_years,'birth_date',dob),left(p_reason,500));return dob;end$$;

-- Route any direct age_years edit through the same audited authoritative RPC.
alter function public.owner_edit_horse(uuid,jsonb,text,boolean)rename to owner_edit_horse_internal;
revoke all on function public.owner_edit_horse_internal(uuid,jsonb,text,boolean)from public,authenticated;
create function public.owner_edit_horse(p_horse_id uuid,p_changes jsonb,p_reason text default '',p_confirm_high_impact boolean default false)
returns public.horses language plpgsql security definer set search_path=public as $$
declare remaining jsonb:=coalesce(p_changes,'{}')-'age_years';result horses;begin
 perform require_horse_editor();
 if p_changes?'age_years'then perform owner_set_horse_age(p_horse_id,(p_changes->>'age_years')::numeric,coalesce(nullif(p_reason,''),'Owner horse editor age correction'));end if;
 if remaining<>'{}'::jsonb then select * into result from owner_edit_horse_internal(p_horse_id,remaining,p_reason,p_confirm_high_impact);else select * into result from horses where id=p_horse_id;end if;
 return result;
end$$;

-- The two existing Owner Unicorns carry exact deterministic evidence of an
-- entered Age 3: created_at - birth_date = 3 * (365.25/30) days.
do $$
declare h horses;v_owner uuid;old_age numeric;new_dob timestamptz;entered_age numeric;corrected integer:=0;
begin
 select s.id into v_owner from stables s where s.account_number=1;
 for h in select x.* from horses x where x.owner_id=v_owner and x.origin='Admin Custom'and x.is_admin_custom and lower(x.breed)='unicorn'
 loop
  entered_age:=extract(epoch from(h.created_at-h.birth_date))/86400/(365.25/30);
  if abs(entered_age-3)<0.000001 then
   old_age:=horse_game_age(h.birth_date,h.created_at);new_dob:=horse_birth_date_for_age(3,h.created_at);
   perform set_config('app.horse_editor','on',true);update horses set birth_date=new_dob where id=h.id;
   insert into horse_edit_audit(horse_id,horse_name,actor_id,actor_account,action,changed_fields,old_values,new_values,reason)values(h.id,h.name,v_owner,1,'custom_creation_age_repair',array['birth_date','age'],jsonb_build_object('birth_date',h.birth_date,'age_at_creation',old_age,'proven_entered_age',3),jsonb_build_object('birth_date',new_dob,'age_at_creation',3),'Correct obsolete custom-creation age conversion; preserve elapsed LE aging from original creation');
   corrected:=corrected+1;
  end if;
 end loop;
 if corrected<>2 then raise exception 'Expected two provenance-proven Owner Unicorn age repairs, found %',corrected;end if;
 raise notice 'Corrected % provenance-proven Owner Unicorn ages',corrected;
end$$;

revoke all on function public.horse_birth_date_for_age(numeric,timestamptz),public.admin_create_visual_horse(uuid,text,text,text,text,numeric,text,text,jsonb,jsonb,jsonb,text),public.get_horse_editor_data(uuid),public.owner_set_horse_age(uuid,numeric,text),public.owner_edit_horse(uuid,jsonb,text,boolean)from public;
grant execute on function public.admin_create_visual_horse(uuid,text,text,text,text,numeric,text,text,jsonb,jsonb,jsonb,text),public.get_horse_editor_data(uuid),public.owner_set_horse_age(uuid,numeric,text),public.owner_edit_horse(uuid,jsonb,text,boolean)to authenticated;
