import{readFileSync}from"node:fs";
import{describe,expect,it}from"vitest";

const ui=readFileSync("app/bank.tsx","utf8");
const css=readFileSync("app/theme.css","utf8");
const sql=readFileSync("supabase/migrations/202609170008_fix_weekly_allowance_bigint.sql","utf8");

describe("LE Bank",()=>{
  it("supports bigint balances while preserving transactional collection",()=>{
    expect(sql).toContain("new_balance bigint");
    expect(sql).toContain("for update");
    expect(sql).toContain("status='collected'");
    expect(sql).toContain("insert into currency_ledger");
  });
  it("guards duplicate client submissions and reports collection failures",()=>{
    expect(ui).toContain("if(collecting)return");
    expect(ui).toContain("This weekly allowance has already been collected");
    expect(ui).toContain("We couldn't collect your weekly allowance");
  });
  it("keeps transaction history collapsed and internally scrollable",()=>{
    expect(ui).toContain('<details className="panel bankactivity">');
    expect(ui).toContain("bankhistoryscroll");
    expect(css).toContain(".bankhistoryscroll{max-height:390px;overflow-y:auto");
  });
});
