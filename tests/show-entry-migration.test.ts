import{readFileSync}from"node:fs";import{describe,expect,it}from"vitest";
const sql=readFileSync(new URL("../supabase/migrations/202609150053_fix_show_entry_horse_id_ambiguity.sql",import.meta.url),"utf8");
describe("transactional multi-horse show entry migration",()=>{
 it("removes the one-owner cap and accepts a UUID array",()=>{expect(sql).not.toContain("Owner entry limit reached");expect(sql).toContain("enter_player_show_batch(p_show_id uuid,p_horse_ids uuid[])")});
 it("locks the show, stable, and every selected horse before charging",()=>{expect(sql).toMatch(/player_shows as ps where ps\.id=p_show_id for update/);expect(sql).toMatch(/stables as st where st\.id=auth\.uid\(\) for update/);expect(sql).toMatch(/horses as h where h\.id=v_selected_horse_id for update/)});
 it("supports a first, second, or 5+ same-owner horses as independent entries",()=>{expect(sql).not.toContain("maximum_per_owner");expect(sql).toContain("foreach v_selected_horse_id in array v_distinct_horse_ids loop");expect(sql).toContain("v_show.entry_fee*cardinality(v_distinct_horse_ids)")});
 it("charges once per distinct horse and rejects duplicate requests before charging",()=>{expect(sql).toContain("array_agg(distinct requested.id order by requested.id)");expect(sql).toContain("already entered in this show");expect(sql.indexOf("insert into public.player_show_entries")).toBeLessThan(sql.indexOf("update public.stables"))});
 it("treats the optional maximum as total horse entries",()=>expect(sql).toContain("v_existing_count+cardinality(v_distinct_horse_ids)>v_show.max_entries"));
 it("snapshots Career Points and tier at entry",()=>{expect(sql).toContain("career_points_at_entry");expect(sql).toContain("tier_at_entry")});
 it("uses the authoritative database tier function for strict divisions",()=>expect((sql.match(/get_horse_competition_tier/g)||[]).length).toBeGreaterThan(5));
 it("qualifies horse columns and never declares a horse_id PL/pgSQL variable",()=>{expect(sql).not.toMatch(/declare[\s\S]*?\bhorse_id uuid;/);expect(sql).toContain("pse.horse_id=v_horse.id");expect(sql).toContain("pse.horse_id from public.player_show_entries as pse")});
 it("serializes concurrent requests and relies on the unique show-horse constraint",()=>{expect(sql).toContain("where ps.id=p_show_id for update");expect(sql).toContain("exception when unique_violation")});
});
