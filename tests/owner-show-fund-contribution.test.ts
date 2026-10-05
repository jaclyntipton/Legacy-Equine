import{readFileSync}from"node:fs";
import{describe,expect,it}from"vitest";

const migration=readFileSync("supabase/migrations/202610050002_owner_show_fund_contribution.sql","utf8");
const ui=readFileSync("app/treasury.tsx","utf8");

describe("Owner Show Fund contribution",()=>{
  it("moves existing Owner LED into the Show Fund without minting",()=>{
    expect(migration).toContain("update public.stables");
    expect(migration).toContain("set balance=balance-p_amount");
    expect(migration).toContain("insert into public.currency_ledger");
    expect(migration).toContain("values(v_owner.id,-p_amount,'SHOW_FUND_CONTRIBUTION: Legacy Equine Show Fund')");
    expect(migration).toContain("update public.system_funds");
    expect(migration).toContain("set balance=balance+p_amount");
    expect(migration).toContain("insert into public.system_fund_ledger");
    expect(migration).not.toContain("set balance=p_amount");
  });

  it("is Owner-only, idempotent, and granted only to authenticated callers",()=>{
    expect(migration).toContain("if not public.is_owner_account()");
    expect(migration).toContain("Owner Account #1 access required");
    expect(migration).toContain("transaction_type='show_fund_contribution'");
    expect(migration).toContain("related_id=p_request_id");
    expect(migration).toContain("revoke all on function public.owner_contribute_to_show_fund(bigint,uuid,text,text) from public");
    expect(migration).toContain("grant execute on function public.get_owner_show_fund_workspace(),public.owner_contribute_to_show_fund(bigint,uuid,text,text) to authenticated");
    expect(migration).not.toContain("to anon");
  });

  it("exposes a confirmation-first Owner funding control in Admin Economy",()=>{
    expect(ui).toContain("SHOW FUND");
    expect(ui).toContain("Current Show Fund Balance");
    expect(ui).toContain("Current Owner Account Balance");
    expect(ui).toContain("Auto Host Funding Requirement");
    expect(ui).toContain("Transfer ${fundAmount.toLocaleString()} LED");
    expect(ui).toContain("Owner Balance Before:");
    expect(ui).toContain("Show Fund After:");
    expect(ui).toContain('supabase.rpc("owner_contribute_to_show_fund"');
  });
});
