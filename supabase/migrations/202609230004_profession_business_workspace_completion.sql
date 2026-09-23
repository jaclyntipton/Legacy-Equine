-- Reconnect the shared business workspace directly to earned certification,
-- authoritative offerings, existing profile data, and existing histories.
create or replace function public.get_profession_business_workspace(p_profession text)returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare lvl integer;s stables;p professions;cl certification_levels;bp profession_business_profiles;result jsonb;
begin
 if auth.uid()is null then raise exception 'Access denied';end if;
 select * into p from professions where id=p_profession and active;
 if not found then raise exception 'Business not found';end if;
 select * into s from stables where id=auth.uid()and account_status='active';
 if not found then raise exception 'Access denied';end if;
 select max(level)into lvl from player_profession_certifications where stable_id=s.id and profession_id=p.id;
 if lvl is null then raise exception 'Access denied: certification required';end if;
 select * into cl from certification_levels where level=lvl;
 select * into bp from profession_business_profiles where stable_id=s.id and profession_id=p.id;
 result:=jsonb_build_object(
  'provider_id',s.id,'profession_id',p.id,'profession_name',p.name,'certification_level',lvl,'certification',cl.name,
  'business_type',profession_business_type(p.id),'stable_name',s.name,'account_number',s.account_number,
  'display_name',coalesce(bp.display_name,s.name||' '||profession_business_type(p.id)),'banner_url',bp.banner_url,
  'about_text',coalesce(bp.about_text,''),'announcement',coalesce(bp.announcement,''),'featured_service_id',bp.featured_service_id,
  'active_count',coalesce((select count(*)from player_service_offerings o join service_catalog sc on sc.id=o.service_id where o.stable_id=s.id and sc.profession_id=p.id and sc.minimum_level<=lvl and sc.active and o.enabled and o.price between sc.min_price and sc.max_price),0),
  'services',coalesce((select jsonb_agg(jsonb_build_object('id',sc.id,'name',sc.name,'minimum_level',sc.minimum_level,'min_price',sc.min_price,'max_price',sc.max_price,'price',o.price,'enabled',coalesce(o.enabled,false),'tack_slot',sc.tack_slot,'tack_tier',sc.tack_tier,'stat_budget',sc.stat_budget)order by sc.minimum_level,sc.name)from service_catalog sc left join player_service_offerings o on o.stable_id=s.id and o.service_id=sc.id where sc.profession_id=p.id and sc.active and sc.minimum_level<=lvl),'[]'::jsonb),
  'history',case when p.id='leatherworker'then coalesce((select jsonb_agg(jsonb_build_object('completed_at',c.created_at,'service',sc.name,'horse',coalesce(c.custom_name,'Crafted Tack'),'customer',client.name,'price',c.price)order by c.created_at desc)from(select * from leatherwork_commissions where provider_id=s.id and status='completed'order by created_at desc limit 100)c join service_catalog sc on sc.id=c.service_id join stables client on client.id=c.client_id),'[]'::jsonb)else coalesce((select jsonb_agg(jsonb_build_object('completed_at',r.completed_at,'service',sc.name,'horse',h.name,'customer',client.name,'price',r.price)order by r.completed_at desc)from(select * from horse_service_records where provider_id=s.id and profession_id=p.id and status='completed'order by completed_at desc limit 100)r join service_catalog sc on sc.id=r.service_id join horses h on h.id=r.horse_id join stables client on client.id=r.client_id),'[]'::jsonb)end
 );
 return result;
end$$;

revoke all on function public.get_profession_business_workspace(text)from public;
grant execute on function public.get_profession_business_workspace(text)to authenticated;
