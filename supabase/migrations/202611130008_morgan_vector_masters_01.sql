-- Owner #1 approved the Morgan vector masters exactly as delivered.
-- These immutable mature body references enter the library, but cannot display
-- on horses until every exact-master genetic layer requirement reaches Production.
insert into public.horse_visual_assets(
 asset_key,asset_type,breed,sex,image_url,z_index,status,active,review_notes,
 created_by,approved_by,approved_at,immutable_source,source_sha256,
 body_template_key,canvas_width,canvas_height,life_stage
)
select v.asset_key,'body_template','Morgan',v.sex::public.horse_sex,v.image_url,0,
 'approved',true,'Owner #1 approved exactly as delivered on 2026-11-13',
 s.id,s.id,now(),true,v.source_sha256,null,1496,1051,'mature'
from public.stables s
cross join(values
 ('morgan_mare_vector_master_01','Mare','/horse-visuals/vector-masters/morgan_01/morgan_mare_master_01.svg','46dd0e0712599eb24c70fe4f2cbd956f9f8f2cacd58d846f7b4cfe078adf2969'),
 ('morgan_stallion_vector_master_01','Stallion','/horse-visuals/vector-masters/morgan_01/morgan_stallion_master_01.svg','a4ae86788b1b2ce749d08ac7432616d879186f62211e200aabccbffdd03a87c7')
)v(asset_key,sex,image_url,source_sha256)
where s.account_number=1
on conflict(asset_key)do nothing;

insert into public.horse_visual_asset_requirements(
 body_template_key,category,trait_key,anatomical_position,canvas_width,canvas_height
)
select m.asset_key,t.category,t.trait_key,null,1496,1051
from public.horse_visual_assets m
cross join public.equine_visual_taxonomy t
where m.asset_key in('morgan_mare_vector_master_01','morgan_stallion_vector_master_01')
 and t.active and t.trait_key<>'none' and t.category<>'leg_marking'
on conflict do nothing;

insert into public.horse_visual_asset_requirements(
 body_template_key,category,trait_key,anatomical_position,canvas_width,canvas_height
)
select m.asset_key,t.category,t.trait_key,p.position,1496,1051
from public.horse_visual_assets m
cross join public.equine_visual_taxonomy t
cross join(values('LF'),('RF'),('LH'),('RH'))p(position)
where m.asset_key in('morgan_mare_vector_master_01','morgan_stallion_vector_master_01')
 and t.active and t.category='leg_marking' and t.trait_key<>'none'
on conflict do nothing;
