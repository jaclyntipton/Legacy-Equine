import { describe, expect, it } from "vitest";
import { GAME } from "./config";
import { seededRandom } from "./random";
import { canBreed, createFoal, createFoundationHorse, gameAge } from "./simulation";
describe("simulation", () => {
  it("generates deterministic two-year-old foundation horses in configured bounds", () => { const now=new Date("2026-01-01");const a=createFoundationHorse(seededRandom(42),now); const b=createFoundationHorse(seededRandom(42),now); expect(a.stats).toEqual(b.stats);expect(gameAge(a,now)).toBeCloseTo(2,5);Object.values(a.stats).forEach(v=>expect(v).toBeGreaterThanOrEqual(GAME.foundation.outlierMinimum)); });
  it("inherits each foal stat from the balanced parental average plus bounded variance", () => { const s=createFoundationHorse(seededRandom(1)); const d={...createFoundationHorse(seededRandom(2)),sex:"Mare" as const}; const f=createFoal({...s,sex:"Stallion"},d,seededRandom(3)); GAME.stats.forEach(k=>expect(Math.abs(f.stats[k]-Math.round((s.stats[k]+d.stats[k])/2))).toBeLessThanOrEqual(GAME.breedingVariance+1)); });
  it("calculates age from timestamps", () => { const h=createFoundationHorse(seededRandom(4),new Date("2026-01-01")); expect(gameAge(h,new Date("2026-01-02"))).toBeGreaterThan(gameAge(h,new Date("2026-01-01"))); });
  it("enforces mare cooldown", () => { const h={...createFoundationHorse(seededRandom(5)),sex:"Mare" as const,lastBredAt:new Date().toISOString()}; expect(canBreed(h)).toBe(false); });
});
