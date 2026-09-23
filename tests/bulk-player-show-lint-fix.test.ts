import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const sql = readFileSync(
  "supabase/migrations/202609220011_fix_bulk_player_show_date_alias.sql",
  "utf8",
);

describe("bulk player Show lint correction", () => {
  it("qualifies the expanded run date instead of colliding with PL/pgSQL d", () => {
    expect(sql).toContain("expanded_date.run_date_value");
    expect(sql).toContain("unnest(p_run_dates) as expanded_date(run_date_value)");
    expect(sql).not.toContain("array_agg(d)");
  });

  it("preserves the authoritative Cartesian creation count and Show fields", () => {
    expect(sql).toContain("cardinality(p_discipline_ids)*cardinality(p_tier_ids)*cardinality(p_run_dates)");
    expect(sql).toContain("foreach rd in array p_run_dates");
    expect(sql).toContain("foreach d in array p_discipline_ids");
    expect(sql).toContain("foreach t in array p_tier_ids");
    expect(sql).toContain("d,t,rd,rd::timestamp at time zone 'America/New_York',p_entry_fee");
    expect(sql).toContain("'shows_created',total");
  });
});
