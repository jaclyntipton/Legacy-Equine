const loci = [
  ["HYPP", "H", 1],
  ["PSSM1", "P1", 1],
  ["GBED", "G", 2],
  ["HERDA", "H", 2],
  ["SCID", "S", 2],
  ["LFS", "L", 2],
  ["CA", "C", 2],
  ["OAAM", "O", 2],
] as const;

export function foundationGeneticHealth(genetics: Record<string, unknown>) {
  return loci.map(([locus, variant, riskCopies]) => {
    const pair = genetics[locus];
    if (!Array.isArray(pair) || pair.length !== 2 || !pair.every(allele => allele === "N" || allele === variant)) {
      return {locus, genotype: null, status: "Unknown"};
    }
    const copies = pair.filter(allele => allele === variant).length;
    return {
      locus,
      genotype: pair.join("/"),
      status: copies === 0 ? "Variant absent" : copies >= riskCopies ? "Risk variant present" : "Carrier",
    };
  });
}
