do $$declare duplicate record;begin
 for duplicate in select id from(select id,row_number()over(partition by body_template_key,category,trait_key,coalesce(anatomical_position,''),variant order by(asset_id is not null)desc,updated_at desc,id)as ordinal from horse_visual_asset_requirements)ranked where ordinal>1 loop
  delete from horse_visual_asset_requirements where id=duplicate.id;
 end loop;
end$$;
drop index if exists horse_visual_asset_requirements_identity_nullsafe;
create unique index horse_visual_asset_requirements_identity_nullsafe on horse_visual_asset_requirements(body_template_key,category,trait_key,coalesce(anatomical_position,''),variant);
comment on index horse_visual_asset_requirements_identity_nullsafe is 'Prevents duplicate filename/requirement mappings even when anatomical position is NULL.';
