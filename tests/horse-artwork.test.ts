import {describe,expect,it} from "vitest";
import {horseArtworkCandidates,isUniqueHorseArtwork} from "../lib/game/horse-artwork";
describe("horse artwork recovery",()=>{
  it("uses an individual horse image",()=>expect(horseArtworkCandidates("https://cdn.example/horse.png")).toEqual(["https://cdn.example/horse.png"]));
  it("shows no image while unique artwork is pending",()=>expect(horseArtworkCandidates("")).toEqual([]));
  it("never exposes the Foundation reference as a portrait",()=>expect(horseArtworkCandidates("/foundation-horse.png")).toEqual([]));
  it("recognizes absolute Foundation reference URLs",()=>expect(isUniqueHorseArtwork("https://game.example/foundation-horse.png?v=2")).toBe(false));
});
