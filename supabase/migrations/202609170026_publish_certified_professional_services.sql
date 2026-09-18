-- One authoritative public projection: earned certificate + enabled valid rate.
-- Owner QA fallback rows are intentionally excluded from all normal surfaces.
create or replace function public.get_public_professional_services(p_stable uuid)
returns jsonb language sql security definer set search_path=public stable as $$
 select coalesce(jsonb_agg(jsonb_build_object(
  'provider_id',p_stable,'service_id',sc.id,'profession_id',sc.profession_id,
  'name',sc.name,'price',o.price,'profession',pr.name,
  'certification',cl.name||' Certified','certification_level',earned.level
 )order by pr.sort_order,sc.minimum_level,sc.name),'[]'::jsonb)
 from player_service_offerings o
 join service_catalog sc on sc.id=o.service_id and sc.active
 join professions pr on pr.id=sc.profession_id and pr.active
 join lateral(
  select max(c.level)::integer level from player_profession_certifications c
  where c.stable_id=p_stable and c.profession_id=sc.profession_id
 )earned on earned.level is not null and earned.level>=sc.minimum_level
 join certification_levels cl on cl.level=earned.level
 where o.stable_id=p_stable and o.enabled and o.price between sc.min_price and sc.max_price
$$;

drop function public.get_service_directory(text);
create function public.get_service_directory(target_profession text default null)
returns table(provider_id uuid,stable_name text,account_number bigint,profession_id text,profession_name text,certification text,certification_level integer,completed_services integer,service_id text,service_name text,price integer,owner_qa boolean)
language sql security definer set search_path=public stable as $$
 select s.id,s.name,s.account_number,p.id,p.name,cl.name||' Certified',earned.level,
  coalesce(completed.total,0),sc.id,sc.name,o.price,false
 from player_service_offerings o
 join stables s on s.id=o.stable_id and s.account_status='active'
 join service_catalog sc on sc.id=o.service_id and sc.active
 join professions p on p.id=sc.profession_id and p.active
 join lateral(
  select max(c.level)::integer level from player_profession_certifications c
  where c.stable_id=o.stable_id and c.profession_id=sc.profession_id
 )earned on earned.level is not null and earned.level>=sc.minimum_level
 join certification_levels cl on cl.level=earned.level
 left join lateral(
  select count(*)::integer total from horse_service_records r
  where r.provider_id=o.stable_id and r.profession_id=sc.profession_id
   and r.status='completed'and not r.self_service and r.price>0
 )completed on true
 where o.enabled and o.price between sc.min_price and sc.max_price
  and(target_profession is null or p.id=target_profession)
 order by earned.level desc,completed.total desc,o.price,s.name,sc.name
$$;

create or replace function public.get_public_player_profile(p_stable uuid)returns jsonb
language plpgsql stable security definer set search_path=public as $$declare s stables;b stable_brands;begin
 select * into s from stables where id=p_stable and account_status='active';if not found then raise exception 'Player profile not found';end if;
 select * into b from stable_brands where stable_id=s.id and(active or reserved);
 return jsonb_build_object(
  'id',s.id,'username',s.username,'account_number',s.account_number,'avatar_url',s.avatar_url,'bio',s.bio,
  'established_at',s.created_at,'account_level',account_level_for_xp(s.account_xp),'stable_name',s.name,
  'brand',case when b.id is null then null else jsonb_build_object('code',b.code,'mark_url',b.mark_url)end,
  'horse_count',(select count(*)from horses h where h.owner_id=s.id and not h.retired),'owner',auth.uid()=s.id,
  'services',public.get_public_professional_services(s.id)
 );
end$$;

create or replace function public.get_public_stable_profile(p_stable uuid) returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare s stables;p stable_public_profiles;b stable_brands;result jsonb;begin
 select * into s from stables where id=p_stable and account_status='active';if not found then raise exception 'Stable not found';end if;
 select * into p from stable_public_profiles where stable_id=p_stable;
 select * into b from stable_brands where stable_id=p_stable and(active or reserved);
 result:=jsonb_build_object(
  'id',s.id,'name',s.name,'username',s.username,'account_number',s.account_number,'ranch_image_url',s.ranch_image_url,'created_at',s.created_at,
  'brand',case when b.id is null then null else jsonb_build_object('code',b.code,'mark_url',b.mark_url,'active',b.active)end,
  'stable_news',coalesce(p.stable_news,''),'about',coalesce(nullif(p.about_text,''),s.bio,''),
  'blocks',coalesce(p.blocks,'[{"id":"banner","type":"banner","visible":true},{"id":"news","type":"news","visible":true},{"id":"about","type":"about","visible":true},{"id":"featured","type":"featured","visible":true},{"id":"stallions","type":"stallions","visible":true},{"id":"broodmares","type":"broodmares","visible":true},{"id":"winners","type":"winners","visible":true},{"id":"services","type":"services","visible":true},{"id":"custom","type":"custom","visible":true,"content":""}]'::jsonb),
  'featured_horses',coalesce(p.featured_horses,'{}'::uuid[]),'owner',auth.uid()=p_stable,'can_customize',public.has_custom_stable_layout(p_stable),
  'horses',coalesce((select jsonb_agg(jsonb_build_object('id',h.id,'name',h.name,'breed',h.breed,'sex',h.sex,'color',h.color,'image_url',h.image_url,'career_points',h.career_points)order by h.name)from horses h where h.owner_id=p_stable and not h.retired),'[]'::jsonb),
  'services',public.get_public_professional_services(p_stable)
 );return result;
end$$;

revoke all on function public.get_public_professional_services(uuid),public.get_service_directory(text) from public;
grant execute on function public.get_public_professional_services(uuid),public.get_service_directory(text),public.get_public_player_profile(uuid),public.get_public_stable_profile(uuid) to authenticated;
