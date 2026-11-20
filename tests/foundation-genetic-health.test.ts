import {describe, expect, it} from "vitest";
import {foundationGeneticHealth} from "../lib/game/foundation-genetic-health";

describe("Foundation Store genetic health", () => {
  it("distinguishes dominant risk, recessive carriers, and absent variants", () => {
    const results = foundationGeneticHealth({
      HYPP: ["N", "H"], PSSM1: ["P1", "N"], GBED: ["N", "G"],
      HERDA: ["H", "H"], SCID: ["N", "N"],
    });
    expect(results.slice(0, 5).map(r => [r.locus, r.status])).toEqual([
      ["HYPP", "Risk variant present"], ["PSSM1", "Risk variant present"], ["GBED", "Carrier"],
      ["HERDA", "Risk variant present"], ["SCID", "Variant absent"],
    ]);
  });

  it("labels incomplete or invalid genotype data as unknown", () => {
    const results = foundationGeneticHealth({HYPP: ["N"], PSSM1: ["N", "?"], GBED: null});
    expect(results.every(result => result.status === "Unknown" && result.genotype === null)).toBe(true);
  });
});
