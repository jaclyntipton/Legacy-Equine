import{readFileSync}from"node:fs";
import{describe,expect,it}from"vitest";

const migration=readFileSync("supabase/migrations/202610050001_auto_host_insufficient_show_fund_reporting.sql","utf8");

describe("Auto Host funding shortage reporting",()=>{
  it("reports insufficient Show Fund as an explicit non-creation state",()=>{
    expect(migration).toContain("'status','insufficient_show_fund'");
    expect(migration).toContain("'required_show_fund',v_required");
    expect(migration).toContain("'available_show_fund',v_available");
    expect(migration).toContain("'shortfall',v_required-v_available");
    expect(migration).toContain("'auto_host_funding_blocked'");
    expect(migration).toContain("'created',0");
    expect(migration).toContain("'errors',0");
  });

  it("keeps Auto Host execution server-side after the funding diagnostic patch",()=>{
    expect(migration).toContain("revoke all on function public.run_show_auto_host(text,text,uuid)from public");
    expect(migration).toContain("grant execute on function public.run_show_auto_host(text,text,uuid)to service_role");
    expect(migration).not.toContain("grant execute on function public.run_show_auto_host(text,text,uuid)to authenticated");
    expect(migration).not.toContain("grant execute on function public.run_show_auto_host(text,text,uuid)to anon");
  });
});
