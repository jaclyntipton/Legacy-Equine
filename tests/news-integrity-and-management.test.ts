import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";

const migration = readFileSync("supabase/migrations/202609220006_news_integrity_and_management.sql", "utf8");
const home = readFileSync("app/home-news.tsx", "utf8");
const styles = readFileSync("app/home-news.css", "utf8");

describe("News integrity and management", () => {
  it("enforces exactly one published primary pin and keeps older stories", () => {
    expect(migration).toContain("news_one_primary_pin_idx");
    expect(migration).toContain("where pinned and status='published'");
    expect(migration).not.toContain("delete from news_posts");
  });
  it("retains archived stories in Admin but excludes them from public News", () => {
    expect(migration).toContain("'archived'");
    expect(migration).toContain("set status='archived',pinned=false");
    expect(migration).toContain("n.status='published'");
  });
  it("returns one primary story separately and keeps Latest News chronological", () => {
    expect(migration).toContain("'primary_pinned'");
    expect(migration).toContain("order by coalesce(n.publish_at,n.published_at,n.created_at)desc,n.id desc");
    expect(home).toContain("primaryPinned&&");
  });
  it("bounds only the desktop feed while mobile remains in document flow", () => {
    expect(styles).toContain("@media(min-width:761px){.newsfeed");
    expect(styles).toContain("overflow-y:auto");
    expect(styles).toContain("overscroll-behavior:contain");
  });
});
