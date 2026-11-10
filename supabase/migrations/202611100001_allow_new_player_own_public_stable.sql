-- A newly initialized account can remain unverified while completing onboarding.
-- Keep that Stable private from other players, but let its authenticated owner
-- open the existing Stable/Profile workspace instead of receiving Stable not found.
create or replace function public.get_public_stable_profile(p_stable uuid) returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare s stables;p stable_public_profiles;b stable_brands;result jsonb;begin
 select * into s from stables
 where id=p_stable and(account_status='active' or id=auth.uid());
 if not found then raise exception 'Stable not found';end if;
 select * into p from stable_public_profiles where stable_id=p_stable;
 select * into b from stable_brands where stable_id=p_stable and(active or reserved);
 result:=jsonb_build_object(
  'id',s.id,'name',s.name,'username',s.username,'account_number',s.account_number,'ranch_image_url',s.ranch_image_url,'created_at',s.created_at,
  'brand',case when b.id is null then null else jsonb_build_object('code',b.code,'mark_url',b.mark_url,'active',b.active)end,
  'stable_news',coalesce(p.stable_news,''),'about',coalesce(nullif(p.about_text,''),s.bio,''),
  'blocks',coalesce(p.blocks,'[{"id":"banner","type":"banner","visible":true},{"id":"news","type":"news","visible":true},{"id":"about","type":"about","visible":true},{"id":"featured","type":"featured","visible":true},{"id":"stallions","type":"stallions","visible":true},{"id":"broodmares","type":"broodmares","visible":true},{"id":"winners","type":"winners","visible":true},{"id":"services","type":"services","visible":true},{"id":"roster","type":"roster","visible":true},{"id":"custom","type":"custom","visible":true,"content":""}]'::jsonb),
  'featured_horses',coalesce(p.featured_horses,'{}'::uuid[]),'layout_mode',coalesce(p.layout_mode,'standard'),'layout_image_url',coalesce(p.layout_image_url,''),
  'owner',auth.uid()=p_stable,'can_customize',public.has_custom_stable_layout(p_stable),
  'horses',coalesce((select jsonb_agg(jsonb_build_object('id',h.id,'name',h.name,'breed',h.breed,'sex',h.sex,'color',h.color,'image_url',h.image_url,'career_points',h.career_points)order by h.name)from horses h where h.owner_id=p_stable and not h.retired),'[]'::jsonb),
  'services',public.get_public_professional_services(p_stable)
 );return result;
end$$;

revoke all on function public.get_public_stable_profile(uuid) from public,anon;
grant execute on function public.get_public_stable_profile(uuid) to authenticated;
