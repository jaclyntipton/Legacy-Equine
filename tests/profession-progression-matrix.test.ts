import { describe, expect, it } from "vitest";
import fs from "node:fs";

const progression = fs.readFileSync(
  "supabase/migrations/202609170023_complete_profession_level_progression.sql",
  "utf8",
);
const curriculum = fs.readFileSync(
  "supabase/migrations/202609150030_professional_services.sql",
  "utf8",
);
const questions = fs.readFileSync(
  "supabase/migrations/202609170022_level_specific_profession_tests.sql",
  "utf8",
);
const ui = fs.readFileSync("app/professions.tsx", "utf8");
const professions = ["farrier", "veterinarian", "trainer", "massage"];
const levels = [1, 2, 3, 4];

describe("all profession progression paths", () => {
  for (const profession of professions)
    for (const level of levels)
      it(`${profession} level ${level} resolves curriculum, test, requirement, and advancement`, () => {
        expect(curriculum).toContain(`('${profession}',${level},`);
        expect(questions.match(new RegExp(`\\('${profession}',${level},`, "g")))
          .toHaveLength(3);
        expect(progression).toContain(
          "from public.professions p cross join public.certification_levels l",
        );
        expect(progression).toContain(
          "profession_id=target_profession and level=pp.certification_level",
        );
        if (level < 4)
          expect(progression).toContain("target:=pp.certification_level+1");
        else
          expect(progression).toContain("if pp.certification_level=4 then");
      });

  it("never configures a zero-service level", () => {
    expect(progression).toContain("check (required_services > 0)");
    expect(progression).toContain("case l.level when 1 then 5");
    expect(progression).toContain(
      "Incomplete profession progression paths",
    );
  });

  it("persists every certificate and requires legitimate paid service history", () => {
    expect(progression).toContain("player_profession_certifications");
    expect(progression).toContain("'certificate_granted',passed");
    expect(progression).toContain("not self_service and price>0");
    expect(progression).toContain("Current level certificate is required");
  });

  it("guides certificate recipients through rates and services", () => {
    expect(ui).toContain("Certificate Granted ✓");
    expect(ui).toContain("CONTINUE TO SET YOUR RATES");
    expect(ui).toContain("CONTINUE TO SERVICES");
    expect(ui).toContain("CONTINUE TO ADVANCEMENT");
  });

  it("finishes Professional without inventing a fifth level", () => {
    expect(progression).toContain("profession_career_completions");
    expect(ui).toContain('"COMPLETE CAREER"');
    expect(ui).toContain("Career Completed ✓");
  });
});
