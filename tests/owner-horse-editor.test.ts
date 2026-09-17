import{describe,expect,it}from"vitest";
import fs from"node:fs";
const sql=fs.readFileSync("supabase/migrations/202609160002_owner_complete_horse_editor.sql","utf8");
const persistenceFix=fs.readFileSync("supabase/migrations/202609170010_fix_owner_horse_color_override.sql","utf8");
const monietCorrection=fs.readFileSync("supabase/migrations/202609170011_apply_moniet_grey_owner_override.sql","utf8");
const postCommitVerification=fs.readFileSync("supabase/migrations/202609170012_verify_owner_horse_override_persistence.sql","utf8");
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
describe("Owner Horse Editor persistence correction",()=>{
 it("converts a Grey request into the dominant Gray locus without replacing the base genotype",()=>{expect(persistenceFix).toContain("return jsonb_set(result,'{Gray}'");expect(persistenceFix).toContain("Extension/Agouti and every other locus intact")});
 it("derives and verifies the authoritative phenotype before the transaction can audit success",()=>{expect(persistenceFix).toContain("owner_edit_horse_core_20260917");expect(persistenceFix).toContain("result.color not like 'Gray (% base)'");expect(persistenceFix).toContain("raise exception 'The requested gray phenotype did not persist'")});
 it("continues to support another Owner field through the existing authoritative mutation",()=>{expect(sql).toContain("sex=case when p_changes?'sex'");expect(sql).toContain("returning * into new_h")});
 it("applies and verifies the authorized Moniet correction before recording success",()=>{expect(monietCorrection).toContain("set genetics=public.owner_color_override_genetics(h.genetics,'Grey')");expect(monietCorrection.indexOf("failed authoritative verification")).toBeLessThan(monietCorrection.indexOf("insert into public.horse_edit_audit"));expect(monietCorrection).toContain("'Owner-requested Bay to Grey correction','success'")});
 it("re-reads the committed horse and matching audit in a later migration",()=>{expect(postCommitVerification).toContain("persisted.visual_phenotype->>'color'<>persisted.color");expect(postCommitVerification).toContain("a.new_values->>'color'=persisted.color")});
});
