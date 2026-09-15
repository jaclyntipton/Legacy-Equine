import{describe,expect,it}from"vitest";import{safeShowEntryError}from"../lib/game/show-entry-errors";
describe("safe player-facing show entry errors",()=>{
 it("maps expected gameplay failures",()=>{expect(safeShowEntryError("duplicate key: already entered")).toMatch(/already entered/);expect(safeShowEntryError("not eligible tier")).toMatch(/not eligible/);expect(safeShowEntryError("Insufficient LED")).toMatch(/enough LE Dollars/)});
 it("never exposes unexpected database internals",()=>{const safe=safeShowEntryError('column reference "horse_id" is ambiguous in player_show_entries');expect(safe).toBe("We couldn't complete that show entry. Please try again.");expect(safe).not.toMatch(/horse_id|column|player_show_entries|ambiguous/) });
});
