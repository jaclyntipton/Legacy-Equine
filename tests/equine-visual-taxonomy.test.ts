import{describe,expect,it}from"vitest";
import fs from"node:fs";
const sql=fs.readFileSync("supabase/migrations/202609160003_equine_visual_taxonomy_and_requirements.sql","utf8");
describe("reference-led equine visual taxonomy",()=>{
 it("models every supplied face category and keeps Medicine Hat out of facial markings",()=>{for(const key of["snip_01","faint_01","faint_star_01","star_01","half_star_01","strip_01","broken_strip_01","star_strip_01","blaze_01","blaze_snip_01","irregular_blaze_01","bald_face_01"])expect(sql).toContain(`'face_marking','${key}'`);expect(sql).toContain("'pinto_pattern','medicine_hat_01'");expect(sql).not.toContain("'face_marking','medicine_hat")});
 it("models all approved leg heights independently for four anatomical limbs",()=>{for(const key of["coronet_01","white_heel_01","half_pastern_01","pastern_01","ankle_01","half_sock_01","full_sock_01","high_sock_01"])expect(sql).toContain(`'leg_marking','${key}'`);expect(sql).toContain("(values('LF'),('RF'),('LH'),('RH'))")});
 it("maps anatomical limbs explicitly and never uses screen position",()=>{expect(sql).toContain("when'LF'then coalesce(p_markings->>'left_front'");expect(sql).toContain("when'RF'then coalesce(p_markings->>'right_front'");expect(sql).toContain("when'LH'then coalesce(p_markings->>'left_hind'");expect(sql).toContain("when'RH'then coalesce(p_markings->>'right_hind'");expect(sql).not.toMatch(/screen_(left|right)/i)});
 it("derives grulla from Dun on a black base",()=>{expect(sql).toContain("when base='bay'then'bay_dun'else'grulla'");expect(sql).toContain("'dun','grulla'")});
 it("keeps age-dependent gray, true roan, dapple and leopard complex distinct",()=>{expect(sql).toContain("gray_stage:=case when age_years<3");expect(sql).toContain("'roan'");expect(sql).toContain("coalesce(modifiers->>'dapple','none')");expect(sql).toContain("'leopard_complex'")});
 it("requires an exact body-master registration before production",()=>{expect(sql).toContain("body_template_key=r.body_template_key");expect(sql).toContain("Only an approved active asset may enter production");expect(sql).toContain("status text not null default 'missing'")});
});
