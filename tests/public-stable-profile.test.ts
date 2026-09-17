import{describe,expect,it}from"vitest";import{readFileSync}from"node:fs";
const page=readFileSync("app/page.tsx","utf8"),profile=readFileSync("app/public-stable-profile.tsx","utf8"),css=readFileSync("app/public-stable-profile.css","utf8"),sql=readFileSync("supabase/migrations/202609170019_public_stable_profiles.sql","utf8");
describe("public Stable profiles",()=>{
 it("keeps ranch imagery off My Profile and on the public Stable",()=>{expect(page).not.toContain('playerprofilehero ${stable.ranch_image_url');expect(profile).toContain("profile.ranch_image_url");expect(page).toContain("View Public Stable Profile")});
 it("routes Stable identities publicly",()=>{expect(page).toContain('path=`/stables/${state.publicStableId}`');expect(page).toContain('view="publicstable"');expect(profile).toContain("get_public_stable_profile")});
 it("connects the existing viewer and editor from My Stable",()=>{expect(page).toContain(">View Stable Profile</button>");expect(page).toContain(">Customize Stable</button>");expect(page).toContain("?customize=1");expect(profile).toContain('value.owner&&new URLSearchParams(location.search).get("customize")==="1"')});
 it("supports the approved blocks and ordering",()=>{for(const name of["Stable Banner","Stable News","About the Stable","Featured Horses","Stallions","Broodmares","Recent Winners","Professional Services","Custom Text","Move Up","Move Down","Reset to Standard Layout"])expect(profile).toContain(name)});
 it("connects Owner and Level 20 capability without changing horse data",()=>{expect(sql).toContain("is_owner_account(p_stable)");expect(sql).toContain("c.custom_stable_layout");expect(sql).toContain("stable_layout_capability_grants");expect(sql).not.toContain("update horses")});
 it("sanitizes content server-side and renders without executable HTML",()=>{expect(sql).toContain("stable_safe_rich_text");expect(sql).toContain("'<[^>]*>'");expect(sql).toContain("'(javascript|vbscript|data)");expect(profile).not.toContain("dangerouslySetInnerHTML")});
 it("provides responsive bounded layouts",()=>{expect(css).toContain(".publichorsegrid{grid-template-columns:1fr}");expect(css).toContain(".publicstablebanner{min-height:250px")});
});
