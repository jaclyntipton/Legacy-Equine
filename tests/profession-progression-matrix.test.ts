import { describe, expect, it } from "vitest";
import fs from "node:fs";

const progression = fs.readFileSync(
  "supabase/migrations/202609170023_complete_profession_level_progression.sql",
  "utf8",
);
const exactStateMachine = fs.readFileSync(
  "supabase/migrations/202609170024_exact_profession_state_machine.sql",
  "utf8",
);
const enrollmentStatus = fs.readFileSync(
  "supabase/migrations/202609170025_authoritative_profession_enrollment_status.sql",
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
        expect(exactStateMachine).toContain(
          "provider_level=target_level and status='completed'",
        );
        expect(exactStateMachine).toContain(
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

  it("hard-locks advancement behind rates and paid level-specific client services", () => {
    expect(exactStateMachine).toContain(
      "Set every authorized service rate before advancing",
    );
    expect(exactStateMachine).toContain(
      "Complete % legitimate paid client services before advancing",
    );
    expect(exactStateMachine).toContain(
      "legitimate_profession_service_count(auth.uid(),target_profession,pp.certification_level)",
    );
    expect(ui).toContain("serviceCredit < requiredServices");
    expect(ui).toContain("🔒 Advancement");
  });

  it("persists mandatory rate setup in the existing offering architecture", () => {
    expect(exactStateMachine).toContain("profession_rate_setups");
    expect(exactStateMachine).toContain("player_service_offerings");
    expect(exactStateMachine).toContain("required.minimum_level<=lvl");
    expect(ui).toContain("SAVE & START ACCEPTING CLIENTS");
    expect(ui).toContain("p.rates_configured");
  });

  it("exposes the exact shared server state machine", () => {
    for (const state of [
      "STUDY_REQUIRED",
      "TEST_AVAILABLE",
      "RATES_REQUIRED",
      "SERVICE_EXPERIENCE_REQUIRED",
      "ADVANCEMENT_AVAILABLE",
      "NEXT_LEVEL_STUDY",
      "PROFESSIONAL_CERTIFIED",
    ])
      expect(exactStateMachine).toContain(state);
  });

  it("resolves enrollment independently from certification level", () => {
    expect(enrollmentStatus).toContain(
      "'enrolled',pp.stable_id is not null",
    );
    expect(enrollmentStatus).toContain(
      "when pp.certification_level=0 and sp.completed_at is null then'Enrolled · Basic Study'",
    );
    expect(enrollmentStatus).toContain("'status_label',case");
    expect(ui).toContain("{p.status_label}");
    expect(ui).toContain("{!p.enrolled ? (");
    expect(ui).toContain("!profession.enrolled");
    expect(ui).not.toContain("{p.level === 0 ? (");
  });

  it("keeps card actions aligned with authoritative career state", () => {
    expect(ui).toContain('p.career_completed ? "VIEW CAREER" : "CONTINUE CAREER"');
    expect(ui).toContain("ENROLL AS NORMAL PLAYER");
    expect(enrollmentStatus).toContain("when pp.stable_id is null then'Not Enrolled'");
    expect(enrollmentStatus).toContain("then'Ready to Advance'");
    expect(enrollmentStatus).toContain("then nextcl.name||' Study'");
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
