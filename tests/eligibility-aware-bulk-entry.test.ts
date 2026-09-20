import{describe,expect,it}from"vitest";
import{readFileSync}from"node:fs";
const ui=readFileSync("app/shows-v2.tsx","utf8"),sql=readFileSync("supabase/migrations/202609200001_eligibility_aware_bulk_show_entries.sql","utf8");
describe("eligibility-aware bulk Show entry",()=>{
 it("builds pairs server-side through the authoritative preview",()=>{expect(sql).toContain("v_preview:=preview_show_entries(v_pairs)");expect(ui).toContain('rpc("preview_eligible_show_entries"');expect(ui).not.toContain("const allPairs=")});
 it("returns only eligible pairs and compact exclusion counts",()=>{for(const key of ["entries_to_create","eligible_show_count","already_entered","ineligible","excluded_by_reason"])expect(sql).toContain(`'${key}'`);expect(sql).toContain("v_preview-'skipped'")});
 it("charges only selected eligible entries",()=>{expect(ui).toContain("preview?.eligible.filter");expect(ui).toContain("chosenEntries.reduce");expect(ui).toContain("ENTRIES TO CREATE");expect(ui).not.toContain("<small>SKIPPED</small>")});
});
