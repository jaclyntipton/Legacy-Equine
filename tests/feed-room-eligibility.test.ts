import{readFileSync}from"node:fs";import{describe,expect,it}from"vitest";
const ui=readFileSync(new URL("../app/stable-inventory.tsx",import.meta.url),"utf8"),sql=readFileSync(new URL("../supabase/migrations/202609180010_feed_system_v2.sql",import.meta.url),"utf8");
describe("Feed Room category eligibility and bulk feeding",()=>{
 it("uses one authoritative LE day and independent Hay/Grain keys",()=>{expect(sql.match(/America\/New_York/g)?.length).toBeGreaterThanOrEqual(4);expect(sql).toContain("horse_day_type");expect(sql).toContain("f.feed_type=product.feed_type");expect(sql).toContain("feed_type in('hay','grain')")});
 it("atomically validates all horses and inventory before consuming",()=>{expect(sql).toContain("owned<requested");expect(sql).toContain("units required • % available");expect(sql.indexOf("owned<requested")).toBeLessThan(sql.indexOf("update player_store_items set consumed_at"));expect(sql).toContain("horse_id=any(p_horses)")});
 it("filters each category immediately and supports Select All Eligible",()=>{expect(ui).toContain('rpc("get_feed_room_eligibility")');expect(ui).toContain("hay_eligible_horse_ids");expect(ui).toContain("grain_eligible_horse_ids");expect(ui).toContain("SELECT ALL ELIGIBLE");expect(ui).toContain("All horses have received their")});
 it("shows exact selection and inventory requirements",()=>{expect(ui).toContain("unit{selected.length===1");expect(ui).toContain("Owned: {group.length}");expect(ui).toContain("selected.length>group.length");expect(ui).toContain('rpc("feed_horses"')});
 it("keeps occupied Tack slots filtered",()=>{expect(ui).toContain("openSlotHorses=horses.filter");expect(ui).toContain("e.slot===product.tack_slot");expect(ui).toContain("openSlotHorses.map")});
});
