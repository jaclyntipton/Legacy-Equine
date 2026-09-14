export function seededRandom(seed: number) {
  let value = seed >>> 0;
  return () => { value = (value * 1664525 + 1013904223) >>> 0; return value / 4294967296; };
}
export const integer = (random: () => number, min: number, max: number) => Math.floor(random() * (max - min + 1)) + min;
export const pick = <T>(random: () => number, values: readonly T[]) => values[Math.floor(random() * values.length)];

