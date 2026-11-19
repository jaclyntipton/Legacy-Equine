import{describe,expect,it}from"vitest";
import{readFileSync}from"node:fs";

const page=readFileSync("app/page.tsx","utf8"),migration=readFileSync("supabase/migrations/202611180004_secondary_general_barn.sql","utf8"),bulk=readFileSync("supabase/migrations/202611180005_bulk_horse_barn_moves.sql","utf8"),ownerOnly=readFileSync("supabase/migrations/202611190001_owner_only_secondary_barns.sql","utf8");

describe("Training and private General Barn",()=>{
 it("keeps barn placement horse-specific without changing ownership or capacity",()=>{expect(migration).toContain("stable_barn text not null default 'training'");expect(migration).toContain("move_owned_horse_to_barn");expect(migration).not.toMatch(/update stables set|stable_capacity_allocations/)});
 it("provides both owner barn views and move controls",()=>{for(const label of["Training Barn","General Barn","Move only this horse to"])expect(page).toContain(label);expect(page).toContain('stable_barn: "training" | "general"')});
 it("does not inherit the global full-height navigation layout",()=>{expect(page).toContain('className="barnswitcher" role="tablist"');expect(page).not.toContain('<nav className="barnswitcher"')});
 it("retains every owned horse for gameplay while filtering only the Stable display",()=>{expect(page).toContain("horses={ownedHorses}");expect(page).toContain("horses={barnHorses}");expect(page).toContain("const barnHorses=")});
 it("publishes only Training Barn horses",()=>{expect(migration.match(/h\.stable_barn='training'/g)?.length).toBeGreaterThanOrEqual(4);expect(migration).toContain('create policy "training barn horses are public"');expect(page).toContain("Horse Profile unavailable")});
 it("moves multiple selected owned horses atomically",()=>{expect(page).toContain("Select All Shown");expect(page).toContain("move_owned_horses_to_barn");expect(bulk).toContain("for update");expect(bulk).toContain("moved<>requested");expect(bulk).toContain("Every selected horse must be an active horse you own")});
 it("limits the secondary barn experience to Owner Account #1",()=>{expect(page).toContain("const hasPrivateBarns=stable?.account_number===1");expect(page).toContain("hasPrivateBarns&&<><div className=\"barnswitcher\"");expect(ownerOnly.match(/account_number=1/g)?.length).toBeGreaterThanOrEqual(2);expect(ownerOnly).toContain("s.account_number<>1");expect(ownerOnly).toContain("set stable_barn='training'")});
});
