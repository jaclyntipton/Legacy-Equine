import{readFileSync}from"node:fs";
import{describe,expect,it}from"vitest";

const component=readFileSync(new URL("../app/visual-stage-coverage.tsx",import.meta.url),"utf8");
const page=readFileSync(new URL("../app/page.tsx",import.meta.url),"utf8");

describe("Owner foal and mature visual coverage",()=>{
 it("is reachable from the existing Admin Horse Visual Library path",()=>{
  expect(page).toContain('import { VisualStageCoverage } from "@/app/visual-stage-coverage"');
  expect(page).toContain('<VisualStageCoverage notify={setMessage}/>');
 });
 it("reports missing and incomplete artwork without activating it",()=>{
  expect(component).toContain('admin_visual_stage_coverage');
  expect(component).toContain('MASTER NEEDED');
  expect(component).toContain('INCOMPLETE');
  expect(component).toContain('DISPLAY READY');
  expect(component).not.toContain('admin_promote_visual_asset');
 });
 it("states the exact age transition and fallback behavior",()=>{
  expect(component).toContain('Foals change to the mature stage at exact age 2');
  expect(component).toContain('neutral fallback');
 });
});
