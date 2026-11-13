import{readFileSync}from"node:fs";
import{describe,expect,it}from"vitest";

const sql=readFileSync(new URL("../supabase/migrations/202611130010_universal_foal_visual_master.sql",import.meta.url),"utf8");

describe("universal foal visual master",()=>{
 it("maps every foal breed to the Quarter Horse body",()=>expect(sql).toContain("when p_life_stage='foal'then'Quarter Horse'"));
 it("keeps mature breed mappings",()=>expect(sql).toContain("horse_visual_body_breed_mappings"));
 it("uses a sex-neutral foal master for mares and stallions",()=>{expect(sql).toContain("a.sex is null or a.sex=h.sex");expect(sql).toContain("m.sex is null or m.sex=e.sex")});
 it("shows the inherited foal master in Owner coverage",()=>expect(sql).toContain("horse_visual_master_breed(b.name,s.life_stage)"));
 it("does not create or alter artwork",()=>{expect(sql).not.toContain("insert into public.horse_visual_assets");expect(sql).not.toContain("update public.horse_visual_assets")});
});
