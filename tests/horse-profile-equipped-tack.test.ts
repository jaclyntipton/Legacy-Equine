import{readFileSync}from"node:fs";import{describe,expect,it}from"vitest";
const strip=readFileSync(new URL("../app/equipped-tack-strip.tsx",import.meta.url),"utf8"),profile=readFileSync(new URL("../app/horse-profile.tsx",import.meta.url),"utf8"),sql=readFileSync(new URL("../supabase/migrations/202609180009_horse_profile_equipped_tack.sql",import.meta.url),"utf8");
describe("Horse Profile equipped tack strip",()=>{
 it("reads the authoritative equipped item and bonus records",()=>{expect(sql).toContain("from horse_equipment e");expect(sql).toContain("join player_store_items i");expect(sql).toContain("coalesce(i.custom_tack_bonuses,p.tack_bonuses");expect(strip).toContain('rpc("get_horse_equipped_tack"')});
 it("shows four current slots and a future Shoes slot",()=>{for(const slot of ["bridle","saddle","saddle_pad","leg_protection","shoes"])expect(strip).toContain(`id:"${slot}"`);expect(profile).toContain("<EquippedTackStrip")});
 it("shows custom maker provenance and Effective Stats wording",()=>{expect(strip).toContain("maker_brand_code");expect(strip).toContain("maker_stable_name");expect(strip).toContain("Effective Stats only")});
 it("uses the existing Tack Room and unequip paths",()=>{expect(strip).toContain('rpc("unequip_tack"');expect(strip).toContain("onClick={openTackRoom}");expect(strip).toContain("UNEQUIP");expect(strip).toContain("CHANGE")});
});
