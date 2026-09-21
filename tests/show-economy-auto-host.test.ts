import fs from"node:fs";import path from"node:path";import{describe,expect,it}from"vitest";
const root=process.cwd(),migration=fs.readFileSync(path.join(root,"supabase/migrations/202609210001_auto_host_show_economy_and_zero_payout_guard.sql"),"utf8"),admin=fs.readFileSync(path.join(root,"app/admin-shows.tsx"),"utf8");
describe("authoritative Auto Host Show economy",()=>{
 it("stores positive configurable tier defaults and resolves them in Auto Host",()=>{expect(migration).toContain("default_entry_fee bigint not null default 25");expect(migration).toContain("default_base_purse bigint not null default 200");expect(migration).toContain("from get_show_economy_defaults");expect(migration).not.toContain("c.use_show_defaults then 0")});
 it("reconciles only future entry-free Auto Host shows",()=>{expect(migration).toContain("not exists(select 1 from player_show_entries e where e.show_id=ps.id)");expect(migration).toContain("manual_review")});
 it("preserves the non-zero ledger constraint by guarding calculated payouts",()=>{expect(migration).toContain("if payout>0 then");expect(migration).not.toContain("drop constraint currency_ledger_amount_check")});
 it("shows fee and purse in Bulk Run and exposes economy balancing",()=>{expect(admin).toContain("LED entry ·");expect(admin).toContain("Show Economy Defaults");expect(admin).toContain("admin_save_show_economy_defaults")});
});
