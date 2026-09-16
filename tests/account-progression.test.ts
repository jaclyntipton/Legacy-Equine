import{readFileSync}from"node:fs";
import{describe,expect,it}from"vitest";
const sql=readFileSync(new URL("../supabase/migrations/202609160004_account_progression_allowances_bulk_shows.sql",import.meta.url),"utf8");

describe("Account progression migration",()=>{
 it("keeps Account XP separate from Horse Career Points",()=>{expect(sql).toContain("stables add column if not exists account_xp");expect(sql).toContain("horses.career_points")});
 it("contains all fifty cumulative level thresholds",()=>{const tuples=[...sql.matchAll(/\((\d+),(\d+),(\d+),(\d+),(?:true|false)/g)].slice(0,50);expect(tuples).toHaveLength(50);expect(tuples[0].slice(1,3)).toEqual(["1","0"]);expect(tuples[49].slice(1,3)).toEqual(["50","18135"])});
 it("uses Friday Eastern week boundaries",()=>{expect(sql).toContain("America/New_York");expect(sql).toContain("extract(dow");expect(sql).toContain("+2)%7")});
 it("makes XP idempotent",()=>{expect(sql).toContain("unique(stable_id,source_type,source_id,event_key)");expect(sql).toContain("on conflict do nothing")});
 it("awards configured show and hosting XP",()=>{for(const token of["xp_entry","xp_first","xp_second","xp_third","xp_host_complete","xp_host_5_accounts","xp_host_10_accounts","xp_host_20_accounts"])expect(sql).toContain(token)});
 it("keeps QA results out of progression",()=>{expect(sql).toContain("not coalesce(e.is_admin_qa,false)");expect(sql).toContain("xp_eligible")});
 it("claims allowances transactionally through the currency ledger",()=>{expect(sql).toContain("collect_weekly_allowances");expect(sql).toContain("Weekly Stable Allowance");expect(sql).toContain("for update loop")});
 it("validates bulk shows before inserting and bulk entry through the locked entry RPC",()=>{expect(sql).toContain("bulk_create_player_shows");expect(sql).toContain("preview_bulk_show_entries");expect(sql).toContain("perform enter_player_show")});
});
