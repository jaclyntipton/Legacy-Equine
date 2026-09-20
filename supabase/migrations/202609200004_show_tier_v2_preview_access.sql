-- Temporary aggregate-only access used to capture the required pre-mutation
-- production acceptance summary. Revoked by the activation migration.
grant execute on function public.preview_show_tier_v2_migration()to anon;
