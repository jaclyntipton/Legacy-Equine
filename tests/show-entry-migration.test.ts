import{readFileSync}from"node:fs";import{describe,expect,it}from"vitest";
const sql=readFileSync(new URL("../supabase/migrations/202609150048_unlimited_multi_horse_show_entries.sql",import.meta.url),"utf8");
describe("transactional multi-horse show entry migration",()=>{
 it("removes the one-owner cap and accepts a UUID array",()=>{expect(sql).not.toContain("Owner entry limit reached");expect(sql).toContain("enter_player_show_batch(target_show uuid,target_horses uuid[])")});
 it("locks the show, stable, and every selected horse before charging",()=>{expect(sql).toMatch(/player_shows where id=target_show for update/);expect(sql).toMatch(/stables where id=auth\.uid\(\) for update/);expect(sql).toMatch(/horses where id=horse_id for update/)});
 it("charges once per distinct horse and rejects duplicates",()=>{expect(sql).toContain("sh.entry_fee*cardinality(horse_ids)");expect(sql).toContain("select coalesce(array_agg(distinct x order by x)");expect(sql).toContain("already entered in this show")});
 it("treats the optional maximum as total horse entries",()=>expect(sql).toContain("existing_count+cardinality(horse_ids)>sh.max_entries"));
 it("snapshots Career Points and tier at entry",()=>{expect(sql).toContain("career_points_at_entry");expect(sql).toContain("tier_at_entry")});
 it("uses the authoritative database tier function for strict divisions",()=>expect((sql.match(/get_horse_competition_tier/g)||[]).length).toBeGreaterThan(5));
});
