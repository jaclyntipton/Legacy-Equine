import fs from "node:fs";
import path from "node:path";
import {describe,expect,it} from "vitest";

const page=fs.readFileSync(path.resolve(__dirname,"../app/page.tsx"),"utf8");
const css=fs.readFileSync(path.resolve(__dirname,"../app/store-filter-controls.css"),"utf8");

describe("LE Store search and filter controls",()=>{
  it("restores Foundation horse search and breed filtering",()=>{
    expect(page).toContain('aria-label="Search Horses"');
    expect(page).toContain('aria-label="Foundation horse breed"');
    expect(page).toContain("visibleStoreHorses.map");
  });

  it("restores Feed & Hay controls and all requested sort choices",()=>{
    expect(page).toContain('aria-label={storeDepartment==="tack"?"Tack category":"Feed and hay type"}');
    expect(page).toContain('placeholder={`Search ${storeDepartment==="tack"?"Tack":"Feed & Hay"}`}');
    for(const value of ['value="tier-asc"','value="tier-desc"','value="price-asc"','value="price-desc"'])expect(page).toContain(value);
  });

  it("keeps Tack tier ordering authoritative",()=>{
    expect(page).toContain('const STORE_TIERS=["Entry","Quality","Elite","Legendary"]');
    expect(page).toContain('storeDepartment==="tack"?"All Tiers":"All"');
  });

  it("keeps filter labels and controls contained on desktop and mobile",()=>{
    expect(page).toContain('import "@/app/store-filter-controls.css"');
    expect(css).toContain(".productfilters{display:grid");
    expect(css).toContain(".productfilters label{display:grid");
    expect(css).toContain("@media(max-width:480px)");
  });
});
