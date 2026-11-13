-- Owner-approved Quarter Horse mare Phase 1A Revision 2 pigment foundations.
-- Assets are approved for the library but requirements remain non-Production;
-- the generic fallback stays active until the exact master set is complete.
alter table public.horse_visual_assets
 add column if not exists blend_mode text not null default 'normal';
alter table public.horse_visual_assets
 drop constraint if exists horse_visual_assets_blend_mode_check;
alter table public.horse_visual_assets
 add constraint horse_visual_assets_blend_mode_check check(blend_mode in('normal','multiply'));

alter table public.equine_visual_taxonomy
 drop constraint if exists equine_visual_taxonomy_category_check;
alter table public.equine_visual_taxonomy
 add constraint equine_visual_taxonomy_category_check check(category in('face_marking','leg_marking','base_coat','leg_points','gray_stage','dun','cream','roan','silver','champagne','pearl','dapple','pinto_pattern','leopard_complex','visual_detail','mane','tail','clean_body'));

insert into public.equine_visual_taxonomy(category,trait_key,display_name,family,sort_order,metadata)
values('leg_points','black','Black Points','pigment',10,'{"requires_base":"bay"}')
on conflict(category,trait_key)do update set display_name=excluded.display_name,family=excluded.family,sort_order=excluded.sort_order,metadata=excluded.metadata,active=true;

insert into public.horse_visual_asset_requirements(body_template_key,category,trait_key,anatomical_position,canvas_width,canvas_height)
select a.asset_key,'leg_points','black',null,a.canvas_width,a.canvas_height
from public.horse_visual_assets a
where a.asset_type='body_template' and a.immutable_source and a.canvas_width is not null and a.canvas_height is not null
on conflict do nothing;

insert into public.horse_visual_assets(
 asset_key,asset_type,breed,sex,phenotype_key,image_url,z_index,status,active,
 review_notes,created_by,approved_by,approved_at,immutable_source,source_sha256,
 body_template_key,canvas_width,canvas_height,version,validation,blend_mode,life_stage
)
select v.asset_key,v.category,'Quarter Horse','Mare'::public.horse_sex,v.trait_key,v.image_url,v.z_index,
 'approved',true,'Owner #1 approved Phase 1A Revision 2 on 2026-11-13',s.id,s.id,now(),true,
 v.source_sha256,'qh_mare_vector_master_01',1496,1051,1,
 jsonb_build_object('technical_compatibility','pass','owner_approved',true,'master_sha256','3e239ed8c0571b27b42219739329825ec87386528747379a3aa8081a2ff632f1','blend_mode','multiply'),
 'multiply','mature'
from public.stables s
cross join(values
 ('qh_mare_phase1a_base_chestnut','base_coat','chestnut','/horse-visuals/vector-masters/qh_01/layers/phase1a_rev2/qh_mare_master_01__base_chestnut.svg',100,'827deb1a8df90624e19d7a8884802f0e2d161fd7bb6b34cfb373652b343cbdf6'),
 ('qh_mare_phase1a_base_black','base_coat','black','/horse-visuals/vector-masters/qh_01/layers/phase1a_rev2/qh_mare_master_01__base_black.svg',100,'f5369ae16d2002a0cb74929518a639f51b72294b33831922bffb1f562b45f7ea'),
 ('qh_mare_phase1a_base_bay','base_coat','bay','/horse-visuals/vector-masters/qh_01/layers/phase1a_rev2/qh_mare_master_01__base_bay.svg',100,'08219216ecc71d5bed7a232816e7921a29b586f582214aeab0fe3147f8aa790f'),
 ('qh_mare_phase1a_points_black','leg_points','black','/horse-visuals/vector-masters/qh_01/layers/phase1a_rev2/qh_mare_master_01__points_black.svg',110,'f10abecd3f4a7b58cafb832a26b3fb24c1075333a464d0f99d71147e57177754'),
 ('qh_mare_phase1a_mane_black','mane','black','/horse-visuals/vector-masters/qh_01/layers/phase1a_rev2/qh_mare_master_01__mane_black.svg',120,'09724afb279d104a4bb191e132ac4088d8b2dd47c26c0a394d4991b5518c324e'),
 ('qh_mare_phase1a_tail_black','tail','black','/horse-visuals/vector-masters/qh_01/layers/phase1a_rev2/qh_mare_master_01__tail_black.svg',120,'66c435dcdad39e0bbb102ac9cb2575a1f4de2cb2eaa7324c19f5ab3a4ad3cff9'),
 ('qh_mare_phase1a_mane_chestnut','mane','chestnut','/horse-visuals/vector-masters/qh_01/layers/phase1a_rev2/qh_mare_master_01__mane_chestnut.svg',120,'f79d96d2e7ed75a538a1dc25c4599cf5c61c29d14970e4f4096d43a8c6607b2e'),
 ('qh_mare_phase1a_tail_chestnut','tail','chestnut','/horse-visuals/vector-masters/qh_01/layers/phase1a_rev2/qh_mare_master_01__tail_chestnut.svg',120,'e806764ff79a9235c19271bfc078e28659703fc8ac3e4646b185203d7a8b52ac')
)v(asset_key,category,trait_key,image_url,z_index,source_sha256)
where s.account_number=1
on conflict(asset_key)do nothing;

update public.horse_visual_asset_requirements r
set asset_id=a.id,status='approved',notes='Owner #1 approved Phase 1A Revision 2; awaiting complete exact-master set before Production',updated_at=now()
from public.horse_visual_assets a
where r.body_template_key='qh_mare_vector_master_01'
 and a.body_template_key=r.body_template_key
 and a.asset_type=r.category
 and a.phenotype_key=r.trait_key
 and a.asset_key like 'qh_mare_phase1a_%';

create or replace function public.get_horse_visual_layers(p_horse_id uuid)
returns jsonb language sql stable security definer set search_path=public as $$
 with h as(select * from public.horses where id=p_horse_id),v as(
  select h.*,public.equine_visual_traits(h.genetics,public.horse_game_age(h.birth_date),h.visual_modifiers)traits from h
 ),assets as(
 select a.* from v join public.horse_visual_assets a on a.status='approved' and a.active and(
  (a.asset_type='body_template' and a.asset_key=v.visual_template_id)or
  (a.asset_type='base_coat' and a.phenotype_key=v.traits->>'underlying_base')or
  (a.asset_type='leg_points' and a.phenotype_key='black' and v.traits->>'underlying_base'='bay')or
  (a.asset_type='mane' and a.phenotype_key=case when v.traits->>'underlying_base'='chestnut'then'chestnut'else'black'end)or
  (a.asset_type='tail' and a.phenotype_key=case when v.traits->>'underlying_base'='chestnut'then'chestnut'else'black'end)or
  (a.asset_type='face_marking' and a.marking_key=lower(v.markings->>'face'))or
  (a.asset_type='leg_marking' and a.leg_position is not null and a.marking_key=lower(v.markings->>a.leg_position)))
 where(a.body_template_key=v.visual_template_id or a.breed is null or a.breed='*' or a.breed=v.breed)
 )
 select jsonb_build_object('horse_id',v.id,'template_id',v.visual_template_id,'fingerprint',v.visual_fingerprint,'custom_url',v.player_custom_image_url,'le_visual_url',v.le_visual_url,'layers',coalesce((select jsonb_agg(jsonb_build_object('asset_key',a.asset_key,'type',a.asset_type,'url',a.image_url,'z',a.z_index,'blend_mode',a.blend_mode)order by a.z_index,a.asset_key)from assets a),'[]'::jsonb))from v
$$;

create or replace function public.admin_visual_workspace()returns jsonb language plpgsql stable security definer set search_path=public as $$declare result jsonb;begin perform require_admin();select coalesce(jsonb_agg(item order by item->>'master',item->>'category',item->>'display_name'),'[]')into result from(select jsonb_build_object('requirement_id',r.id,'master',r.body_template_key,'master_url',m.image_url,'breed',m.breed,'sex',m.sex,'category',r.category,'trait_key',r.trait_key,'display_name',t.display_name,'limb',r.anatomical_position,'variant',r.variant,'status',r.status,'notes',r.notes,'width',r.canvas_width,'height',r.canvas_height,'asset_id',a.id,'asset_key',a.asset_key,'asset_url',a.image_url,'blend_mode',coalesce(a.blend_mode,'normal'),'version',a.version,'validation',coalesce(a.validation,'{}'::jsonb),'uploaded_at',a.created_at,'approved_at',a.approved_at,'history',coalesce((select jsonb_agg(jsonb_build_object('id',v.id,'key',v.asset_key,'url',v.image_url,'version',v.version,'status',v.status,'notes',v.review_notes,'uploaded_at',v.created_at,'approved_at',v.approved_at)order by v.version desc)from horse_visual_assets v where v.body_template_key=r.body_template_key and v.asset_type=r.category and coalesce(v.phenotype_key,v.marking_key,'')=coalesce(a.phenotype_key,a.marking_key,r.trait_key,'')and coalesce(v.leg_position,'')=coalesce(a.leg_position,case r.anatomical_position when'LF'then'left_front'when'RF'then'right_front'when'LH'then'left_hind'when'RH'then'right_hind'end,'')),'[]'::jsonb))item from horse_visual_asset_requirements r join horse_visual_assets m on m.asset_key=r.body_template_key join equine_visual_taxonomy t on t.category=r.category and t.trait_key=r.trait_key left join horse_visual_assets a on a.id=r.asset_id)s;return result;end$$;

comment on column public.horse_visual_assets.blend_mode is 'Deterministic compositing mode. Multiply layers must render inside an isolated horse stack.';
