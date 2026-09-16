import{describe,expect,it}from"vitest";import{readFileSync}from"node:fs";
const page=readFileSync("app/page.tsx","utf8"),visuals=readFileSync("app/visual-asset-requirements.tsx","utf8"),permissions=readFileSync("supabase/migrations/202609160017_admin_control_center.sql","utf8"),retirement=readFileSync("supabase/migrations/202609160018_retire_generic_foundation_art.sql","utf8");
describe("Admin Control Center",()=>{
 it("provides the complete sticky topic architecture",()=>{for(const label of["Dashboard","Horses","Horse Visuals","Store & Inventory","Shows","Professions","Accounts","Economy / Bank","Stable Brands","Game Balance","System / QA","Audit Log"])expect(page).toContain(`label:\"${label}\"`);expect(page).toContain("admintopics")});
 it("keeps the Visual workspace compact and discoverable",()=>{expect(visuals).toContain("starter_packs");expect(visuals).toContain("Download Artist Starter Pack");expect(visuals).toContain("asset_matrix");expect(visuals).toContain("le-visual-filters")});
 it("makes Owner #1 implicit and permissions server-authoritative",()=>{expect(permissions).toContain("public.is_owner_account(p_user)");expect(permissions).toContain("require_admin_permission");expect(permissions).toContain("admin.visuals.production");expect(permissions).toContain("admin.audit.view")});
 it("retires live generic artwork without touching immutable masters",()=>{expect(retirement).toContain("image_url=''");expect(retirement).toContain("active=false");expect(retirement).not.toContain("qh_mare_master_01");expect(retirement).not.toContain("qh_stallion_master_01")});
});
