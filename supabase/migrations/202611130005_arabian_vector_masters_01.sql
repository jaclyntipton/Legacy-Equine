-- Owner #1 approved the Arabian vector masters exactly as delivered.
-- These immutable mature body references enter the library, but cannot display
-- on horses until every exact-master genetic layer requirement reaches Production.
insert into public.horse_visual_assets(
 asset_key,asset_type,breed,sex,image_url,z_index,status,active,review_notes,
 created_by,approved_by,approved_at,immutable_source,source_sha256,
 body_template_key,canvas_width,canvas_height,life_stage
)
select v.asset_key,'body_template','Arabian',v.sex::public.horse_sex,v.image_url,0,
 'approved',true,'Owner #1 approved exactly as delivered on 2026-11-13',
 s.id,s.id,now(),true,v.source_sha256,null,1496,1051,'mature'
from public.stables s
cross join(values
 ('arabian_mare_vector_master_01','Mare','/horse-visuals/vector-masters/arabian_01/arabian_mare_master_01.svg','5caa54bf4a9b6c0d60f56354c2e128ab8ae9688cdcb94bef27a14108c096801b'),
 ('arabian_stallion_vector_master_01','Stallion','/horse-visuals/vector-masters/arabian_01/arabian_stallion_master_01.svg','ef0cd6b83740b9d951b0bafddb75fa42c6a811eb06b5c36983227665e42d4c5a')
)v(asset_key,sex,image_url,source_sha256)
where s.account_number=1
on conflict(asset_key)do nothing;

insert into public.horse_visual_asset_requirements(
 body_template_key,category,trait_key,anatomical_position,canvas_width,canvas_height
)
select m.asset_key,t.category,t.trait_key,null,1496,1051
from public.horse_visual_assets m
cross join public.equine_visual_taxonomy t
where m.asset_key in('arabian_mare_vector_master_01','arabian_stallion_vector_master_01')
 and t.active and t.trait_key<>'none' and t.category<>'leg_marking'
on conflict do nothing;

insert into public.horse_visual_asset_requirements(
 body_template_key,category,trait_key,anatomical_position,canvas_width,canvas_height
)
select m.asset_key,t.category,t.trait_key,p.position,1496,1051
from public.horse_visual_assets m
cross join public.equine_visual_taxonomy t
cross join(values('LF'),('RF'),('LH'),('RH'))p(position)
where m.asset_key in('arabian_mare_vector_master_01','arabian_stallion_vector_master_01')
 and t.active and t.category='leg_marking' and t.trait_key<>'none'
on conflict do nothing;
