import{readFileSync}from"node:fs";
import{describe,expect,it}from"vitest";

const component=readFileSync(new URL("../app/contained-horse-artwork.tsx",import.meta.url),"utf8"),compositor=readFileSync(new URL("../lib/game/horse-coat-compositor.ts",import.meta.url),"utf8"),sql=readFileSync(new URL("../supabase/migrations/202611130014_live_twh_rmh_deterministic_coats.sql",import.meta.url),"utf8");
describe("live TWH and RMH deterministic coats",()=>{
 it("uses the approved isolated pigment and erase compositor",()=>{expect(compositor).toContain('compositing_group==="pigment"');expect(compositor).toContain('globalCompositeOperation="destination-out"');expect(compositor).toContain('globalCompositeOperation="multiply"');expect(compositor).toContain('compositing_group==="top"')});
 it("loads recipes through the shared horse renderer",()=>{expect(component).toContain('get_horse_visual_recipe');expect(component).toContain('paintCoat');expect(component).toContain('<canvas')});
 it("keeps owner-selected custom art and the universal foal stage ahead of mature composites",()=>{expect(component).toContain('!recipe.custom_url');expect(component).toContain('recipe.life_stage==="mature"');expect(sql).toContain("stage='mature'")});
 it("assigns only approved exact-breed, sex-appropriate masters",()=>{expect(sql).toContain("status='approved'");expect(sql).toContain('a.breed=h.breed');expect(sql).toContain("h.sex='Gelding'")});
 it("ships every approved layer",()=>{expect(compositor).toContain('/horse-visuals/coat-layers/');});
});
