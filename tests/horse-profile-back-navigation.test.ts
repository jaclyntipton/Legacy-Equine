import{readFileSync}from"node:fs";
import{describe,expect,it}from"vitest";

const profile=readFileSync(new URL("../app/horse-profile.tsx",import.meta.url),"utf8");
const page=readFileSync(new URL("../app/page.tsx",import.meta.url),"utf8");
const styles=readFileSync(new URL("../app/horse-profile-navigation.module.css",import.meta.url),"utf8");

describe("Horse Profile stable navigation",()=>{
 it("routes owned horses explicitly to My Stable / My Horses",()=>{
  expect(profile).toContain("← BACK TO MY STABLE");
  expect(page).toContain('backToMyStable={() => navigate("stable",{stableTab:"horses"})}');
  expect(page).toContain('path=state?.stableTab==="horses"?"/stable/horses"');
  expect(profile).not.toContain("history.back");
 });

 it("routes other players' horses to the owner's public Stable",()=>{
  expect(profile).toContain("visitOwnerStable(h.owner_id!)");
  expect(page).toContain('visitOwnerStable={(ownerId) => navigate("publicstable",{publicStableId:ownerId})}');
  expect(page).toContain('path=`/stables/${state.publicStableId}`');
  expect(profile).toContain('.from("stables").select("name")');
 });

 it("supports direct public horse routes and mobile touch sizing",()=>{
  expect(page).toContain('.from("horses").select("*").eq("id",selected).maybeSingle()');
  expect(styles).toContain("min-height: 44px");
  expect(styles).toContain("max-width: 100%");
 });
});
