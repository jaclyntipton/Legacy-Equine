-- Complete the explicit browser allowlist with multiline/generic production calls
-- discovered by the source-to-grant regression test.
do $migration$
declare
  v_names text[] := array[
    'admin_moderation_workspace','admin_test_moderation',
    'admin_list_foundation_genetics','admin_update_foundation_genetic_weight',
    'admin_list_horse_visual_assets','buy_marketplace_horse','owner_set_admin',
    'get_profession_certification_cooldown','admin_bypass_profession_certification_cooldown',
    'admin_mark_profession_requirement_complete','preview_professional_services',
    'purchase_professional_services'
  ];
  v_record record;
begin
  for v_record in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f' and p.proname = any(v_names)
  loop
    execute format('grant execute on function %s to authenticated', v_record.signature);
  end loop;

  if exists (
    select 1 from unnest(v_names) wanted(name)
    where not exists (
      select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.prokind = 'f' and p.proname = wanted.name
    )
  ) then
    raise exception 'Registered authenticated RPC is missing from public schema';
  end if;
end
$migration$;
