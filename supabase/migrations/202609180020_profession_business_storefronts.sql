-- Profession businesses are presentation around earned certifications and authoritative offerings.
create table public.profession_business_profiles(
 stable_id uuid not null references public.stables(id) on delete cascade,
 profession_id text not null references public.professions(id) on delete cascade,
 display_name text not null,
 banner_url text,
 about_text text not null default '',
 announcement text not null default '',
 featured_service_id text references public.service_catalog(id) on delete set null,
 updated_at timestamptz not null default now(),
 primary key(stable_id,profession_id)
);
alter table public.profession_business_profiles enable row level security;
create policy "business owners read profiles" on public.profession_business_profiles for select using(stable_id=auth.uid());

create or replace function public.profession_business_type(p_profession text)returns text
language sql immutable strict as $$select case p_profession
 when'farrier'then'Blacksmith Shop' when'veterinarian'then'Veterinary Clinic'
 when'trainer'then'Training Facility' when'massage'then'Equine Therapy Room'
 when'leatherworker'then'Tack Shop' else'Professional Business'end$$;

create or replace function public.business_safe_text(value text,max_length integer)returns text
language sql immutable as $$select left(regexp_replace(coalesce(value,''),'<[^>]*>','','g'),max_length)$$;

create or replace function public.get_my_profession_businesses()returns jsonb
language sql stable security definer set search_path=public as $$
 with earned as(
  select c.profession_id,max(c.level)::integer level from player_profession_certifications c
  where c.stable_id=auth.uid() group by c.profession_id
 ), base as(
  select s.id provider_id,p.id profession_id,p.name profession_name,e.level,cl.name certification,
   profession_business_type(p.id) business_type,s.name stable_name,s.account_number,
   coalesce(bp.display_name,s.name||' '||profession_business_type(p.id)) display_name,
   bp.banner_url,coalesce(bp.about_text,'')about_text,coalesce(bp.announcement,'')announcement,bp.featured_service_id,
   coalesce((select count(*)from player_service_offerings o join service_catalog sc on sc.id=o.service_id
    where o.stable_id=s.id and sc.profession_id=p.id and sc.minimum_level<=e.level and sc.active and o.enabled and o.price between sc.min_price and sc.max_price),0)::integer active_count
  from earned e join professions p on p.id=e.profession_id and p.active join certification_levels cl on cl.level=e.level
  join stables s on s.id=auth.uid() left join profession_business_profiles bp on bp.stable_id=s.id and bp.profession_id=p.id
 )select coalesce(jsonb_agg(to_jsonb(base)order by profession_name),'[]'::jsonb)from base
$$;

create or replace function public.get_profession_business_workspace(p_profession text)returns jsonb
language plpgsql stable security definer set search_path=public as $$declare lvl integer;profile jsonb;begin
 select max(level)into lvl from player_profession_certifications where stable_id=auth.uid()and profession_id=p_profession;
 if lvl is null then raise exception 'Earn the Basic certification to unlock this business';end if;
 select b into profile from jsonb_array_elements(get_my_profession_businesses())b where b->>'profession_id'=p_profession;
 return profile||jsonb_build_object(
  'services',coalesce((select jsonb_agg(jsonb_build_object('id',sc.id,'name',sc.name,'minimum_level',sc.minimum_level,'min_price',sc.min_price,'max_price',sc.max_price,'price',o.price,'enabled',coalesce(o.enabled,false),'tack_slot',sc.tack_slot,'tack_tier',sc.tack_tier)order by sc.minimum_level,sc.name)
   from service_catalog sc left join player_service_offerings o on o.stable_id=auth.uid()and o.service_id=sc.id
   where sc.profession_id=p_profession and sc.active and sc.minimum_level<=lvl),'[]'::jsonb),
  'history',coalesce((select jsonb_agg(jsonb_build_object('completed_at',r.completed_at,'service',sc.name,'horse',h.name,'customer',client.name,'price',r.price)order by r.completed_at desc)
   from(select * from horse_service_records where provider_id=auth.uid()and profession_id=p_profession and status='completed'order by completed_at desc limit 100)r
   join service_catalog sc on sc.id=r.service_id join horses h on h.id=r.horse_id join stables client on client.id=r.client_id),'[]'::jsonb)
 );end$$;

create or replace function public.save_profession_business_profile(p_profession text,p_display_name text,p_banner_url text,p_about text,p_announcement text,p_featured_service text default null)returns void
language plpgsql security definer set search_path=public as $$declare lvl integer;clean_name text;begin
 select max(level)into lvl from player_profession_certifications where stable_id=auth.uid()and profession_id=p_profession;
 if lvl is null then raise exception 'Earn the Basic certification to unlock this business';end if;
 clean_name:=business_safe_text(p_display_name,80);if length(trim(clean_name))<2 then raise exception 'Business name is required';end if;
 if p_banner_url is not null and p_banner_url<>''and p_banner_url!~'^https://[^[:space:]]+$'then raise exception 'Invalid business banner URL';end if;
 if p_featured_service is not null and not exists(select 1 from service_catalog where id=p_featured_service and profession_id=p_profession and active and minimum_level<=lvl)then raise exception 'Featured service is not authorized';end if;
 insert into profession_business_profiles(stable_id,profession_id,display_name,banner_url,about_text,announcement,featured_service_id)
 values(auth.uid(),p_profession,clean_name,nullif(p_banner_url,''),business_safe_text(p_about,2000),business_safe_text(p_announcement,1000),p_featured_service)
 on conflict(stable_id,profession_id)do update set display_name=excluded.display_name,banner_url=excluded.banner_url,about_text=excluded.about_text,announcement=excluded.announcement,featured_service_id=excluded.featured_service_id,updated_at=now();
end$$;

create or replace function public.get_public_profession_business(p_stable uuid,p_profession text)returns jsonb
language plpgsql stable security definer set search_path=public as $$declare lvl integer;s stables;b stable_brands;bp profession_business_profiles;begin
 select * into s from stables where id=p_stable and account_status='active';if not found then raise exception 'Business not found';end if;
 select max(level)into lvl from player_profession_certifications where stable_id=p_stable and profession_id=p_profession;if lvl is null then raise exception 'Business not found';end if;
 select * into bp from profession_business_profiles where stable_id=p_stable and profession_id=p_profession;
 select * into b from stable_brands where stable_id=p_stable and active;
 return jsonb_build_object('provider_id',s.id,'profession_id',p_profession,'profession',(select name from professions where id=p_profession),'business_type',profession_business_type(p_profession),
  'display_name',coalesce(bp.display_name,s.name||' '||profession_business_type(p_profession)),'banner_url',bp.banner_url,'about_text',coalesce(bp.about_text,''),'announcement',coalesce(bp.announcement,''),'featured_service_id',bp.featured_service_id,
  'stable_name',s.name,'username',s.username,'account_number',s.account_number,'certification',(select name from certification_levels where level=lvl)||' Certified','certification_level',lvl,
  'brand',case when b.id is null then null else jsonb_build_object('code',b.code,'mark_url',b.mark_url)end,
  'completed_services',(select count(*)from horse_service_records where provider_id=p_stable and profession_id=p_profession and status='completed'and not self_service and price>0),
  'services',coalesce((select jsonb_agg(jsonb_build_object('id',sc.id,'name',sc.name,'price',o.price,'minimum_level',sc.minimum_level,'tack_slot',sc.tack_slot,'tack_tier',sc.tack_tier)order by(sc.id=bp.featured_service_id)desc,sc.minimum_level,sc.name)
   from player_service_offerings o join service_catalog sc on sc.id=o.service_id and sc.active
   where o.stable_id=p_stable and o.enabled and o.price between sc.min_price and sc.max_price and sc.profession_id=p_profession and sc.minimum_level<=lvl),'[]'::jsonb)
 );end$$;

revoke all on function public.get_my_profession_businesses(),public.get_profession_business_workspace(text),public.save_profession_business_profile(text,text,text,text,text,text),public.get_public_profession_business(uuid,text)from public;
grant execute on function public.get_my_profession_businesses(),public.get_profession_business_workspace(text),public.save_profession_business_profile(text,text,text,text,text,text),public.get_public_profession_business(uuid,text)to authenticated;
