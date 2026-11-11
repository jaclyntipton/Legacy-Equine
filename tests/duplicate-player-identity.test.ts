import{describe,expect,it}from"vitest";
import{readFileSync}from"node:fs";
const migration=readFileSync("supabase/migrations/202611110006_prevent_duplicate_player_identity.sql","utf8");
const signup=readFileSync("app/public-auth.tsx","utf8");

describe("one person account guard",()=>{
 it("serializes and rejects duplicate normalized private identities",()=>{
  expect(migration.match(/pg_advisory_xact_lock/g)).toHaveLength(2);
  expect(migration.match(/regexp_replace\(lower/g)?.length).toBeGreaterThanOrEqual(8);
  expect(migration).toContain("i.date_of_birth=dob");
  expect(migration).toContain("i.account_id<>auth.uid()");
 });
 it("keeps private identity out of public signup availability",()=>expect(migration).not.toContain("public_signup_availability"));
 it("directs a rejected signup to account recovery instead of blaming the username",()=>{
  expect(signup).toContain("log in, reset your password, or contact Help & Support");
  expect(signup).not.toContain("Your username may already be unavailable");
 });
});
