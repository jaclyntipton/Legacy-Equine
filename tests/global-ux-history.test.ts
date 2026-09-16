import{describe,expect,it}from"vitest";
import fs from"node:fs";import path from"node:path";
const root=path.resolve(__dirname,".."),page=fs.readFileSync(path.join(root,"app/page.tsx"),"utf8"),horse=fs.readFileSync(path.join(root,"app/horse-profile.tsx"),"utf8"),catchAll=fs.readFileSync(path.join(root,"app/[...path]/page.tsx"),"utf8");
describe("global UX navigation",()=>{
 it("uses a non-layout toast with routine auto dismissal and persistent errors",()=>{expect(page).toContain("function GlobalToast");expect(page).toContain("setTimeout(dismiss,2800)");expect(page).toContain('role={persistent?"alert":"status"}');expect(page).not.toContain('useState("Welcome to Legacy Equine.")')});
 it("pushes meaningful destinations and restores popstate",()=>{expect(page).toContain("history.pushState({le:true}");expect(page).toContain('addEventListener("popstate",back)');expect(page).toContain('"/stable/tack-room"');expect(page).toContain('"/profile/artwork"');expect(page).toContain('"/store/foundation-horses"')});
 it("makes horse tabs real history entries",()=>{expect(horse).toContain("history.pushState({leHorseTab:true}");expect(horse).toContain('addEventListener("popstate",restore)');expect(horse).not.toContain("history.replaceState")});
 it("supports direct refresh for nested application routes",()=>{expect(catchAll).toContain('export{default}from"../page"')});
});
