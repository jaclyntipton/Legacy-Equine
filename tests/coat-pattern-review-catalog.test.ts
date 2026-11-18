import fs from"node:fs";
import path from"node:path";
import {describe,expect,it}from"vitest";

const root=process.cwd();
const component=fs.readFileSync(path.join(root,"app/coat-pattern-catalog.tsx"),"utf8");
const migration=fs.readFileSync(path.join(root,"supabase/migrations/202611170004_pattern_standard_review_catalog.sql"),"utf8");

describe("complete coat pattern approval catalog",()=>{
 it("lists every registered Paint and Appaloosa review standard",()=>{
  for(const label of["Tobiano","Frame Overo","Sabino","Sabino Roaning","Splashed White","Medicine Hat","Tovero","Dominant White","Blanket","Snowcap","Spotted Blanket","Leopard","Few Spot Leopard","Snowflake","Varnish Roan","Frost","Pintaloosa"])expect(component).toContain(`label:\"${label}\"`);
 });
 it("supports both registered sexes and persistent owner decisions",()=>{
  expect(component).toContain("qh_mare_master_01");expect(component).toContain("qh_stallion_master_01");expect(component).toContain("admin_list_pattern_standard_reviews");expect(component).toContain("admin_review_pattern_standard");
 });
 it("keeps review records protected and auditable",()=>{
  expect(migration).toContain("enable row level security");expect(migration).toContain("revoke all on public.horse_pattern_standard_reviews from anon,authenticated");expect(migration).toContain("public.is_owner_account()");expect(migration).not.toContain("require_owner()");expect(migration).toContain("insert into admin_audit_log");
 });
});
