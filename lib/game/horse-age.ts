import { GAME } from "./config";

export const HORSE_AGE_REFRESH_MS = 60_000;

export function horseAgeYears(birthDate: string | Date, at: string | Date | number = Date.now()) {
  const birth = new Date(birthDate).getTime();
  const current = typeof at === "number" ? at : new Date(at).getTime();
  if (!Number.isFinite(birth) || !Number.isFinite(current)) return 0;
  return Math.max(0, (current - birth) / 86_400_000 / GAME.age.realDaysPerHorseYear);
}

export function horseAgeLongLabel(birthDate: string | Date, at: string | Date | number = Date.now()) {
  const months = Math.floor(horseAgeYears(birthDate, at) * 12);
  const years = Math.floor(months / 12);
  const remainder = months % 12;
  return `${years} ${years === 1 ? "year" : "years"}${remainder ? `, ${remainder} ${remainder === 1 ? "month" : "months"}` : ""}`;
}

export function horseAgeCompactLabel(birthDate: string | Date, at: string | Date | number = Date.now()) {
  const months = Math.floor(horseAgeYears(birthDate, at) * 12);
  return months < 12 ? `${months} month${months === 1 ? "" : "s"}` : `${Math.floor(months / 12)}y ${months % 12}m`;
}
