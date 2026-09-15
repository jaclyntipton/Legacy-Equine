import{describe,expect,it}from"vitest";
import fs from"node:fs";

const migration=fs.readFileSync("supabase/migrations/202609150055_owner_unlimited_and_unlimited_store_purchases.sql","utf8");
const currentPurchase=fs.readFileSync("supabase/migrations/202609150047_stable_capacity_and_sanctuary.sql","utf8").split("create or replace function public.purchase_store_horse")[1].split("create or replace function public.buy_marketplace_horse")[0];

describe("store purchase and owner capacity policy",()=>{
 it("treats Foundation purchase count as history rather than an eligibility gate",()=>{
  expect(migration).toContain("never an eligibility limit");
  expect(currentPurchase).not.toMatch(/foundation_purchases\s*(?:>=|>)\s*\d/);
  expect(currentPurchase).not.toContain("Foundation purchase limit reached");
 });
 it("keeps transactional balance and stall checks for ordinary accounts",()=>{
  expect(currentPurchase).toContain("perform require_available_stall(s.id)");
  expect(currentPurchase).toContain("if s.balance<item.price");
 });
 it("makes Account #1 intrinsically and permanently unlimited",()=>{
  expect(migration).toContain("account_number=1");
  expect(migration).toContain("allocation_unlimited or coalesce(s.owner_unlimited,false)");
  expect(migration).toContain("Account #1 has permanent unlimited stable capacity");
 });
});
