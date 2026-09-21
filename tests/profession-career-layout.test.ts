import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

describe("routed profession career layout", () => {
  const layout = readFileSync("app/layout.tsx", "utf8");
  const careerLayout = readFileSync("app/profession-career-layout.css", "utf8");

  it("keeps the career workspace in normal document flow on mobile", () => {
    expect(layout).toContain('import "./profession-career-layout.css"');
    expect(careerLayout).toMatch(/\.careerworkspace\s*\{[^}]*max-height:\s*none/);
    expect(careerLayout).toMatch(/\.careerworkspace\s*\{[^}]*overflow:\s*visible/);
  });

  it("keeps every Profession destination and the footer in normal document flow", () => {
    const page = readFileSync("app/page.tsx", "utf8");
    expect(page).toContain('view === "professions" ? "profession-main"');
    expect(careerLayout).toMatch(/main\.profession-main\s*\{[^}]*flex:\s*1 0 auto/);
    expect(careerLayout).toMatch(/\.profession-main \+ footer\s*\{[^}]*position:\s*static/);
  });
});
