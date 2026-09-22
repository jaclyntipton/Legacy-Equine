import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const migration = readFileSync("supabase/migrations/202609220001_scheduled_news_publisher.sql", "utf8");
const route = readFileSync("app/api/cron/publish-news/route.ts", "utf8");
const admin = readFileSync("app/admin-news.tsx", "utf8");
const vercel = JSON.parse(readFileSync("vercel.json", "utf8"));

describe("scheduled News publishing", () => {
  it("registers an authenticated, uncached production scheduler", () => {
    expect(vercel.crons).toContainEqual({ path: "/api/cron/publish-news", schedule: "*/5 * * * *" });
    expect(route).toContain("process.env.CRON_SECRET");
    expect(route).toContain('"Cache-Control": "no-store"');
    expect(route).toContain('rpc("process_due_news")');
  });

  it("publishes every overdue scheduled row idempotently", () => {
    expect(migration).toContain("n.status='scheduled'");
    expect(migration).toContain("n.publish_at<=now()");
    expect(migration).toContain("n.id=any(due_ids)");
    expect(migration).toContain("news_publish_runs");
  });

  it("stores a real scheduled state and shows overdue status", () => {
    expect(admin).toContain('save(form.publish_at && new Date(form.publish_at).getTime() > Date.now() ? "scheduled" : "published")');
    expect(admin).toContain('"Publication overdue"');
    expect(admin).toContain('timeZone: "America/New_York"');
  });
});
