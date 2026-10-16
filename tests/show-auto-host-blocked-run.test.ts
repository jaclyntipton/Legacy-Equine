import{readFileSync}from"node:fs";
import{describe,expect,it}from"vitest";

const ui=readFileSync("app/show-auto-host.tsx","utf8");
const migration=readFileSync("supabase/migrations/202610160001_auto_host_blocked_run_semantics_and_catchup.sql","utf8");

describe("Auto Host blocked-run semantics",()=>{
  it("reports funding blocks instead of presenting combinations as skipped",()=>{
    expect(ui).toContain('result?.status==="insufficient_show_fund"');
    expect(ui).toContain("No Shows were skipped");
    expect(ui).toContain("Funding blocked");
    expect(migration).toContain("new.shows_skipped:=0");
    expect(migration).toContain("blocked_combinations");
  });
});
