import {describe,expect,it} from "vitest";
import {horseArtworkCandidates,isUniqueHorseArtwork} from "../lib/game/horse-artwork";
import {coatAccuracyConstraint,patternMaySubsumeMarkings} from "../lib/game/horse-visual";
describe("horse artwork recovery",()=>{
  it("uses only the horse's production artwork",()=>expect(horseArtworkCandidates("https://cdn.example/horse.png")).toEqual(["https://cdn.example/horse.png"]));
  it("uses the branded pending state while artwork is incomplete",()=>expect(horseArtworkCandidates("")).toEqual([]));
  it("never revives the retired generic Foundation artwork",()=>expect(horseArtworkCandidates(`/${["foundation","horse.png"].join("-")}`)).toEqual([]));
  it("recognizes absolute retired reference URLs",()=>expect(isUniqueHorseArtwork(`https://game.example/${["foundation","horse.png"].join("-")}?v=2`)).toBe(false));
  it("requires black pigment evidence for every bay base",()=>{const rule=coatAccuracyConstraint("Bay Splashed White");expect(rule).toContain("black mane");expect(rule).toContain("red/copper mane or tail");expect(rule).toContain("WRONG")});
  it("keeps white-pattern validation separate from underlying pigment",()=>expect(coatAccuracyConstraint("Bay Splashed White")).toContain("remaining pigmented areas MUST retain the stated base-coat pigment"));
  it("does not give chestnut horses bay points",()=>expect(coatAccuracyConstraint("Sorrel")).toContain("no genetically black bay points"));
  it("lets genetic white patterns subsume standalone markings",()=>{expect(patternMaySubsumeMarkings("Splashed white pattern","Bay Splashed White")).toBe(true);expect(patternMaySubsumeMarkings("No body pattern","Bay")).toBe(false)});
});
