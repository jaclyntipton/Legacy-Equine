import {describe,expect,it} from "vitest";
import {readFileSync} from "node:fs";

const migration=readFileSync("supabase/migrations/202611170006_owner_treasury_contribution.sql","utf8");
const ui=readFileSync("app/treasury.tsx","utf8");

describe("Owner Treasury contribution",()=>{
 it("moves existing Owner LED atomically without minting",()=>{
  expect(migration).toContain("public.is_owner_account()");
  expect(migration).toContain("set balance=balance-p_amount");
  expect(migration).toContain("values(v_owner.id,-p_amount,'TREASURY_CONTRIBUTION: Legacy Equine Treasury')");
  expect(migration).toContain("set balance=balance+p_amount,lifetime_inflow=lifetime_inflow+p_amount");
 });
 it("is idempotent and fully audited",()=>{
  expect(migration).toContain("l.related_id=p_request_id");
  expect(migration).toContain("'treasury_contribution'");
  expect(migration).toContain("'treasury.owner_contribution'");
  expect(migration).toContain("'currency_ledger_id',v_currency_entry");
 });
 it("preserves exact bigint balances in the Owner workspace",()=>{
  expect(migration).toContain("public.get_owner_treasury_workspace()");
  expect(migration).toContain("'treasury_balance_exact',v_fund.balance::text");
  expect(ui).toContain("ownerTreasury.treasury_balance_exact");
 });
 it("provides an explicit Owner confirmation workflow",()=>{
  expect(ui).toContain("OWNER ACCOUNT → TREASURY");
  expect(ui).toContain("Add LED to the Legacy Equine Treasury");
  expect(ui).toContain("owner_contribute_to_treasury");
  expect(ui).toContain("Confirm Treasury transfer");
 });
});
