import{readFileSync}from"node:fs";import{describe,expect,it}from"vitest";
const page=readFileSync(new URL("../app/page.tsx",import.meta.url),"utf8");

describe("horse ownership isolation",()=>{
 it("keeps externally viewed horses out of My Stable",()=>{
  expect(page).toContain("horses.filter((candidate) => candidate.owner_id === user?.id)");
  expect(page).toContain("const barnHorses=useMemo(()=>ownedHorses.filter");
  expect(page).toContain("const filtered = barnHorses.filter((h) =>");
  expect(page).toContain("Showing {visibleHorses.length} of {barnHorses.length} horses");
  expect(page).toContain("<HorseListTools horses={barnHorses}");
 });
 it("excludes viewed horses from owner-only gameplay selectors",()=>{
  expect(page).toContain("<TrainingCenter\n              horses={ownedHorses}");
  expect(page).toContain("<PlayerShows\n              horses={ownedHorses}");
  expect(page).toContain("<MarketplaceView\n              listings={market}\n              horses={ownedHorses}");
  expect(page).toContain("<SanctuaryView horses={sanctuary} owned={ownedHorses}");
  expect(page).toContain("<StableInventory room={stableTab} horses={ownedHorses}");
 });
});
