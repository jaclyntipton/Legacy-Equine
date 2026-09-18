import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const sql = readFileSync(
  "supabase/migrations/202609180019_profession_certification_cooldown_qa_bypass.sql",
  "utf8",
);
const ui = readFileSync("app/professions.tsx", "utf8");
const admin = readFileSync("app/admin-professions.tsx", "utf8");
const page = readFileSync("app/page.tsx", "utf8");

describe("Profession certification cooldown QA bypass", () => {
  it("requires the granular server-side permission", () => {
    expect(sql).toContain(
      "has_admin_permission('professions.qa_bypass_certification_cooldown')",
    );
    expect(sql).toContain(
      "Profession certification cooldown QA permission required",
    );
    expect(page).toContain('"professions.qa_bypass_certification_cooldown"');
  });

  it("preserves the failed attempt and bypasses only that attempt's wait", () => {
    expect(sql).toContain("failed_attempt_id uuid not null unique references public.certification_attempts(id)");
    expect(sql).toContain("attempt.passed then raise exception");
    expect(sql).toContain("'original_result','FAILED'");
    expect(sql).not.toMatch(/delete from certification_attempts|update certification_attempts/);
  });

  it("does not grant certification or mutate progression from the bypass", () => {
    const bypass = sql.slice(
      sql.indexOf("admin_bypass_profession_certification_cooldown"),
      sql.indexOf("create or replace function public.take_certification_test"),
    );
    expect(bypass).not.toMatch(/player_profession_certifications|update player_professions|currency_ledger|horse_service_records/);
  });

  it("keeps the normal cooldown guard and consumes the bypass by attempt id", () => {
    expect(sql).toContain("and not cooldown_bypassed then raise exception 'Certification retest cooldown is active'");
    expect(sql).toContain("b.failed_attempt_id=latest.id");
  });

  it("shows the Owner QA control and configurable normal cooldown", () => {
    expect(ui).toContain("Certification Cooldown Active");
    expect(ui).toContain("BYPASS COOLDOWN FOR QA");
    expect(ui).toContain("Available again:");
    expect(admin).toContain("Certification Retry Cooldown (minutes)");
    expect(admin).toContain("admin_update_profession_retry_cooldown");
  });
});
