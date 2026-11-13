import{readFileSync}from"node:fs";
import{describe,expect,it}from"vitest";

const sql=readFileSync(new URL("../supabase/migrations/202611130006_stock_breed_visual_body_mapping.sql",import.meta.url),"utf8");

describe("stock-breed visual body mapping",()=>{
 it("maps Quarter Horse, Paint Horse and Appaloosa to Quarter Horse masters",()=>{
  expect(sql).toContain("('Quarter Horse','Quarter Horse'");
  expect(sql).toContain("('American Paint Horse','Quarter Horse'");
  expect(sql).toContain("('Paint Horse','Quarter Horse'");
  expect(sql).toContain("('Appaloosa','Quarter Horse'");
 });
 it("resolves only the conformation master breed",()=>{
  expect(sql).toContain("horse_visual_master_breed(h.breed)");
  expect(sql).toContain("a.breed=required_master_breed");
  expect(sql).toContain("a.body_template_key=h.visual_template_id");
 });
 it("keeps the exact foal/mature and sex selection rules",()=>{
  expect(sql).toContain("a.life_stage in(required_stage,'any')");
  expect(sql).toContain("a.sex is null or a.sex=h.sex");
 });
 it("does not mutate or duplicate any artwork",()=>{
  expect(sql).not.toContain("insert into public.horse_visual_assets");
  expect(sql).not.toContain("update public.horse_visual_assets");
  expect(sql).not.toContain("/horse-visuals/vector-masters/");
 });
 it("shows inherited master coverage in the owner matrix",()=>{
  expect(sql).toContain("public.horse_visual_master_breed(b.name)as master_breed");
  expect(sql).toContain("m.breed=e.master_breed");
 });
});
