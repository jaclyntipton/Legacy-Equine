-- Owner #1 supplied the Tennessee Walking Horse mature vector masters.
-- All Tennessee Walking Horse foals use the universal Quarter Horse foal master.
insert into public.horse_visual_assets(
 asset_key,asset_type,breed,sex,image_url,z_index,status,active,review_notes,
 created_by,approved_by,approved_at,immutable_source,source_sha256,
 body_template_key,canvas_width,canvas_height,life_stage
)
select v.asset_key,'body_template','Tennessee Walking Horse',v.sex::public.horse_sex,v.image_url,0,
 'approved',true,'Owner #1 supplied for registration on 2026-11-13',
 s.id,s.id,now(),true,v.source_sha256,null,1496,1051,'mature'
from public.stables s
cross join(values
 ('tennessee_walking_horse_mare_vector_master_01','Mare','/horse-visuals/vector-masters/tennessee_walking_horse_01/tennessee_walking_horse_mare_master_01.svg','1896644d1d6b39711036e93d6120dda9bcf80dd1f507aabe851863c17893ccd1'),
 ('tennessee_walking_horse_stallion_vector_master_01','Stallion','/horse-visuals/vector-masters/tennessee_walking_horse_01/tennessee_walking_horse_stallion_master_01.svg','84a5ad5723b66aaf1b314a1a6f341f35dd3a994607330ae5a3b68282db480e39')
)v(asset_key,sex,image_url,source_sha256)
where s.account_number=1
on conflict(asset_key)do nothing;

insert into public.horse_visual_asset_requirements(
 body_template_key,category,trait_key,anatomical_position,canvas_width,canvas_height
)
select m.asset_key,t.category,t.trait_key,null,1496,1051
from public.horse_visual_assets m
cross join public.equine_visual_taxonomy t
where m.asset_key in('tennessee_walking_horse_mare_vector_master_01','tennessee_walking_horse_stallion_vector_master_01')
 and t.active and t.trait_key<>'none' and t.category<>'leg_marking'
on conflict do nothing;

insert into public.horse_visual_asset_requirements(
 body_template_key,category,trait_key,anatomical_position,canvas_width,canvas_height
)
select m.asset_key,t.category,t.trait_key,p.position,1496,1051
from public.horse_visual_assets m
cross join public.equine_visual_taxonomy t
cross join(values('LF'),('RF'),('LH'),('RH'))p(position)
where m.asset_key in('tennessee_walking_horse_mare_vector_master_01','tennessee_walking_horse_stallion_vector_master_01')
 and t.active and t.category='leg_marking' and t.trait_key<>'none'
on conflict do nothing;
