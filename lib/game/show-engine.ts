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

export type EffectiveBreakdown = Record<string, { birth: number; development: number; developed: number; tack: number; farrier?:number; massage?:number; service: number; effective: number }>;
export type CompetitionTier={id:string;name:string;minimum_average:number;maximum_average:number|null;sort_order:number};
export const permanentStatAverage=(stats:Record<string,number>)=>["Agility","Speed","Endurance","Temperament","Strength","Intelligence","Conformation"].reduce((sum,key)=>sum+Number(stats[key]??0),0)/7;
export const competitionTier=(average:number,tiers:CompetitionTier[])=>[...tiers].sort((a,b)=>b.minimum_average-a.minimum_average).find(t=>average>=t.minimum_average)??null;
export const tierRangeLabel=(tier:CompetitionTier)=>tier.maximum_average==null?`Avg ${tier.minimum_average}+`:tier.minimum_average===0?`Avg <${tier.maximum_average+0.01}`:`Avg ${tier.minimum_average}–${tier.maximum_average}`;
export const competitionScore = (stats: readonly string[], breakdown: EffectiveBreakdown) =>
  stats.reduce((sum, stat) => sum + (breakdown[stat]?.effective ?? 0), 0) / stats.length;
export const placingLabel = (placement: number) => placement === 1 ? "WIN" : placement === 2 ? "PLACE" : placement === 3 ? "SHOW" : `${placement}TH`;
export const rankDeterministically = <T extends { score: number; baseScore: number; careerPoints: number; enteredAt: string; horseId: string }>(entries: T[]) =>
  [...entries].sort((a, b) => b.score - a.score || b.baseScore - a.baseScore || b.careerPoints - a.careerPoints || a.enteredAt.localeCompare(b.enteredAt) || a.horseId.localeCompare(b.horseId));
