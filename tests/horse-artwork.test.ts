import {describe,expect,it} from "vitest";
import {horseArtworkCandidates} from "../lib/game/horse-artwork";
describe("horse artwork recovery",()=>{
  it("tries the horse image before the official fallback",()=>expect(horseArtworkCandidates("https://cdn.example/horse.png")).toEqual(["https://cdn.example/horse.png","/foundation-horse.png"]));
  it("uses the Foundation image when no image exists",()=>expect(horseArtworkCandidates("")).toEqual(["/foundation-horse.png"]));
  it("does not duplicate the official fallback",()=>expect(horseArtworkCandidates("/foundation-horse.png")).toEqual(["/foundation-horse.png"]));
  it("treats whitespace as missing",()=>expect(horseArtworkCandidates("   ")).toEqual(["/foundation-horse.png"]));
});
