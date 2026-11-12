import { describe, expect, it } from "vitest";
import fs from "node:fs";

const sql = fs.readFileSync(
  "supabase/migrations/202611120001_private_last_active_visibility.sql",
  "utf8",
);
const profile = fs.readFileSync("app/community-directory.tsx", "utf8");
const page = fs.readFileSync("app/page.tsx", "utf8");

describe("private player last-active visibility", () => {
  it("allows players to update only their own activity timestamp", () => {
    expect(sql).toContain("where id = auth.uid()");
    expect(sql).toContain("last_active_at < clock_timestamp() - interval '2 minutes'");
    expect(sql).toContain("grant execute on function public.touch_my_last_active() to authenticated");
  });

  it("returns activity only to the player or authorized Community staff", () => {
    expect(sql).toContain("auth.uid() = s.id");
    expect(sql).toContain("viewer.community_role in ('moderator', 'admin', 'owner')");
    expect(sql).toContain("case when can_view_activity then s.last_active_at else null end");
  });

  it("does not add last-active information to the public directory", () => {
    const directoryFunction = fs.readFileSync(
      "supabase/migrations/202609170020_community_player_stable_directory.sql",
      "utf8",
    ).split("create or replace function public.get_public_player_profile")[0];
    expect(directoryFunction).not.toContain("last_active_at");
  });

  it("renders the timestamp for self and authorized staff when supplied", () => {
    expect(profile).toContain("player.last_active_at");
    expect(page).toContain("stable.last_active_at");
    expect(page).toContain("a.last_active_at");
  });
});
