-- Owner #1 approved the Quarter Horse vector masters exactly as delivered.
-- These immutable body references enter the library, but cannot display on
-- horses until every exact-master genetic layer requirement reaches Production.
insert into public.horse_visual_assets(
 asset_key,asset_type,breed,sex,image_url,z_index,status,active,review_notes,
 created_by,approved_by,approved_at,immutable_source,source_sha256,
 body_template_key,canvas_width,canvas_height,life_stage
)
select v.asset_key,'body_template','Quarter Horse',v.sex::public.horse_sex,v.image_url,0,
 'approved',true,'Owner #1 approved exactly as delivered on 2026-11-13',
 s.id,s.id,now(),true,v.source_sha256,null,1496,1051,v.life_stage
from public.stables s
cross join(values
 ('qh_foal_vector_master_01',null,'/horse-visuals/vector-masters/qh_01/qh_foal_master_01.svg','eaf20168d7b768d8bddca4057721fb4aa7147952eee8d3170c46995f18a77365','foal'),
 ('qh_mare_vector_master_01','Mare','/horse-visuals/vector-masters/qh_01/qh_mare_master_01.svg','3e239ed8c0571b27b42219739329825ec87386528747379a3aa8081a2ff632f1','mature'),
 ('qh_stallion_vector_master_01','Stallion','/horse-visuals/vector-masters/qh_01/qh_stallion_master_01.svg','ed541fc2843166537891e61a2ab8ad75f79d76222d5a85715acb167442ec0dd8','mature')
)v(asset_key,sex,image_url,source_sha256,life_stage)
where s.account_number=1
on conflict(asset_key)do nothing;

insert into public.horse_visual_asset_requirements(
 body_template_key,category,trait_key,anatomical_position,canvas_width,canvas_height
)
select m.asset_key,t.category,t.trait_key,null,1496,1051
from public.horse_visual_assets m
cross join public.equine_visual_taxonomy t
where m.asset_key in('qh_foal_vector_master_01','qh_mare_vector_master_01','qh_stallion_vector_master_01')
 and t.active and t.trait_key<>'none' and t.category<>'leg_marking'
on conflict do nothing;

insert into public.horse_visual_asset_requirements(
 body_template_key,category,trait_key,anatomical_position,canvas_width,canvas_height
)
select m.asset_key,t.category,t.trait_key,p.position,1496,1051
from public.horse_visual_assets m
cross join public.equine_visual_taxonomy t
cross join(values('LF'),('RF'),('LH'),('RH'))p(position)
where m.asset_key in('qh_foal_vector_master_01','qh_mare_vector_master_01','qh_stallion_vector_master_01')
 and t.active and t.category='leg_marking' and t.trait_key<>'none'
on conflict do nothing;

comment on column public.horse_visual_assets.life_stage is 'Foal or mature body stage. Any is reserved for a neutral fallback carrying no phenotype.';
