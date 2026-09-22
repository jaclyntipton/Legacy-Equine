import{describe,expect,it}from"vitest";
import fs from"node:fs";

const read=(file:string)=>fs.readFileSync(file,"utf8");

describe("My Stable refinement",()=>{
 it("preserves Supply Room with the future-facing empty state",()=>{
  const page=read("app/page.tsx"),inventory=read("app/stable-inventory.tsx");
  expect(page).toContain('Supply Room</button>');
  expect(inventory).toContain("Your Supply Room is empty");
  expect(inventory).toContain("Brushes, grooming supplies, treats, and other Stable essentials");
  expect(inventory).not.toContain("Purchased Stable Supply products will appear here.");
 });
 it("keeps all three header actions as visual peers",()=>{
  const page=read("app/page.tsx"),css=read("app/page-section-header.css");
  expect(page).toContain("View Stable Profile");
  expect(page).toContain("Customize Stable");
  expect(page).toContain("Visit LE Store");
  expect(page).not.toContain('<button className="primary" onClick={()=>navigate("store",{storeDepartment:"horses"})}>Visit LE Store</button>');
  expect(css).toContain(".stableprofileactions button:hover:not(:disabled)");
  expect(css).toContain(".stableprofileactions button:focus-visible");
 });
});
