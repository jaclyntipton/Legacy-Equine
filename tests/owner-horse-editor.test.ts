import{describe,expect,it}from"vitest";
import fs from"node:fs";
const sql=fs.readFileSync("supabase/migrations/202609160002_owner_complete_horse_editor.sql","utf8");
describe("Owner complete horse editor security contract",()=>{
 it("requires Owner #1 or an explicit horse_editor permission",()=>{expect(sql).toContain("s.account_number=1");expect(sql).toContain("p.permission='horse_editor'");expect(sql).toContain("perform require_horse_editor()")});
 it("keeps ordinary admins separate from Horse Editor permission",()=>{expect(sql).toContain("Only Owner Account #1 can manage Horse Editor permission");expect(sql).not.toContain("and s.is_admin")});
 it("immutably audits old and new horse values",()=>{expect(sql).toContain("horse_edit_audit_immutable");expect(sql).toContain("old_values jsonb not null,new_values jsonb not null");expect(sql).toContain("to_jsonb(old_h),to_jsonb(new_h)")});
 it("supports uncapped birth and permanent development editing",()=>{expect(sql).toContain("p_changes?'stat_values'");expect(sql).toContain("new_birth:=jsonb_set");expect(sql).toContain("new_stats:=jsonb_set")});
 it("recalculates phenotype from genotype",()=>{expect(sql).toContain("genetic_color(p_changes->'genetics')");expect(sql).toContain("build_visual_phenotype")});
 it("keeps phenotype override independent",()=>{expect(sql).toContain("phenotype_override=case");expect(sql).not.toContain("genetics=phenotype_override")});
 it("rejects self-parentage and circular pedigrees",()=>{expect(sql).toContain("A horse cannot be its own parent");expect(sql).toContain("Pedigree change would create a circular ancestry")});
 it("records administrative transfers without fabricating a sale",()=>{expect(sql).toContain("'Administrative Transfer'");expect(sql).not.toContain("Marketplace Sale")});
 it("restricts Sanctuary restoration and show correction to Owner #1",()=>{expect(sql).toContain("Only Owner Account #1 may restore a Sanctuary horse");expect(sql).toContain("Only Owner Account #1 may correct completed show history")});
 it("preserves historical progeny and completed show rows in general edits",()=>{const generalEdit=sql.match(/create or replace function public\.owner_edit_horse[\s\S]*?\nend\$\$;/i)?.[0]??"";expect(generalEdit).not.toMatch(/delete from breeding_records/i);expect(generalEdit).not.toMatch(/delete from player_show_results/i)});
});
