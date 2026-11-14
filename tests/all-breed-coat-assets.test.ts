import{readdirSync,readFileSync}from"node:fs";
import{describe,expect,it}from"vitest";

const root=new URL("../public/horse-visuals/coat-layers/",import.meta.url),migration=readFileSync(new URL("../supabase/migrations/202611130015_all_breed_deterministic_coats.sql",import.meta.url),"utf8");
describe("all supplied deterministic horse coats",()=>{
 it("ships all fifteen masters and 1,587 approved layers",()=>{const masters=readdirSync(root).filter(name=>readdirSync(new URL(`${name}/`,root)).includes("manifest.json")),layers=masters.reduce((total,name)=>total+readdirSync(new URL(`${name}/layers/`,root)).filter(file=>file.endsWith(".svg")).length,0);expect(masters).toHaveLength(15);expect(layers).toBe(1587)});
 it("uses one universal foal body for every breed and sex",()=>{expect(migration).toContain("asset_key='qh_foal_vector_master_01'");expect(migration).toContain("stage='foal'")});
 it("maps mature stock breeds through the Quarter Horse body rules",()=>expect(migration).toContain("horse_visual_master_breed(h.breed)"));
 it("keeps mare, stallion, and gelding-compatible mature selection",()=>{expect(migration).toContain("h.sex='Gelding'");expect(migration).toContain("a.sex=case")});
});
