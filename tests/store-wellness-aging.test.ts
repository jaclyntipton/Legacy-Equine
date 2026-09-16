import{readFileSync}from"node:fs";import{describe,expect,it}from"vitest";
const store=readFileSync(new URL("../supabase/migrations/202609160006_store_wellness_feed_tack_aging.sql",import.meta.url),"utf8"),age=readFileSync(new URL("../supabase/migrations/202609160007_authoritative_age_gameplay.sql",import.meta.url),"utf8");
describe("Store, Wellness, and continuous aging",()=>{
 it("maintains four shared horses per active breed by default",()=>{expect(store).toContain("store_inventory_size integer not null default 4");expect(store).toContain("pg_advisory_xact_lock(674381)")});
 it("records one optional feeding per horse and LE day",()=>{expect(store).toContain("unique(horse_id,le_day)");expect(store).toContain("Development Feeding is already complete")});
 it("keeps tack in explicit equipment slots",()=>{expect(store).toContain("unique(horse_id,slot)");expect(store).toContain("recalculate_horse_tack")});
 it("keeps Wellness bounded and activity based",()=>{expect(store).toContain("check(health between 0 and 100)");expect(store).toContain("wellness_wear_training");expect(store).toContain("wellness_wear_show")});
 it("enforces Vet half-year and Friday care windows",()=>{expect(store).toContain(":first");expect(store).toContain(":second");expect(store).toContain("le_week_start(new.completed_at)")});
 it("derives continuous age from 28 real days",()=>{expect(store).toContain("real_days_per_horse_year numeric not null default 28");expect(age).toContain("horse_game_age(sire.birth_date)");expect(age).toContain("interval '56 days'")});
});
