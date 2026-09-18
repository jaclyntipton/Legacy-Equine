import{describe,expect,it}from"vitest";
import fs from"node:fs";
const ui=fs.readFileSync("app/professions.tsx","utf8");
const guard=fs.readFileSync("supabase/migrations/202609170031_authoritative_profession_persistence_guards.sql","utf8");
const publicProjection=fs.readFileSync("supabase/migrations/202609170026_publish_certified_professional_services.sql","utf8");
describe("server-authoritative Profession progression",()=>{
 it("exits QA simulation before any normal gameplay action",()=>{expect(ui).toContain('`/professions/${career.id}`');expect(ui).toContain("setCareer({ id: career.id, qa: false })");expect(ui).toContain("Normal Gameplay active")});
 it("prevents a later write from reducing a permanent level",()=>{expect(guard).toContain("new.certification_level<old.certification_level");expect(guard).toContain("Permanent certification progress cannot be reduced")});
 it("syncs every permanent certificate into its career row",()=>{expect(guard).toContain("sync_profession_certificate_to_career");expect(guard).toContain("greatest(certification_level,new.level)")});
 it("uses one authoritative projection for Market, Profile, and Stable",()=>{expect(publicProjection).toContain("public.get_public_professional_services(s.id)");expect(publicProjection).toContain("public.get_public_professional_services(p_stable)");expect(publicProjection).toContain("from player_service_offerings o")});
 it("protects all four data-driven professions",()=>{for(const id of ["farrier","veterinarian","trainer","massage"])expect(fs.readFileSync("supabase/migrations/202609150030_professional_services.sql","utf8")).toContain(`('${id}'`) });
});
