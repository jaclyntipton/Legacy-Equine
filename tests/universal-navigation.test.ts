import{describe,expect,it}from"vitest";
import{readFileSync}from"node:fs";
const source=readFileSync("app/universal-game-navigation.tsx","utf8");
describe("universal game navigation",()=>{
 it("defines the consolidated main branches",()=>{for(const label of ["World","Compete","Professions","Community"])expect(source).toContain(`label:\"${label}\"`)});
 it("preserves every required child destination",()=>{for(const href of ["/store/foundation-horses","/marketplace","/bank","/sanctuary","/shows","/training","/professions/businesses","/professions?section=market#professional-market","/community","/community/chat"])expect(source).toContain(`href:\"${href}\"`)});
 it("uses drill-in mobile navigation",()=>{expect(source).toContain("setCurrent(id)");expect(source).toContain("‹ Back");expect(source).not.toContain('label:"LE Store",href:"/store/foundation-horses"},{label:"Training"')});
});
