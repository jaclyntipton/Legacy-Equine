import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const shows = readFileSync("app/shows-v2.tsx", "utf8");

describe("Upcoming Show discovery", () => {
  it("queries open future Shows independently from capped completed history", () => {
    expect(shows).toContain('.rpc("get_player_shows").eq("status","open").gt("run_at",now).order("run_at")');
    expect(shows).toContain('.rpc("get_player_shows").eq("status","complete").order("run_at",{ascending:false}).limit(250)');
  });

  it("does not gate the Upcoming Shows list by horse eligibility", () => {
    const upcoming = shows.slice(
      shows.indexOf('view==="upcoming"'),
      shows.indexOf('view==="create"'),
    );
    expect(upcoming).toContain("openShows.map");
    expect(upcoming).not.toContain("levelOf(");
    expect(upcoming).not.toContain("filteredShows");
    expect(shows).toContain('orderDiscoverableShows(shows.filter(s=>s.status==="open"))');
  });
});
