import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
const sql = readFileSync("supabase/migrations/202609180023_authenticated_home_news.sql", "utf8");
const home = readFileSync("app/home-news.tsx", "utf8");
const auth = readFileSync("app/public-auth.tsx", "utf8");
const page = readFileSync("app/page.tsx", "utf8");
const styles = readFileSync("app/home-news.css", "utf8");
describe("authenticated Home News", () => {
  it("supports five categories, drafts, scheduling, pinning and expiration", () => {
    for (const value of ["official", "updates", "shows", "contests", "community", "draft", "published", "unpublished", "publish_at", "expires_at", "pinned"]) expect(sql).toContain(value);
  });
  it("uses a lightweight last-viewed cursor", () => {
    expect(sql).toContain("news_reader_state"); expect(sql).toContain("last_viewed_at"); expect(sql).not.toContain("news_post_reads");
  });
  it("sanitizes content and internal routes", () => {
    expect(sql).toContain("news_safe_text"); expect(sql).toContain("news_safe_destination");
  });
  it("publishes configured milestones without routine-show spam", () => {
    expect(sql).toContain("news_auto_rules"); expect(sql).toContain("horse_cp_milestone"); expect(sql).toContain("new.source<>'auto_host'"); expect(sql).toContain("new.feature_on_news");
  });
  it("provides compact feed, filters and quick links", () => {
    for (const value of ["Featured / Important", "Latest News", "Quick Links", "LOAD MORE"]) expect(home).toContain(value);
    for (const value of ["My Stable", "Enter Shows", "LE Store", "Marketplace", "Professions", "Community"]) expect(home).toContain(value);
    expect(styles).toContain("grid-template-columns:repeat(2,minmax(0,1fr))");
    expect(styles).toContain("overflow-x:auto");
    expect(styles).toContain("scrollbar-width:none");
    expect(home).toContain("filtersRef.current?.scrollTo({left:0})");
    expect(styles).toContain(".homeheadline h1{margin:.15rem 0;color:#3f286a");
  });
  it("labels News consistently in desktop and mobile game navigation", () => {
    expect(page.match(/`News · \$\{newsNew\} New`:\"News\"/)).toBeTruthy();
    expect(page).toContain('<NavIcon name="news"/>News');
  });
  it("redirects authentication to Home and exposes Home route", () => {
    expect(auth).not.toContain('"/stable/horses"'); expect(auth).toContain('"/home"'); expect(page).toContain('"home"');
  });
});
