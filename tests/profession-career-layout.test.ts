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
});
