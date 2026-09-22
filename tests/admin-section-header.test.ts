import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = process.cwd();
const css = readFileSync(resolve(root, "app/admin-section-header.css"), "utf8");
const news = readFileSync(resolve(root, "app/admin-news.tsx"), "utf8");
const handbook = readFileSync(resolve(root, "app/admin-handbook.tsx"), "utf8");

describe("reusable Admin section header", () => {
  it("uses high-contrast text and a distinct light primary action", () => {
    expect(css).toContain(".admin-section-header h1");
    expect(css).toContain("color: #fff !important");
    expect(css).toContain("background: #fff");
    expect(css).toContain("outline: 3px solid #ffd99f");
  });

  it("stacks the compact header safely on mobile", () => {
    expect(css).toContain("@media (max-width: 700px)");
    expect(css).toContain("flex-direction: column");
    expect(css).toContain("width: 100%");
  });

  it("is shared by News Publisher and How to Play", () => {
    expect(news).toContain('className="newsroom-header admin-section-header"');
    expect(news).toContain('className="primary admin-section-action"');
    expect(handbook).toContain("admintitle admin-section-header");
  });
});
