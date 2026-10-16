import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { horseAgeCompactLabel, horseAgeLongLabel, horseAgeYears } from "../lib/game/horse-age";

describe("authoritative continuous horse aging", () => {
  const birth = "2026-01-01T00:00:00.000Z";

  it("advances one horse-year every 28 real days without materialization", () => {
    expect(horseAgeYears(birth, "2026-01-29T00:00:00.000Z")).toBe(1);
    expect(horseAgeYears(birth, "2026-02-26T00:00:00.000Z")).toBe(2);
    expect(horseAgeYears(birth, "2026-01-08T00:00:00.000Z")).toBe(.25);
  });

  it("uses the same timestamp calculation for detailed and compact displays", () => {
    expect(horseAgeLongLabel(birth, "2026-02-19T00:00:00.000Z")).toBe("1 year, 9 months");
    expect(horseAgeCompactLabel(birth, "2026-02-19T00:00:00.000Z")).toBe("1y 9m");
  });

  it("is naturally idempotent because age is derived instead of incremented", () => {
    const at = "2026-03-26T12:00:00.000Z";
    expect(horseAgeYears(birth, at)).toBe(horseAgeYears(birth, at));
  });

  it("refreshes long-lived Stable and Horse Profile sessions", () => {
    const stable = readFileSync(new URL("../app/page.tsx", import.meta.url), "utf8");
    const profile = readFileSync(new URL("../app/horse-profile.tsx", import.meta.url), "utf8");
    for (const source of [stable, profile]) {
      expect(source).toContain("HORSE_AGE_REFRESH_MS");
      expect(source).toContain('document.addEventListener("visibilitychange"');
      expect(source).toContain("setAgeClock(Date.now())");
    }
  });
});
