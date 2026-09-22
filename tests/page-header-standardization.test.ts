import {describe,expect,it} from "vitest";
import fs from "node:fs";
import path from "node:path";

const root=process.cwd();
const read=(file:string)=>fs.readFileSync(path.join(root,file),"utf8");

describe("global page header standard",()=>{
  it("provides one reusable semantic header component",()=>{
    const source=read("app/page-section-header.tsx");
    expect(source).toContain("export function PageSectionHeader");
    expect(source).toContain("primaryAction");
    expect(source).toContain("secondaryAction");
    expect(source).toContain("<header");
  });

  it("uses the shared header for core page titles and News",()=>{
    expect(read("app/page.tsx")).toContain("<PageSectionHeader");
    expect(read("app/home-news.tsx")).toContain("<PageSectionHeader");
  });

  it("keeps approved contrast, focus, responsive stacking, and transitional workspace coverage",()=>{
    const css=read("app/page-section-header.css");
    expect(css).toContain("linear-gradient(120deg,#4a2e78,#7048a9)");
    expect(css).toContain("outline:3px solid #ffd99f");
    expect(css).toContain("@media(max-width:700px)");
    for(const selector of [".supportcenter>.supporthero",".handbook>.handbookhero",".adminsupport>header",".stablemanagementhead"]){
      expect(css).toContain(selector);
    }
  });
});
