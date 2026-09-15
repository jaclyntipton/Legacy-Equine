import{readFileSync}from"node:fs";import{describe,expect,it}from"vitest";
const worker=readFileSync(new URL("../app/api/store-horse-images/generate/route.ts",import.meta.url),"utf8"),migration=readFileSync(new URL("../supabase/migrations/202609150054_deterministic_horse_visual_library.sql",import.meta.url),"utf8");
describe("approved deterministic horse visual pipeline",()=>{
 it("forbids production image-model input",()=>{expect(worker).toContain("status:410");expect(worker).not.toMatch(/generateImage|imageModel|prodia/)});
 it("falls back instead of inventing incomplete anatomy",()=>expect(migration).toContain("foundation_generic_01"));
 it("stores human approval and horse quality metadata",()=>{expect(migration).toContain("horse_visual_assets");expect(migration).toContain("image_quality_status");expect(migration).toContain("approved_by")});
 it("preserves gameplay data during visual reassignment",()=>{const assign=migration.slice(migration.indexOf("assign_horse_visual"),migration.indexOf("-- Preserve recognizable"));expect(assign).not.toMatch(/stats\s*=|genetics\s*=|owner_id\s*=|sire_id\s*=|dam_id\s*=/)});
});
