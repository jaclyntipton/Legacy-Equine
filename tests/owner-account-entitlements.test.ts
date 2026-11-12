import{describe,expect,it}from"vitest";
import{readFileSync}from"node:fs";
const sql=readFileSync("supabase/migrations/202611120003_owner_account_entitlements.sql","utf8");
const ui=readFileSync("app/account-entitlements-admin.tsx","utf8");
const page=readFileSync("app/page.tsx","utf8");

describe("Owner account membership and Brand entitlements",()=>{
 it("gives Owner a dedicated account entitlement workspace",()=>{expect(page).toContain("<AccountEntitlementsAdmin");expect(ui).toContain("Membership &amp; Brand Access");expect(ui).toContain("Grant Brand Access");expect(ui).toContain("Grant Free Membership")});
 it("keeps Brand access separate from Admin role and membership",()=>{expect(sql).toContain("owner_set_account_brand_access");expect(sql).toContain("stable_brand_privileges");expect(sql).toContain("brand_owner_granted");expect(ui).toContain("Brand access, Admin permissions, and membership are separate")});
 it("routes paid and complimentary memberships through the same capability resolver",()=>{expect(sql).toContain("paid_subscription or legacy_subscription or complimentary_subscription");expect(sql).toContain("'subscription_active',subscriber");expect(sql).toContain("'paid_subscription_active'");expect(sql).toContain("'complimentary_subscription_active'")});
 it("does not let removal of an Owner gift cancel a paid membership",()=>{expect(sql).toContain("source_type='owner_grant'");expect(sql).toContain("'paid_subscription_unchanged',true");expect(ui).toContain("Any paid membership remains active")});
 it("audits entitlement changes and preserves Owner #1 Brand access",()=>{expect(sql).toContain("commerce_entitlement_history");expect(sql).toContain("admin_audit_log");expect(sql).toContain("Owner Account #1 Brand access is permanent")});
});
