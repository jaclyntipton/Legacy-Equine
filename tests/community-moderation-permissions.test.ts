import{readFileSync}from"node:fs";
import{describe,expect,it}from"vitest";

const chat=readFileSync("app/community-chat.tsx","utf8");
const hub=readFileSync("app/community-directory.tsx","utf8");
const base=readFileSync("supabase/migrations/202609150038_community_chat_rooms.sql","utf8");
const suspension=readFileSync("supabase/migrations/202611110002_chat_moderator_suspensions.sql","utf8");

describe("Community moderation permissions",()=>{
 it("lets moderators manage comments without granting room management",()=>{
  expect(hub).toContain('canModerate={isAdmin||communityRole==="moderator"');
  expect(chat).toContain("{canModerate && (");
  expect(chat).toContain("{isAdmin && (");
  expect(base).toContain("if not community_staff('admin') then raise exception 'Community Admin access required'");
 });
 it("supports audited timed and indefinite chat suspensions",()=>{
  expect(suspension).toContain("alter column expires_at drop not null");
  expect(suspension).toContain("mute_minutes=0");
  expect(suspension).toContain("m.expires_at is null or m.expires_at>now()");
  expect(suspension).toContain("user_chat_suspended");
  expect(chat).toContain("Suspend indefinitely");
  expect(chat).toContain("Apply to all chat rooms");
 });
 it("allows authorized staff to lift suspensions",()=>{
  expect(suspension).toContain("create or replace function public.unmute_chat_user");
  expect(suspension).toContain("if not community_staff()");
  expect(chat).toContain("Lift Active Chat Suspension");
 });
});
