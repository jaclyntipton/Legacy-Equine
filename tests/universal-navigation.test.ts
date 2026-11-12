import{describe,expect,it}from"vitest";
import{readFileSync}from"node:fs";
const source=readFileSync("app/universal-game-navigation.tsx","utf8");
describe("universal game navigation",()=>{
 it("defines the consolidated main branches",()=>{for(const label of ["World","Compete","Professions","Community"])expect(source).toContain(`label:\"${label}\"`)});
	it("preserves every required child destination",()=>{for(const href of ["/store/foundation-horses","/marketplace","/bank","/sanctuary","/shows","/training","/professions/businesses","/professions?section=market#professional-market","/community","/community/chat","/how-to-play"])expect(source).toContain(`href:\"${href}\"`)});
	it("places How to Play in Community rather than the mobile account list",()=>{expect(source).toContain('community:{label:"Community"');expect(source).toMatch(/community:\{[^\n]+label:"How to Play",href:"\/how-to-play"/);expect(source.match(/label:"How to Play"/g)).toHaveLength(1);expect(source).toContain('path.startsWith("/how-to-play")')});
 it("uses drill-in mobile navigation",()=>{expect(source).toContain("setCurrent(id)");expect(source).toContain("‹ Back");expect(source).not.toContain('label:"LE Store",href:"/store/foundation-horses"},{label:"Training"')});
});
