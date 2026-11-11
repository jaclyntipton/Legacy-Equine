import{readFileSync}from"node:fs";
import{describe,expect,it}from"vitest";

const sql=readFileSync("supabase/migrations/202611110001_sync_community_admin_authority.sql","utf8");
const chat=readFileSync("supabase/migrations/202609150038_community_chat_rooms.sql","utf8");

describe("Community Admin authority",()=>{
 it("uses the same authoritative Admin flag as the application shell",()=>{
  expect(sql).toContain("where is_admin");
  expect(sql).toContain("when 'admin' then s.is_admin or s.account_number=1");
  expect(sql).toContain("community_role in('admin','owner')");
 });
 it("keeps chat-room creation server-enforced for Admins only",()=>{
  expect(chat).toContain("if not community_staff('admin') then raise exception 'Community Admin access required'");
  expect(sql).toContain("revoke all on function public.community_staff(text) from public,anon,authenticated");
 });
});
