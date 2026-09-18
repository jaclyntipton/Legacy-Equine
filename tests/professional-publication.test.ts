import { describe, expect, it } from "vitest";
import fs from "node:fs";

const sql = fs.readFileSync(
  "supabase/migrations/202609170026_publish_certified_professional_services.sql",
  "utf8",
);
const market = fs.readFileSync("app/professions.tsx", "utf8");
const player = fs.readFileSync("app/community-directory.tsx", "utf8");
const stable = fs.readFileSync("app/public-stable-profile.tsx", "utf8");
const stableCss = fs.readFileSync("app/public-stable-profile.css", "utf8");

describe("certified professional publication", () => {
  it("publishes only earned, authorized, valid-rate services", () => {
    expect(sql).toContain("player_profession_certifications");
    expect(sql).toContain("earned.level>=sc.minimum_level");
    expect(sql).toContain("o.enabled and o.price between sc.min_price and sc.max_price");
  });

  it("removes Owner QA fallback from the normal market", () => {
    const directory = sql.slice(
      sql.indexOf("create function public.get_service_directory"),
      sql.indexOf("create or replace function public.get_public_player_profile"),
    );
    expect(directory).not.toContain("Owner QA");
    expect(directory).not.toContain("union all");
    expect(directory).toContain("false");
  });

  it("uses one service projection for both public profiles", () => {
    expect(sql.match(/get_public_professional_services\(/g)?.length).toBeGreaterThanOrEqual(3);
    expect(player).toContain("Professional Services");
    expect(stable).toContain("Professional Services");
    expect(player).toContain("VIEW SERVICES / HIRE PROFESSIONAL");
    expect(stable).toContain("VIEW SERVICES / HIRE PROFESSIONAL");
  });

  it("deep-links the existing direct-purchase flow with provider and service selected", () => {
    for (const source of [player, stable]) {
      expect(source).toContain("provider=${service.provider_id}");
      expect(source).toContain("service=${service.service_id}");
    }
    expect(market).toContain('params.get("provider")');
    expect(market).toContain('params.get("service")');
    expect(market).toContain('setRequest({ providerId, serviceId: selected })');
  });

  it("keeps public service rows readable at phone width", () => {
    expect(stableCss).toContain(".publicservice{align-items:flex-start;flex-direction:column}");
  });
});
