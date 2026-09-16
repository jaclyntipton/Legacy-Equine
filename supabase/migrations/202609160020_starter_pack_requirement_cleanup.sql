-- Starter Pack QA: NONE is state-only; one clean body; no export/debug artifacts.
do $$declare malformed integer;duplicates integer;begin
 select count(*)into malformed from horse_visual_asset_requirements r where r.trait_key='none'or r.category='body_template'or not exists(select 1 from equine_visual_taxonomy t where t.category=r.category and t.trait_key=r.trait_key);
 delete from horse_visual_asset_requirements r where r.trait_key='none'or r.category='body_template'or not exists(select 1 from equine_visual_taxonomy t where t.category=r.category and t.trait_key=r.trait_key);
 with ranked as(select id,row_number()over(partition by body_template_key,category,trait_key,coalesce(anatomical_position,''),variant order by created_at,id)rn from horse_visual_asset_requirements)delete from horse_visual_asset_requirements r using ranked x where r.id=x.id and x.rn>1;get diagnostics duplicates=row_count;
 insert into horse_visual_asset_requirements(body_template_key,category,trait_key,anatomical_position,canvas_width,canvas_height)
 select m.asset_key,'clean_body','neutral',null,1496,1051 from horse_visual_assets m where m.asset_key in('qh_mare_master_01','qh_stallion_master_01')on conflict do nothing;
 insert into admin_audit_log(actor_id,action_type,system,details)values(null,'starter_pack.requirements_cleaned','visuals',jsonb_build_object('malformed_removed',malformed,'duplicates_removed',duplicates,'authoritative_count_per_master',100));
end$$;

comment on table horse_visual_asset_requirements is 'Exact-master derived artwork requirements. NONE states apply no layer; immutable body masters are reference sources, not duplicate clean-body requirements.';
