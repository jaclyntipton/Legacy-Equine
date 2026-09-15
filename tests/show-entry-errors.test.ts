import{describe,expect,it}from"vitest";import{readFileSync}from"node:fs";import{safeShowEntryError}from"../lib/game/show-entry-errors";
describe("safe player-facing show entry errors",()=>{
 it("maps expected gameplay failures",()=>{expect(safeShowEntryError("duplicate key: already entered")).toMatch(/already entered/);expect(safeShowEntryError("not eligible tier")).toMatch(/not eligible/);expect(safeShowEntryError("Insufficient LED")).toMatch(/enough LE Dollars/)});
 it("never exposes unexpected database internals",()=>{const safe=safeShowEntryError('column reference "horse_id" is ambiguous in player_show_entries');expect(safe).toBe("We couldn't complete that show entry. Please try again.");expect(safe).not.toMatch(/horse_id|column|player_show_entries|ambiguous/) });
 it("guards both eligibility lookup and entry mutation calls",()=>{const source=readFileSync(new URL("../app/shows-v2.tsx",import.meta.url),"utf8");expect(source).toContain('get_show_entry_options",{p_show_id:show.id}');expect(source).toContain('enter_player_show_batch",{p_show_id:entryShow.id,p_horse_ids:selected}');expect((source.match(/safeShowEntryError/g)||[]).length).toBeGreaterThanOrEqual(3)});
});
