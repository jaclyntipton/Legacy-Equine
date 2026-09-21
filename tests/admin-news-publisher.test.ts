import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";

const component = readFileSync("app/admin-news.tsx", "utf8");
const styles = readFileSync("app/admin-news.css", "utf8");

describe("Admin News publisher UX", () => {
  it("provides the newsroom library, editor, publication settings, and preview", () => {
    for (const text of ["News Library", "ARTICLE EDITOR", "Publish Date &amp; Time", "PUBLIC PREVIEW", "PREVIEW — NOT LIVE"]) expect(component).toContain(text);
  });
  it("supports article search and human-friendly filters", () => {
    expect(component).toContain('placeholder="Search articles..."');
    expect(component).toContain('["all", "draft", "published", "scheduled"]');
    expect(component).toContain("categories[post.category]");
  });
  it("tracks dirty state and protects article switching", () => {
    expect(component).toContain("Unsaved changes");
    expect(component).toContain("Discard changes and continue?");
    expect(component).toContain('addEventListener("beforeunload"');
  });
  it("updates an existing published record and confirms unpublish", () => {
    expect(component).toContain("p_id: form.id");
    expect(component).toContain("Update Published Article");
    expect(component).toContain("Unpublish this article?");
    expect(component).toContain('role="alertdialog"');
  });
  it("stacks the workspace without overflow on mobile", () => {
    expect(styles).toContain("grid-template-columns:minmax(230px,25%) minmax(420px,50%) minmax(230px,25%)");
    expect(styles).toContain("@media(max-width:700px)");
    expect(styles).toContain("grid-template-columns:1fr");
  });
});
