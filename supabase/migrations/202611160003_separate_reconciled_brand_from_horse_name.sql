-- Brand is authoritative horse provenance and must remain separate from the
-- horse's name. Remove only the redundant code prefix on the legacy Admin
-- Custom horses reconciled by the immediately preceding migration.

do $$
declare
  item record;
  corrected_name text;
  actor_account_number bigint;
begin
  for item in
    select h.id,h.name,h.owner_id,h.brand_code_at_assignment
    from horses h
    where h.brand_origin='Owner Custom Creation Reconciliation'
      and h.brand_code_at_assignment is not null
      and lower(h.name) like lower(h.brand_code_at_assignment)||' %'
  loop
    corrected_name:=trim(substr(
      item.name,length(item.brand_code_at_assignment)+2
    ));
    if corrected_name='' then continue;end if;

    select account_number into actor_account_number
    from stables where id=item.owner_id;

    update horses set name=corrected_name where id=item.id;
    insert into horse_edit_audit(
      horse_id,horse_name,actor_id,actor_account,action,changed_fields,
      old_values,new_values,reason
    ) values(
      item.id,corrected_name,item.owner_id,actor_account_number,
      'legacy_brand_name_prefix_removed',array['name'],
      jsonb_build_object('name',item.name),
      jsonb_build_object('name',corrected_name),
      'Separated reconciled permanent Stable Brand from horse name'
    );
  end loop;
end
$$;

