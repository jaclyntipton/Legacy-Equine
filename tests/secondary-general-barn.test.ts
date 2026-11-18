import{describe,expect,it}from"vitest";
import{readFileSync}from"node:fs";

const page=readFileSync("app/page.tsx","utf8"),migration=readFileSync("supabase/migrations/202611180004_secondary_general_barn.sql","utf8");

describe("Training and private General Barn",()=>{
 it("keeps barn placement horse-specific without changing ownership or capacity",()=>{expect(migration).toContain("stable_barn text not null default 'training'");expect(migration).toContain("move_owned_horse_to_barn");expect(migration).not.toMatch(/update stables set|stable_capacity_allocations/)});
 it("provides both owner barn views and move controls",()=>{for(const label of["Training Barn","General Barn","Move to"])expect(page).toContain(label);expect(page).toContain('stable_barn: "training" | "general"')});
 it("retains every owned horse for gameplay while filtering only the Stable display",()=>{expect(page).toContain("horses={ownedHorses}");expect(page).toContain("horses={barnHorses}");expect(page).toContain("const barnHorses=")});
 it("publishes only Training Barn horses",()=>{expect(migration.match(/h\.stable_barn='training'/g)?.length).toBeGreaterThanOrEqual(4);expect(migration).toContain('create policy "training barn horses are public"');expect(page).toContain("Horse Profile unavailable")});
});
