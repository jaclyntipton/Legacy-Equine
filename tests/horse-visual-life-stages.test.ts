import{readFileSync}from"node:fs";
import{describe,expect,it}from"vitest";

const migration=readFileSync(new URL("../supabase/migrations/202611130002_foal_mature_visual_stages.sql",import.meta.url),"utf8");

describe("foal and mature deterministic visual stages",()=>{
 it("uses exactly the approved two-stage model",()=>{
  expect(migration).toContain("life_stage in('foal','mature','any')");
  expect(migration).toContain("horse_game_age(p_birth_date)<2");
  expect(migration).not.toContain("yearling");
  expect(migration).not.toContain("senior");
 });
 it("keeps the neutral fallback independent of breed, sex, and phenotype",()=>{
  expect(migration).toContain("set life_stage='any'");
  expect(migration).toContain("'/generic-horse-placeholder.png'");
  expect(migration).toContain("chosen.breed='*'");
 });
 it("selects an exact stage before breed and sex specificity",()=>{
  expect(migration).toContain("a.life_stage in(required_stage,'any')");
  expect(migration).toContain("(a.life_stage=required_stage)desc");
  expect(migration).toContain("(a.breed=h.breed)desc");
  expect(migration).toContain("(a.sex=h.sex)desc");
 });
 it("does not mutate the protected Quarter Horse masters",()=>{
  expect(migration).not.toContain("set life_stage='mature'");
  expect(migration).toContain("where not immutable_source");
  expect(migration).toContain("and not immutable_source");
  expect(migration).not.toContain("update public.horse_visual_assets\n+ set image_url");
 });
 it("refuses to describe incomplete artwork as display-ready",()=>{
  expect(migration).toContain("c.production_count>0 and c.incomplete_count=0");
  expect(migration).toContain("admin_visual_stage_coverage");
 });
});
