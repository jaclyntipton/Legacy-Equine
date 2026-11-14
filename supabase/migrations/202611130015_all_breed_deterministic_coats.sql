-- Generalize the approved deterministic compositor recipe to every supplied
-- breed master. All foals share the one Quarter Horse foal body master.
create or replace function public.get_horse_visual_recipe(p_horse_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare h public.horses;m public.horse_visual_assets;stage text;master_breed text;master_sex public.horse_sex;begin
 select * into h from public.horses where id=p_horse_id;
 if not found then return null;end if;
 stage:=public.horse_visual_life_stage(h.birth_date);
 if stage='foal' then
  select * into m from public.horse_visual_assets
   where asset_key='qh_foal_vector_master_01' and asset_type='body_template'
    and status='approved' and active limit 1;
 else
  master_breed:=public.horse_visual_master_breed(h.breed);
  master_sex:=case when h.sex='Gelding' then 'Stallion'::public.horse_sex else h.sex end;
  select * into m from public.horse_visual_assets
   where asset_type='body_template' and status='approved' and active
    and breed=master_breed and life_stage='mature' and sex=master_sex
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

with chosen as(
 select h.id,a.asset_key,a.image_url
 from public.horses h
 join public.horse_visual_assets a on a.asset_type='body_template' and a.status='approved' and a.active
  and((public.horse_visual_life_stage(h.birth_date)='foal' and a.asset_key='qh_foal_vector_master_01')or
   (public.horse_visual_life_stage(h.birth_date)='mature'
    and a.breed=public.horse_visual_master_breed(h.breed) and a.life_stage='mature'
    and a.sex=case when h.sex='Gelding' then 'Stallion'::public.horse_sex else h.sex end))
)
update public.horses h set
 visual_template_id=c.asset_key,
 visual_fingerprint=md5(concat_ws('|',c.asset_key,h.genetics::text,h.markings::text,h.visual_modifiers::text)),
 le_visual_url=c.image_url,image_url=coalesce(nullif(h.player_custom_image_url,''),c.image_url),
 image_generation_status='complete',image_quality_status='approved',
 image_prompt_version='deterministic-layers-v3'
from chosen c where c.id=h.id;

revoke all on function public.get_horse_visual_recipe(uuid) from public;
grant execute on function public.get_horse_visual_recipe(uuid) to authenticated;
