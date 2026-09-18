import{describe,expect,it}from"vitest";
import{readFileSync}from"node:fs";
const sql=readFileSync("supabase/migrations/202609180003_bulk_run_shows.sql","utf8"),fix=readFileSync("supabase/migrations/202609180006_fix_bulk_run_show_id.sql","utf8"),ui=readFileSync("app/admin-shows.tsx","utf8"),css=readFileSync("app/admin-bulk-shows.css","utf8"),runner=readFileSync("supabase/migrations/202609150045_expanded_show_system.sql","utf8");
describe("Owner/Admin bulk Show orchestration",()=>{
 it("grants Owner #1 the permanent delegable bulk capability",()=>{expect(sql).toContain("account_number=1");expect(sql).toContain("shows.admin.bulk_run");expect(sql).toContain("admin.shows.bulk_run")});
 it("uses the authoritative runner and leaves scheduler completion guards intact",()=>{expect(fix).toContain("perform process_due_player_shows()");expect(runner).toContain("status in('open','processing') and run_at<=now()");expect(runner).toContain("on conflict(entry_id) do nothing")});
 it("is retry-safe and isolates failures",()=>{expect(sql).toContain("request_key uuid not null unique");expect(sql).toContain("on conflict(request_key)do nothing");expect(sql).toContain("exception when others then reason:=sqlerrm")});
 it("keeps QA execution side-effect free",()=>{expect(fix).toContain("v_preview:=admin_preview_show_results(v_show.id)");expect(fix).toContain("'side_effects',not p_qa");expect(ui).toContain("zero gameplay/economic effects")});
 it("does not collide a show_id variable with SQL columns",()=>{expect(fix).not.toMatch(/declare[^$]*\bshow_id uuid/);expect(fix).toContain("pse.show_id=v_show.id");expect(fix).toContain("ps.id=v_show_id")});
 it("provides the simplified direct-run workflow",()=>{for(const label of["BULK RUN SHOWS","Search Shows","Discipline","Tier","Run date","SELECT ALL SHOWS","Shows Selected","SHOWS NOW","View Results"])expect(ui).toContain(label);for(const removed of["Select All Eligible","PREVIEW BULK RUN"])expect(ui).not.toContain(removed)});
 it("uses contained touch-friendly mobile controls",()=>{expect(css).toContain("max-height:350px;overflow:auto");expect(css).toContain("@media(max-width:700px)");expect(css).toContain("min-height:68px")});
});
