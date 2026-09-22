import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const businesses = readFileSync("app/profession-businesses.tsx", "utf8");
const professions = readFileSync("app/professions.tsx", "utf8");
const page = readFileSync("app/page.tsx", "utf8");
const navigation = readFileSync("app/universal-game-navigation.tsx", "utf8");

describe("Profession destination rendering", () => {
  it("uses the universal navigation as the only top-level Profession selector", () => {
    expect(businesses).not.toContain("ProfessionNav");
    expect(professions).not.toContain("ProfessionNav");
  });

  it("renders direct Careers, Businesses, and Market destinations", () => {
    expect(professions).toContain('homeSection==="market"?"Find a Professional":"Careers"');
    expect(professions).toContain('new URL(path, "https://legacyequines.com")');
    expect(professions).toContain('professionUrl.searchParams.get("section")==="market"');
    expect(page).toContain('path={currentPath}');
    expect(professions).toContain('normalizedProfessionPath==="/professions/businesses"');
    expect(professions).not.toContain('location.pathname.match(/^\\/professions\\/businesses');
    expect(professions).toContain('<MyBusinesses notify={notify}/>');
  });

  it("keeps business pricing out of the Careers landing page", () => {
    const careersStart = professions.indexOf('{homeSection==="careers"&&<>');
    const marketStart = professions.indexOf('{homeSection==="market"&&');
    const careersLanding = professions.slice(careersStart, marketStart);
    expect(careersLanding).not.toContain("Set Your Rates");
    expect(businesses).toContain("Services & Pricing");
    expect(businesses).toContain("p_profession:professionId");
    expect(businesses).toContain('rpc("set_service_offering"');
  });

  it("routes every supported management workspace through the shared resolver", () => {
    expect(professions).toContain('normalizedProfessionPath.match(/^\\/professions\\/businesses\\/([^/]+)$/)');
    for (const profession of ["farrier", "veterinarian", "trainer", "massage", "leatherworker"]) {
      expect(`/professions/businesses/${profession}`).toMatch(/^\/professions\/businesses\/([^/]+)$/);
    }
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

  it("matches the market child only when the market section is in the URL", () => {
    expect(navigation).toContain('const current=new URL(path,"https://legacyequines.com")');
    expect(navigation).toContain('current.searchParams.get("section")===targetSection');
    expect(navigation).not.toContain('path.startsWith(`${itemPath}/`)');
  });
});
