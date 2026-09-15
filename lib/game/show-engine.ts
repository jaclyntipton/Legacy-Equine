export const PROVISIONAL_DISCIPLINE_STATS = {
  hunters: ["Agility", "Temperament", "Conformation", "Intelligence"],
  jumpers: ["Agility", "Strength", "Speed", "Intelligence"],
  dressage: ["Agility", "Temperament", "Intelligence", "Conformation"],
  halter: ["Conformation", "Temperament", "Strength"],
  reining: ["Agility", "Temperament", "Intelligence", "Strength"],
  western_pleasure: ["Temperament", "Conformation", "Intelligence", "Agility"],
  trail: ["Temperament", "Intelligence", "Agility", "Endurance"],
  driving: ["Strength", "Temperament", "Endurance", "Intelligence"],
  steeplechase: ["Speed", "Endurance", "Agility", "Strength"],
  fox_hunting: ["Endurance", "Agility", "Temperament", "Intelligence"],
  racing: ["Speed", "Endurance", "Strength"],
  cross_country: ["Endurance", "Agility", "Strength", "Temperament"],
} as const;

export type EffectiveBreakdown = Record<string, { base: number; training: number; tack: number; service: number; effective: number }>;
export const competitionScore = (stats: readonly string[], breakdown: EffectiveBreakdown) =>
  stats.reduce((sum, stat) => sum + (breakdown[stat]?.effective ?? 0), 0) / stats.length;
export const placingLabel = (placement: number) => placement === 1 ? "WIN" : placement === 2 ? "PLACE" : placement === 3 ? "SHOW" : `${placement}TH`;
export const rankDeterministically = <T extends { score: number; baseScore: number; careerPoints: number; enteredAt: string; horseId: string }>(entries: T[]) =>
  [...entries].sort((a, b) => b.score - a.score || b.baseScore - a.baseScore || b.careerPoints - a.careerPoints || a.enteredAt.localeCompare(b.enteredAt) || a.horseId.localeCompare(b.horseId));
