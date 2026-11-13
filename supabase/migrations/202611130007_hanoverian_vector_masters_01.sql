-- Owner #1 approved the Hanoverian vector masters exactly as delivered.
-- These immutable mature body references enter the library, but cannot display
-- on horses until every exact-master genetic layer requirement reaches Production.
insert into public.horse_visual_assets(
 asset_key,asset_type,breed,sex,image_url,z_index,status,active,review_notes,
 created_by,approved_by,approved_at,immutable_source,source_sha256,
 body_template_key,canvas_width,canvas_height,life_stage
)
select v.asset_key,'body_template','Hanoverian',v.sex::public.horse_sex,v.image_url,0,
 'approved',true,'Owner #1 approved exactly as delivered on 2026-11-13',
 s.id,s.id,now(),true,v.source_sha256,null,1496,1051,'mature'
from public.stables s
cross join(values
 ('hanoverian_mare_vector_master_01','Mare','/horse-visuals/vector-masters/hanoverian_01/hanoverian_mare_master_01.svg','f4f50d9a803144a5dad582311b85a64864f487e88413c8a1363cf148357d67b7'),
 ('hanoverian_stallion_vector_master_01','Stallion','/horse-visuals/vector-masters/hanoverian_01/hanoverian_stallion_master_01.svg','cd3895081ab7d26027c6956665df30100c9da24f1da07ec90b12644a1c3c2849')
)v(asset_key,sex,image_url,source_sha256)
where s.account_number=1
on conflict(asset_key)do nothing;

insert into public.horse_visual_asset_requirements(
 body_template_key,category,trait_key,anatomical_position,canvas_width,canvas_height
)
select m.asset_key,t.category,t.trait_key,null,1496,1051
from public.horse_visual_assets m
cross join public.equine_visual_taxonomy t
where m.asset_key in('hanoverian_mare_vector_master_01','hanoverian_stallion_vector_master_01')
 and t.active and t.trait_key<>'none' and t.category<>'leg_marking'
on conflict do nothing;

insert into public.horse_visual_asset_requirements(
 body_template_key,category,trait_key,anatomical_position,canvas_width,canvas_height
)
select m.asset_key,t.category,t.trait_key,p.position,1496,1051
from public.horse_visual_assets m
cross join public.equine_visual_taxonomy t
cross join(values('LF'),('RF'),('LH'),('RH'))p(position)
where m.asset_key in('hanoverian_mare_vector_master_01','hanoverian_stallion_vector_master_01')
 and t.active and t.category='leg_marking' and t.trait_key<>'none'
on conflict do nothing;
