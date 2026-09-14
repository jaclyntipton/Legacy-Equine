import { GAME } from "./config";
import { integer, pick } from "./random";
import type { Horse, Stats } from "./types";

const id = (random: () => number) => `${Date.now().toString(36)}-${Math.floor(random() * 1e9).toString(36)}`;
const blankBonuses = () => Object.fromEntries(GAME.stats.map((stat) => [stat, 0]));
export function foundationStat(random: () => number) {
  if (random() < GAME.foundation.outlierChance) return integer(random, GAME.foundation.outlierMinimum, GAME.foundation.outlierMaximum);
  return integer(random, GAME.foundation.minimum, GAME.foundation.maximum);
}
export function createFoundationHorse(random: () => number, now = new Date()): Horse {
  const sex = pick(random, ["Mare", "Stallion"] as const);
  const stats = Object.fromEntries(GAME.stats.map((stat) => [stat, foundationStat(random)]));
  const age = 4 + random() * 4;
  return { id: id(random), name: `Unnamed ${pick(random, ["Hope", "Promise", "Legacy", "Star"])}`, breed: pick(random, GAME.foundationBreeds), sex, color: pick(random, GAME.colors), origin: "Foundation", birthDate: new Date(now.getTime() - age * 365.25 * 86400000 / GAME.age.gameDaysPerRealDay).toISOString(), createdAt: now.toISOString(), sireId: null, damId: null, generation: 0, stats, tackBonuses: blankBonuses(), biography: "", imageUrl: "", studFee: GAME.defaultStudFee, lastBredAt: null, lastTrainedAt: null, retired: false };
}
export function createFoal(sire: Horse, dam: Horse, random: () => number, now = new Date()): Horse {
  if (sire.sex !== "Stallion" || dam.sex !== "Mare") throw new Error("Breeding requires a stallion and mare.");
  const stats = Object.fromEntries(GAME.stats.map((stat) => [stat, Math.max(1, Math.round((sire.stats[stat] + dam.stats[stat]) / 2) + integer(random, -GAME.breedingVariance, GAME.breedingVariance) - (random() < GAME.breedingRegressionChance ? 1 : 0))]));
  return { id: id(random), name: "Unnamed Foal", breed: sire.breed === dam.breed ? sire.breed : "Crossbred", sex: pick(random, ["Mare", "Stallion"] as const), color: pick(random, [sire.color, dam.color]), origin: "Bred", birthDate: now.toISOString(), createdAt: now.toISOString(), sireId: sire.id, damId: dam.id, generation: Math.max(sire.generation, dam.generation) + 1, stats, tackBonuses: blankBonuses(), biography: "", imageUrl: "", studFee: GAME.defaultStudFee, lastBredAt: null, lastTrainedAt: null, retired: false };
}
export const effectiveStats = (horse: Horse): Stats => Object.fromEntries(GAME.stats.map((stat) => [stat, horse.stats[stat] + (horse.tackBonuses[stat] ?? 0)]));
export const overall = (horse: Horse) => Object.values(effectiveStats(horse)).reduce((a, b) => a + b, 0);
export const gameAge = (horse: Horse, now = new Date()) => Math.max(0, (now.getTime() - new Date(horse.birthDate).getTime()) / 86400000 * GAME.age.gameDaysPerRealDay / 365.25);
export const cooldownEnds = (mare: Horse) => mare.lastBredAt ? new Date(new Date(mare.lastBredAt).getTime() + GAME.mareCooldownDays * 86400000) : null;
export const canBreed = (horse: Horse, now = new Date()) => !horse.retired && gameAge(horse, now) >= GAME.age.breedingMinimumYears && gameAge(horse, now) < GAME.age.retirementYears && (horse.sex === "Stallion" || !cooldownEnds(horse) || cooldownEnds(horse)!.getTime() <= now.getTime());
export const canTrain = (horse: Horse, now = new Date()) => !horse.lastTrainedAt || now.getTime() - new Date(horse.lastTrainedAt).getTime() >= GAME.training.cooldownHours * 3600000;
