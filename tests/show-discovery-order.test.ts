import { describe, expect, it } from "vitest";
import { orderDiscoverableShows } from "../lib/game/show-order";

const show = (id: string, name: string, run_at = "2026-09-25T12:00:00Z", discipline = "Driving", tier = "Novice") => ({ id, name, run_at, discipline, tier });

describe("deterministic Show discovery ordering", () => {
  it("sorts independent series by their natural numeric sequence", () => {
    const rows = [show("19", "TFR Driving Classic #19"), show("6", "TFR Driving Classic #6"), show("10", "TFR Driving Classic #10"), show("1", "TFR Driving Classic #1")];
    expect(orderDiscoverableShows(rows).map(row => row.name)).toEqual(["TFR Driving Classic #1", "TFR Driving Classic #6", "TFR Driving Classic #10", "TFR Driving Classic #19"]);
  });
  it("orders date, discipline, canonical tier, series, sequence, and immutable id", () => {
    const rows = [show("z", "Series #2", "2026-09-26T12:00:00Z"), show("e", "Series #2", undefined, "Driving", "Elite"), show("a", "Series #2", undefined, "Dressage", "Advanced"), show("n", "Series #2", undefined, "Dressage", "Novice"), show("i", "Series #2", undefined, "Dressage", "Intermediate")];
    expect(orderDiscoverableShows(rows).map(row => row.id)).toEqual(["n", "i", "a", "e", "z"]);
  });
  it("does not mutate the source array", () => {
    const rows = [show("2", "Series #2"), show("1", "Series #1")];
    orderDiscoverableShows(rows);
    expect(rows[0].id).toBe("2");
  });
});
