import { describe, expect, it } from "vitest";
import fs from "node:fs";

const migration = fs.readFileSync(
  "supabase/migrations/202609170022_level_specific_profession_tests.sql",
  "utf8",
);
const ui = fs.readFileSync("app/professions.tsx", "utf8");

describe("level-specific profession certification content", () => {
  it("defines three distinct questions for every profession and level", () => {
    for (const profession of ["farrier", "veterinarian", "trainer", "massage"])
      for (const level of [1, 2, 3, 4]) {
        const rows = migration.match(
          new RegExp(`\\('${profession}',${level},`, "g"),
        );
        expect(rows?.length, `${profession}/${level}`).toBe(3);
      }
  });

  it("removes the repeated seed and guards all sixteen banks", () => {
    expect(migration).toContain("delete from public.certification_questions");
    expect(migration).toContain("bank.count<3");
    expect(migration).toContain("Incomplete profession question banks");
  });

  it("continues selecting questions by profession and certification level", () => {
    expect(ui).toContain("target_profession: p.id");
    expect(ui).toContain("target_level: level");
  });
});

describe("career rate editor", () => {
  it("gates normal services by certification and uses the existing offering RPC", () => {
    expect(ui).toContain("service.minimum_level <= rateLevel");
    expect(ui).toContain('"set_service_offering"');
    expect(ui).toContain("SAVE RATE");
  });

  it("keeps QA-only validation out of persisted market offerings", () => {
    expect(ui).toContain("career.qa && !runNormal");
    expect(ui).toContain("live market data unchanged");
    expect(ui).toContain("VALIDATE QA RATE");
  });
});
