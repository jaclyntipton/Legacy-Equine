import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const sql = readFileSync(
  "supabase/migrations/202609180001_fix_professional_service_preview_rate.sql",
  "utf8",
);

describe("Professional Market purchase preview", () => {
  it("qualifies certification level references", () => {
    expect(sql).toContain("cl.level=v_provider_level");
    expect(sql).not.toMatch(/\bwhere\s+level\s*=\s*level\b/);
  });

  it("uses the enabled provider offering rate through review", () => {
    expect(sql).toContain("v_service_price:=offering.price");
    expect(sql).toContain("'price',case when qa then 0 else v_service_price end");
    expect(sql).not.toContain("target_provider=auth.uid() then 0");
  });
});
