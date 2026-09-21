import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const businesses = readFileSync("app/profession-businesses.tsx", "utf8");
const professions = readFileSync("app/professions.tsx", "utf8");
const page = readFileSync("app/page.tsx", "utf8");

describe("Profession destination rendering", () => {
  it("uses the universal navigation as the only top-level Profession selector", () => {
    expect(businesses).not.toContain("ProfessionNav");
    expect(professions).not.toContain("ProfessionNav");
  });

  it("renders direct Careers, Businesses, and Market destinations", () => {
    expect(professions).toContain('homeSection==="market"?"Find a Professional":"Careers"');
    expect(professions).toContain('location.pathname==="/professions/businesses"');
    expect(professions).toContain('<MyBusinesses notify={notify}/>');
  });

  it("keeps contextual help in the selected Profession page header", () => {
    expect(page).not.toContain('<><HandbookHelpLink slug="professions"/><ProfessionalCenter');
    expect(professions).toContain('<HandbookHelpLink slug="professions"/>');
    expect(businesses).toContain('<HandbookHelpLink slug="professions"/>');
  });

  it("never silently blanks while business data loads or fails", () => {
    expect(businesses).toContain("Loading your professional businesses…");
    expect(businesses).toContain("Businesses unavailable");
    expect(businesses).toContain("TRY AGAIN");
    expect(businesses).toContain("No professional businesses unlocked yet.");
  });
});
