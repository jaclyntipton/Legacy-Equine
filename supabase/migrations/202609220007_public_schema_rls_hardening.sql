-- Close the production Data API exposure reported by Security Advisor.
-- Reference catalogs remain readable to signed-in players; operational/config
-- tables remain available only to trusted database functions/service_role.

alter table public.breed_cross_rules enable row level security;
alter table public.breed_visual_archetypes enable row level security;
alter table public.items enable row level security;
alter table public.news_auto_rules enable row level security;
alter table public.progression_config enable row level security;
alter table public.show_auto_host_repair_state enable row level security;

revoke all on table public.breed_cross_rules from anon, authenticated;
revoke all on table public.breed_visual_archetypes from anon, authenticated;
revoke all on table public.items from anon, authenticated;
revoke all on table public.news_auto_rules from anon, authenticated;
revoke all on table public.progression_config from anon, authenticated;
revoke all on table public.show_auto_host_repair_state from anon, authenticated;

grant select on table public.breed_cross_rules to authenticated;
grant select on table public.breed_visual_archetypes to authenticated;
grant select on table public.items to authenticated;

create policy "authenticated reads breed cross reference"
on public.breed_cross_rules for select to authenticated using (true);

create policy "authenticated reads breed visual reference"
on public.breed_visual_archetypes for select to authenticated using (true);

create policy "authenticated reads legacy item catalog"
on public.items for select to authenticated using (true);

-- New public tables and functions must opt in to browser access explicitly in
-- the same migration that defines their RLS policies/authorization checks.
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;

create or replace function public.assert_exposed_tables_have_rls()
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  missing text;
begin
  select string_agg(format('%I.%I', n.nspname, c.relname), ', ' order by c.relname)
    into missing
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname in ('public', 'graphql_public')
    and c.relkind in ('r', 'p')
    and not c.relrowsecurity;

  if missing is not null then
    raise exception 'Exposed tables without RLS: %', missing;
  end if;
end
$$;

revoke all on function public.assert_exposed_tables_have_rls() from public, anon, authenticated;
grant execute on function public.assert_exposed_tables_have_rls() to service_role;

select public.assert_exposed_tables_have_rls();
