-- Explicit RPC execution posture for the exposed public schema.
-- Browser clients receive only the functions used by the production app.
-- All unlisted functions remain callable by trusted database owners/service_role.

do $migration$
declare
  v_authenticated text[] := array[
    'add_support_reply','admin_adjust_balance','admin_artwork_storage_accounts','admin_audit_feed',
    'admin_bulk_run_shows','admin_commerce_workspace','admin_correct_private_identity',
    'admin_create_visual_horse','admin_delete_moderation_rule','admin_effective_permissions',
    'admin_get_private_identity','admin_handbook_workspace','admin_list_stable_brands',
    'admin_list_stables','admin_news_list','admin_news_quick_action',
    'admin_owner_profession_evidence','admin_owner_profession_financial_evidence',
    'admin_preview_show_auto_host','admin_preview_show_level_counts','admin_preview_show_results',
    'admin_profession_persistence_integrity','admin_promote_visual_asset',
    'admin_regenerate_horse_image','admin_resolve_moderation_event','admin_restock_feed_product',
    'admin_review_horse_visual_asset','admin_review_visual_asset','admin_run_show_auto_host',
    'admin_save_handbook_article','admin_save_horse_visual_asset','admin_save_moderation_rule',
    'admin_save_news','admin_save_show_auto_host','admin_save_show_economy_defaults',
    'admin_save_show_level_thresholds','admin_set_show_qa_access','admin_show_action',
    'admin_show_workspace','admin_support_workspace','admin_update_feed_storage_config',
    'admin_update_feed_v2_product','admin_update_foundation_store','admin_update_horse_game_config',
    'admin_update_profession_retry_cooldown','admin_update_show_ap_config',
    'admin_update_store_product','admin_update_support_ticket','admin_visual_asset_manifest',
    'admin_visual_workspace','advance_profession_career','allocate_horse_ap',
    'artwork_storage_summary','breed_horses','collect_weekly_allowances',
    'complete_account_information','complete_profession_study','confirm_show_entries','create_shows',
    'enroll_profession','equip_tack','feed_horses','finalize_artwork_album_upload',
    'get_account_progression','get_bank_activity','get_bank_summary','get_breeding_genetic_preview',
    'get_chat_messages','get_chat_rooms','get_community_directory','get_feed_room_eligibility',
    'get_forum_posts','get_handbook','get_handbook_article','get_home_news','get_horse_ap_summary',
    'get_horse_editor_data','get_horse_equipped_tack','get_horse_service_history',
    'get_horse_show_record','get_horse_wellness','get_marketplace','get_my_account_eligibility',
    'get_my_profession_businesses','get_my_stable_brand','get_my_stable_capacity',
    'get_my_support_tickets','get_my_support_update_count','get_news_article','get_open_shows',
    'get_owned_horse_show_levels','get_player_shows','get_profession_business_workspace',
    'get_profession_dashboard','get_public_player_profile','get_public_profession_business',
    'get_public_stable_profile','get_sanctuary_horses','get_service_directory',
    'get_show_auto_host_workspace','get_show_capabilities','get_show_level_config','get_show_results',
    'get_store_feed_catalog','get_store_inventory','get_support_ticket','get_weekly_allowances',
    'has_horse_editor_permission','initialize_stable','list_horse_for_sale','manage_chat_room',
    'mark_news_viewed','moderate_chat_message','mute_chat_user','open_profession_qa_career',
    'owner_correct_horse_ap','owner_correct_horse_brand','owner_edit_horse',
    'owner_grant_artwork_storage','owner_grant_stalls','owner_set_admin_permissions',
    'owner_set_horse_age','owner_set_horse_editor_permission','owner_set_subscriber_artwork_capacity',
    'owner_set_unlimited_capacity','preview_eligible_show_entries','preview_leatherwork_commission',
    'purchase_leatherwork_commission','purchase_store_horse','purchase_store_product_bulk',
    'reconcile_show_fund_history','remove_artwork_album_item','report_missing_horse_image',
    'reserve_artwork_album_upload','save_my_stable_brand','save_profession_business_profile',
    'save_public_stable_content','save_public_stable_customization','send_chat_message',
    'send_horse_to_sanctuary','set_service_offering','show_fund_fund_show',
    'submit_support_ticket','train_horse','treasury_award','treasury_to_show_fund','unequip_tack',
    'update_horse_profile','update_stable_images','update_stable_profile'
  ];
  v_anon text[] := array[
    'get_handbook','get_handbook_article','get_home_news','get_news_article',
    'get_public_player_profile','get_public_profession_business','get_public_stable_profile',
    'public_signup_availability'
  ];
  v_record record;
begin
  -- Remove PostgreSQL's inherited PUBLIC execute privilege and all legacy client grants.
  for v_record in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
  loop
    execute format(
      'revoke execute on function %s from public, anon, authenticated',
      v_record.signature
    );
  end loop;

  -- Grant every overload of an explicitly registered production browser RPC.
  for v_record in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
      and p.proname = any(v_authenticated)
  loop
    execute format('grant execute on function %s to authenticated', v_record.signature);
  end loop;

  -- Only deliberately public, read-oriented endpoints plus signup availability are anonymous.
  for v_record in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
      and p.proname = any(v_anon)
  loop
    execute format('grant execute on function %s to anon', v_record.signature);
  end loop;

  -- Fail closed if application registration drifts from the deployed database.
  if exists (
    select 1 from unnest(v_authenticated) wanted(name)
    where not exists (
      select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.prokind = 'f' and p.proname = wanted.name
    )
  ) then
    raise exception 'Registered authenticated RPC is missing from public schema';
  end if;

  if exists (
    select 1 from unnest(v_anon) wanted(name)
    where not exists (
      select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.prokind = 'f' and p.proname = wanted.name
    )
  ) then
    raise exception 'Registered anonymous RPC is missing from public schema';
  end if;
end
$migration$;

-- New functions remain non-executable by browser roles until explicitly registered.
alter default privileges for role postgres in schema public revoke execute on functions from public;
alter default privileges for role postgres in schema public revoke execute on functions from anon;
alter default privileges for role postgres in schema public revoke execute on functions from authenticated;

