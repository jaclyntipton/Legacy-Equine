-- Dedicated Stable customizer: presentation metadata only, never executable code.
alter table public.stable_public_profiles
 add column if not exists layout_mode text not null default 'standard' check(layout_mode in('standard','custom')),
 add column if not exists layout_image_url text not null default '';

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
  'blocks',coalesce(p.blocks,'[{"id":"banner","type":"banner","visible":true},{"id":"news","type":"news","visible":true},{"id":"about","type":"about","visible":true},{"id":"featured","type":"featured","visible":true},{"id":"stallions","type":"stallions","visible":true},{"id":"broodmares","type":"broodmares","visible":true},{"id":"winners","type":"winners","visible":true},{"id":"services","type":"services","visible":true},{"id":"roster","type":"roster","visible":true},{"id":"custom","type":"custom","visible":true,"content":""}]'::jsonb),
  'featured_horses',coalesce(p.featured_horses,'{}'::uuid[]),'layout_mode',coalesce(p.layout_mode,'standard'),'layout_image_url',coalesce(p.layout_image_url,''),
  'owner',auth.uid()=p_stable,'can_customize',public.has_custom_stable_layout(p_stable),
  'horses',coalesce((select jsonb_agg(jsonb_build_object('id',h.id,'name',h.name,'breed',h.breed,'sex',h.sex,'color',h.color,'image_url',h.image_url,'career_points',h.career_points)order by h.name)from horses h where h.owner_id=p_stable and not h.retired),'[]'::jsonb),
  'services',public.get_public_professional_services(p_stable)
 );return result;
end$$;

create or replace function public.save_public_stable_customization(p_mode text,p_layout_image_url text,p_blocks jsonb) returns void
language plpgsql security definer set search_path=public as $$
declare
 allowed text[]:=array['banner','news','about','featured','stallions','broodmares','winners','services','roster','custom'];
 hotspot_types text[]:=array['news','featured','about','services','roster'];
 clean jsonb;clean_url text:=left(trim(coalesce(p_layout_image_url,'')),2048);
begin
 if p_mode not in('standard','custom')then raise exception 'Choose Standard or Custom Layout';end if;
 if p_mode='custom'and not has_custom_stable_layout(auth.uid())then raise exception 'Custom Stable Layouts unlock at Account Level 20';end if;
 if p_mode='custom'and clean_url=''then raise exception 'Upload a Stable Layout image before using Custom Layout';end if;
 if clean_url<>''and clean_url not like '%/storage/v1/object/public/legacy-equine-media/'||auth.uid()::text||'/artwork-album/%'then raise exception 'Choose an image from your Legacy Equine uploads';end if;
 if jsonb_typeof(p_blocks)<>'array'or jsonb_array_length(p_blocks)>20 then raise exception 'Invalid Stable layout';end if;
 if exists(select 1 from jsonb_array_elements(p_blocks)x where not(x->>'type'=any(allowed))or coalesce(x->>'id','')!~'^[a-z0-9_-]{1,40}$')then raise exception 'Unsupported Stable layout block';end if;
 if(select count(*)from jsonb_array_elements(p_blocks))<>(select count(distinct x->>'id')from jsonb_array_elements(p_blocks)x)then raise exception 'Stable layout block IDs must be unique';end if;
 select jsonb_agg(
  jsonb_build_object('id',x->>'id','type',x->>'type','visible',coalesce((x->>'visible')::boolean,true))
  ||case when x->>'type'='custom'then jsonb_build_object('content',stable_safe_rich_text(x->>'content'))else'{}'::jsonb end
  ||case when x->>'type'=any(hotspot_types)then jsonb_build_object('hotspot',jsonb_build_object(
    'x',least(95,greatest(0,coalesce((x->'hotspot'->>'x')::numeric,0))),
    'y',least(95,greatest(0,coalesce((x->'hotspot'->>'y')::numeric,0))),
    'width',least(50,greatest(1,coalesce((x->'hotspot'->>'width')::numeric,20))),
    'height',least(50,greatest(1,coalesce((x->'hotspot'->>'height')::numeric,10)))
  ))else'{}'::jsonb end
 )into clean from jsonb_array_elements(p_blocks)x;
 insert into stable_public_profiles(stable_id,blocks,layout_mode,layout_image_url)
 values(auth.uid(),clean,p_mode,clean_url)
 on conflict(stable_id)do update set blocks=excluded.blocks,layout_mode=excluded.layout_mode,layout_image_url=excluded.layout_image_url,updated_at=now();
end$$;

create or replace function public.reset_public_stable_layout() returns void language plpgsql security definer set search_path=public as $$begin
 update stable_public_profiles set layout_mode='standard',blocks='[{"id":"banner","type":"banner","visible":true},{"id":"news","type":"news","visible":true},{"id":"about","type":"about","visible":true},{"id":"featured","type":"featured","visible":true},{"id":"stallions","type":"stallions","visible":true},{"id":"broodmares","type":"broodmares","visible":true},{"id":"winners","type":"winners","visible":true},{"id":"services","type":"services","visible":true},{"id":"roster","type":"roster","visible":true},{"id":"custom","type":"custom","visible":true,"content":""}]'::jsonb,updated_at=now()where stable_id=auth.uid();
end$$;

revoke all on function public.save_public_stable_customization(text,text,jsonb) from public;
grant execute on function public.save_public_stable_customization(text,text,jsonb),public.get_public_stable_profile(uuid) to authenticated;
