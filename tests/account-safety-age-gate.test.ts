import{describe,expect,it}from"vitest";
import{readFileSync}from"node:fs";
import{isAtLeast18,parseCalendarDate}from"../lib/account-safety";
const migration=readFileSync("supabase/migrations/202609210006_account_safety_age_gate.sql","utf8");
const signup=readFileSync("app/public-auth.tsx","utf8");
const community=readFileSync("app/community-directory.tsx","utf8");

describe("18+ calendar eligibility",()=>{
 const today=new Date(Date.UTC(2026,8,21));
 it("accepts the exact 18th birthday",()=>expect(isAtLeast18("2008-09-21",today)).toBe(true));
 it("rejects one day before the 18th birthday",()=>expect(isAtLeast18("2008-09-22",today)).toBe(false));
 it("rejects future and malformed dates",()=>{expect(isAtLeast18("2027-01-01",today)).toBe(false);expect(parseCalendarDate("2008-02-30")).toBeNull();expect(parseCalendarDate("")).toBeNull()});
 it("handles leap-day birthdays consistently",()=>{expect(isAtLeast18("2008-02-29",new Date(Date.UTC(2026,1,28)))).toBe(false);expect(isAtLeast18("2008-02-29",new Date(Date.UTC(2026,2,1)))).toBe(true)});
});

describe("authoritative account safety",()=>{
 it("validates DOB in both preflight and auth-user trigger",()=>{expect(signup).toContain("public_signup_availability");expect(migration).toContain("initialize_new_auth_player");expect(migration.match(/account_is_adult\(/g)?.length).toBeGreaterThanOrEqual(4)});
 it("keeps private identity behind forced RLS and audited Admin access",()=>{expect(migration).toContain("account_private_identity force row level security");expect(migration).toContain("accounts.private_identity.viewed");expect(migration).toContain("accounts.private_identity.corrected")});
 it("uses one social eligibility check for Mailbox and Community Chat",()=>{expect(migration).toContain("send_mailbox_message");expect(migration).toContain("block_mailbox_player");expect(migration).toContain("report_mailbox_message");expect(migration.match(/perform require_social_eligibility\(\)/g)?.length).toBeGreaterThanOrEqual(6);expect(community).toContain("SocialEligibilityGate")});
 it("stores no uploaded government identity artifact",()=>expect(migration.toLowerCase()).not.toMatch(/passport|driver.?s license|government.?id/));
});
