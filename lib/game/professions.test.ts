import{describe,expect,it}from"vitest";
import{CERTIFICATION_LEVELS,effectiveStat,qualifyingCredit,scoreCertification,validateServicePrice}from"./professions";
describe("Legacy Equine professions",()=>{
 it("uses the approved four configurable tiers",()=>expect(CERTIFICATION_LEVELS.map(x=>[x.name,x.requiredServices])).toEqual([["Basic",0],["Proficient",10],["Advanced",25],["Professional",50]]));
 it("passes at the configured 80 percent threshold",()=>{expect(scoreCertification(4,5)).toEqual({score:80,passed:true});expect(scoreCertification(3,5).passed).toBe(false)});
 it("counts self service at half credit",()=>expect(qualifyingCredit(8,4)).toBe(10));
 it("enforces provider price ranges",()=>{expect(validateServicePrice(250,250,500)).toBe(true);expect(validateServicePrice(501,250,500)).toBe(false)});
 it("keeps visible stat layers additive",()=>expect(effectiveStat(42,4,2,1,2)).toBe(51));
});
