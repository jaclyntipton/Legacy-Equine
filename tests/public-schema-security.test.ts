import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const migration = readFileSync(
  "supabase/migrations/202609220007_public_schema_rls_hardening.sql",
  "utf8",
);

const exposedTables = [
  "breed_cross_rules",
  "breed_visual_archetypes",
  "items",
  "news_auto_rules",
  "progression_config",
  "show_auto_host_repair_state",
];

describe("public schema security hardening", () => {
  it("enables RLS for every production finding", () => {
    for (const table of exposedTables) {
      expect(migration).toContain(
        `alter table public.${table} enable row level security`,
      );
      expect(migration).toContain(
        `revoke all on table public.${table} from anon, authenticated`,
      );
    }
  });

  it("keeps only non-sensitive reference catalogs player-readable", () => {
    for (const table of [
      "breed_cross_rules",
      "breed_visual_archetypes",
      "items",
    ]) {
      expect(migration).toContain(
        `grant select on table public.${table} to authenticated`,
      );
    }
    for (const table of [
      "news_auto_rules",
      "progression_config",
      "show_auto_host_repair_state",
    ]) {
      expect(migration).not.toContain(
        `grant select on table public.${table} to authenticated`,
      );
    }
  });

  it("makes future public objects opt in and adds a database guard", () => {
    expect(migration).toContain("alter default privileges for role postgres");
    expect(migration).toContain("revoke all on tables from anon, authenticated");
    expect(migration).toContain("assert_exposed_tables_have_rls");
    expect(migration).toContain("select public.assert_exposed_tables_have_rls()");
  });
});
