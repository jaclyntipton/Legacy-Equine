import{describe,expect,it}from"vitest";import{readFileSync}from"node:fs";
const migration=readFileSync(new URL("../supabase/migrations/202609150054_deterministic_horse_visual_library.sql",import.meta.url),"utf8"),route=readFileSync(new URL("../app/api/store-horse-images/generate/route.ts",import.meta.url),"utf8"),page=readFileSync(new URL("../app/page.tsx",import.meta.url),"utf8");
describe("deterministic horse visual architecture",()=>{
 it("permanently assigns template identity and a phenotype fingerprint",()=>{expect(migration).toContain("visual_template_id text");expect(migration).toContain("visual_fingerprint");expect(migration).toContain("md5(concat_ws");expect(migration).not.toContain("order by random()")});
 it("supports every approved compositing layer family",()=>{for(const kind of ["body_template","base_coat","modifier","pattern","face_marking","leg_marking","mane_tail"])expect(migration).toContain(kind)});
 it("keeps custom and standard artwork independent with custom priority",()=>{expect(migration).toContain("player_custom_image_url");expect(migration).toContain("le_visual_url");expect(migration).toContain("coalesce(nullif(player_custom_image_url,''),")});
 it("retires production AI work and API spending",()=>{expect(route).toContain("status:410");expect(route).not.toMatch(/generateImage|generateText|imageModel/);expect(page).not.toContain('fetch("/api/store-horse-images/generate"');expect(migration).toContain("Production AI generation permanently disabled")});
 it("keeps deterministic master assignment independent of the retired generic fallback",()=>{expect(migration).toContain("visual_template_id");expect(migration).toContain("visual_fingerprint")});
});
