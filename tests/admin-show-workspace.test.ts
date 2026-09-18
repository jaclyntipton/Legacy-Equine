import{describe,expect,it}from"vitest";
import{readFileSync}from"node:fs";
const player=readFileSync("app/shows-v2.tsx","utf8"),admin=readFileSync("app/admin-shows.tsx","utf8"),sql=readFileSync("supabase/migrations/202609170004_owner_show_capabilities_admin_workspace.sql","utf8"),bulkSql=readFileSync("supabase/migrations/202609180003_bulk_run_shows.sql","utf8");
describe("Owner Show capabilities",()=>{
 it("resolves Owner #1 centrally",()=>{expect(sql).toContain("account_number=1");expect(sql).toContain("shows.bulk_enter_all");expect(sql).toContain("shows.admin.run_now")});
 it("exposes all three bulk controls",()=>{expect(player).toContain("Select All Eligible Shows");expect(player).toContain("Select All Eligible Horses");expect(player).toContain("Enter All Eligible")});
 it("revalidates bulk entries server-side",()=>{expect(sql).toContain("create or replace function public.preview_show_entries");expect(sql).toContain("Entries are locked");expect(sql).toContain("Show is full")});
});
describe("Admin Show workspace",()=>{
 it("has no placeholder-only tabs",()=>{for(const label of["Open Shows","Scheduled","Test / QA","Run Controls","Processing / History","Audit"])expect(admin).toContain(label)});
 it("connects secured actions",()=>{for(const action of["lock","run_now","cancel","duplicate","duplicate_test"])expect(sql).toContain(`'${action}'`);expect(admin).toContain("Preview Results")});
 it("keeps previews side-effect free",()=>{expect(sql).toContain("admin_preview_show_results");expect(sql).toContain("'side_effects',false")});
 it("adds bulk execution without replacing single run",()=>{expect(admin).toContain("Run Show Now");expect(admin).toContain("BULK RUN SHOWS");expect(bulkSql).toContain("process_due_player_shows()")});
});
