-- Owner-approved Tennessee Walking Horse and Rocky Mountain Horse deterministic coats.
-- Mature horses use their sex-specific master; all foals keep the universal foal visual.
create or replace function public.get_horse_visual_recipe(p_horse_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare h public.horses;m public.horse_visual_assets;stage text;begin
 select * into h from public.horses where id=p_horse_id;
 if not found then return null;end if;
 stage:=public.horse_visual_life_stage(h.birth_date);
 if stage='mature' and h.breed in('Tennessee Walking Horse','Rocky Mountain Horse') then
  select * into m from public.horse_visual_assets
  where asset_type='body_template' and status='approved' and active and breed=h.breed
   and life_stage='mature' and sex=case when h.sex='Gelding' then 'Stallion'::public.horse_sex else h.sex end
  order by approved_at desc nulls last limit 1;
 end if;
 return jsonb_build_object(
  'horse_id',h.id,'template_id',m.asset_key,'master_url',m.image_url,
  'custom_url',h.player_custom_image_url,'life_stage',stage,
  'traits',public.equine_visual_traits(h.genetics,public.horse_game_age(h.birth_date),h.visual_modifiers),
  'genetics',coalesce(h.genetics,'{}'::jsonb),'markings',coalesce(h.markings,'{}'::jsonb),
  'modifiers',coalesce(h.visual_modifiers,'{}'::jsonb)
 );
end
$$;

update public.horses h set
 visual_template_id=a.asset_key,
 visual_fingerprint=md5(concat_ws('|',a.asset_key,h.genetics::text,h.markings::text,h.visual_modifiers::text)),
 le_visual_url=a.image_url,
 image_url=coalesce(nullif(h.player_custom_image_url,''),a.image_url),
 image_generation_status='complete',image_quality_status='approved',
 image_prompt_version='deterministic-layers-v3'
from public.horse_visual_assets a
where h.breed in('Tennessee Walking Horse','Rocky Mountain Horse')
 and public.horse_visual_life_stage(h.birth_date)='mature'
 and a.asset_type='body_template' and a.status='approved' and a.active
 and a.breed=h.breed and a.life_stage='mature'
 and a.sex=case when h.sex='Gelding' then 'Stallion'::public.horse_sex else h.sex end;

revoke all on function public.get_horse_visual_recipe(uuid) from public;
grant execute on function public.get_horse_visual_recipe(uuid) to authenticated;

comment on function public.get_horse_visual_recipe(uuid) is 'Returns the immutable master and genetic recipe used by the approved browser compositor. Custom artwork retains priority; foals remain on the universal foal visual.';
