import{readFileSync}from"node:fs";import{describe,expect,it}from"vitest";
const ui=readFileSync(new URL("../app/stable-inventory.tsx",import.meta.url),"utf8"),sql=readFileSync(new URL("../supabase/migrations/202609180008_feed_room_eligibility_and_bulk_feeding.sql",import.meta.url),"utf8");
describe("Feed Room eligibility and bulk feeding",()=>{
 it("uses one authoritative LE day across eligibility and feeding",()=>{expect(sql.match(/America\/New_York/g)?.length).toBeGreaterThanOrEqual(2);expect(sql).toContain("horse_feed_log f");expect(sql).toContain("f.le_day=today");expect(sql).toContain("unique horse/day constraint")});
 it("atomically validates all horses and inventory before consuming",()=>{expect(sql).toContain("owned<requested");expect(sql).toContain("units required • % available");expect(sql.indexOf("owned<requested")).toBeLessThan(sql.indexOf("update player_store_items set consumed_at"));expect(sql).toContain("horse_id=any(p_horses)")});
 it("removes fed horses from every product and supports select all",()=>{expect(ui).toContain('rpc("get_feed_room_eligibility")');expect(ui).toContain("setEligibleFeedIds(ids)");expect(ui).toContain("SELECT ALL ELIGIBLE");expect(ui).toContain("All horses have received their development feeding for this LE day.")});
 it("shows exact selection and inventory requirements",()=>{expect(ui).toContain("unit{selected.length===1");expect(ui).toContain("Owned: {group.length}");expect(ui).toContain("selected.length>group.length");expect(ui).toContain('rpc("feed_horses"')});
 it("filters occupied Tack slots in the same inventory update",()=>{expect(ui).toContain("openSlotHorses=horses.filter");expect(ui).toContain("e.slot===product.tack_slot");expect(ui).toContain("{openSlotHorses.map")});
});
