import{describe,expect,it}from"vitest";
import{readFileSync}from"node:fs";
import{normalizeUsPhone}from"../lib/phone";
const ui=readFileSync("app/phone-verification.tsx","utf8"),signup=readFileSync("app/public-auth.tsx","utf8"),migration=readFileSync("supabase/migrations/202611110007_verified_phone_enrollment.sql","utf8");
const linked=readFileSync("supabase/migrations/202611110008_owner_linked_phone_verification.sql","utf8");
const announcement=readFileSync("supabase/migrations/202611110009_phone_verification_news.sql","utf8");
describe("verified phone enrollment",()=>{
 it("normalizes supported US phone formats",()=>{expect(normalizeUsPhone("(555) 555-0123")).toBe("+15555550123");expect(normalizeUsPhone("1-555-555-0123")).toBe("+15555550123");expect(normalizeUsPhone("555")).toBeNull()});
 it("requires a phone for new app signups and verifies the phone change OTP",()=>{expect(signup).toContain("pending_phone: normalizedPhone");expect(migration).toContain("require_legacy_equine_signup_phone");expect(migration).toContain("before insert on auth.users");expect(ui).toContain('type:"phone_change"');expect(ui).toContain("PhoneVerificationGate")});
 it("trusts only the Auth-confirmed phone when syncing",()=>{expect(migration).toContain("from auth.users where id=auth.uid()");expect(migration).toContain("phone_confirmed_at");expect(migration).not.toMatch(/sync_my_verified_phone\([^)]/)});
 it("privately links only the two approved Owner accounts without duplicating a phone",()=>{expect(linked).toContain("account_number in(1,2)");expect(linked).toContain("force row level security");expect(linked).toContain("revoke all");expect(linked).not.toContain("phone_e164=");expect(ui).toContain("get_my_phone_verification_status")});
 it("publishes the required announcement and blocks unverified gameplay with a modal",()=>{expect(announcement).toContain("Action Required: Verify Your Phone Number");expect(announcement).toContain("mandatory-phone-verification-2026");expect(announcement).toContain("Administrative Review");expect(ui).toContain("phoneverificationbackdrop");expect(ui).toContain("aria-modal=\"true\"")});
});
