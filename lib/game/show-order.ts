export type DiscoverableShow = { id: string; name: string; discipline?: string; tier?: string; tier_id?: string; run_at: string };

const tierOrder: Record<string, number> = { novice: 0, intermediate: 1, advanced: 2, elite: 3 };
const natural = new Intl.Collator("en", { numeric: true, sensitivity: "base" });
const trailingSequence = /^(.*?)(?:\s*#?\s*(\d+))\s*$/;

const seriesParts = (name: string) => {
  const match = name.trim().match(trailingSequence);
  return match ? { base: match[1].trim(), sequence: Number(match[2]) } : { base: name.trim(), sequence: Number.MAX_SAFE_INTEGER };
};

export const compareDiscoverableShows = (a: DiscoverableShow, b: DiscoverableShow) => {
  const time = new Date(a.run_at).getTime() - new Date(b.run_at).getTime();
  if (time) return time;
  const discipline = natural.compare(a.discipline ?? "", b.discipline ?? "");
  if (discipline) return discipline;
  const aTier = tierOrder[(a.tier_id ?? a.tier ?? "").toLowerCase()] ?? Number.MAX_SAFE_INTEGER;
  const bTier = tierOrder[(b.tier_id ?? b.tier ?? "").toLowerCase()] ?? Number.MAX_SAFE_INTEGER;
  if (aTier !== bTier) return aTier - bTier;
  const aSeries = seriesParts(a.name), bSeries = seriesParts(b.name);
  const series = natural.compare(aSeries.base, bSeries.base);
  return series || aSeries.sequence - bSeries.sequence || natural.compare(a.name, b.name) || a.id.localeCompare(b.id);
};

export const orderDiscoverableShows = <T extends DiscoverableShow>(shows: readonly T[]) => [...shows].sort(compareDiscoverableShows);
