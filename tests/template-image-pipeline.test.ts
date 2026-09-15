import{readFileSync}from"node:fs";
import{describe,expect,it}from"vitest";
const worker=readFileSync(new URL("../app/api/store-horse-images/generate/route.ts",import.meta.url),"utf8");
const migration=readFileSync(new URL("../supabase/migrations/202609150052_approved_horse_image_templates.sql",import.meta.url),"utf8");
describe("approved horse image template pipeline",()=>{
 it("requires template pixels as image-to-image input",()=>{expect(worker).toContain("prompt:{images:[template]");expect(worker).not.toContain("prodia/flux-fast-schnell")});
 it("falls back instead of publishing failed anatomy",()=>expect(worker).toContain('finish(admin,job,fallback,"fallback"'));
 it("stores human approval and horse quality metadata",()=>{expect(migration).toContain("horse_image_templates");expect(migration).toContain("image_quality_status");expect(migration).toContain("approved_by")});
 it("preserves gameplay data during batch regeneration",()=>{const batch=migration.slice(migration.indexOf("admin_batch_regenerate_foundation_images"),migration.indexOf("create or replace function public.admin_regenerate_horse_image"));expect(batch).not.toMatch(/stats\s*=|genetics\s*=|owner_id\s*=|sire_id\s*=|dam_id\s*=/)});
});
