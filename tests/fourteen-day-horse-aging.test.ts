import{readFileSync}from"node:fs";import{describe,expect,it}from"vitest";
const migration=readFileSync(new URL("../supabase/migrations/202611120002_fourteen_day_horse_year.sql",import.meta.url),"utf8"),spec=readFileSync(new URL("../GAME_SPEC.md",import.meta.url),"utf8"),config=readFileSync(new URL("../lib/game/config.ts",import.meta.url),"utf8");
describe("14-day horse-year rollout",()=>{
 it("uses the same 14-day rate in server, client, and specification",()=>{expect(migration).toContain("set real_days_per_horse_year=14");expect(config).toContain("realDaysPerHorseYear: 14");expect(spec).toContain("one horse-year per 14 real days")});
 it("re-anchors existing timestamps before changing the rate",()=>{expect(migration.indexOf("update public.horses")).toBeLessThan(migration.indexOf("set real_days_per_horse_year=14"));expect(migration).toContain("/old_days)*14*86400")});
 it("updates gameplay guidance and publishes an idempotent public News post",()=>{expect(migration).toContain("One horse-year passes every 14 real days");expect(migration).toContain("horse-aging-14-day-year-2026");expect(migration).toContain("on conflict(source_type,source_key)do update")});
});
