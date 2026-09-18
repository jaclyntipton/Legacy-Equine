import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const pause = readFileSync(
  "supabase/migrations/202609180021_pause_auto_host_for_result_repair.sql",
  "utf8",
);
const fix = readFileSync(
  "supabase/migrations/202609180022_fix_auto_host_ambiguous_result_and_verify.sql",
  "utf8",
);

describe("Auto Host ambiguous result production repair", () => {
  it("captures the exact schedule state before the safety pause", () => {
    expect(pause).toContain("was_enabled");
    expect(pause).toContain("was_daily_enabled");
    expect(pause).toContain("update public.show_auto_host_config set enabled=false");
  });

  it("removes the PL/pgSQL result collision", () => {
    expect(fix).toContain("v_result jsonb");
    expect(fix).toContain("result=v_result");
    expect(fix).not.toContain("result=result");
    expect(fix).toContain("select r.result into prior");
  });

  it("qualifies directly called orchestration queries", () => {
    expect(fix).toContain("from show_auto_host_runs as r");
    expect(fix).toContain("from player_shows as existing_show");
    expect(fix).toContain("from system_funds as sf");
    expect(fix).toContain("where r.id=run_id");
  });

  it("proves planning is side-effect free and Maintain-X is idempotent", () => {
    expect(fix).toContain("after_preview_count<>before_count");
    expect(fix).toContain("Production Auto Host is not in Maintain Target Availability mode");
    expect(fix).toContain("(second_run->>'created')::integer,0)<>0");
  });

  it("restores the preserved ON/daily configuration only after verification", () => {
    expect(fix.indexOf("second_run:=run_show_auto_host")).toBeLessThan(
      fix.indexOf("set enabled=saved.was_enabled"),
    );
    expect(fix).toContain("restored_at=now()");
  });
});
