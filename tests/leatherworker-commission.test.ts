import{describe,expect,it}from"vitest";
import fs from"node:fs";
const sql=fs.readFileSync("supabase/migrations/202609180002_leatherworker_custom_tack.sql","utf8");
const qaProvenance=fs.readFileSync("supabase/migrations/202609180004_leatherworker_test_identity_provenance.sql","utf8");
const ui=fs.readFileSync("app/professions.tsx","utf8");
const inventory=fs.readFileSync("app/stable-inventory.tsx","utf8");
describe("Leatherworker commission architecture",()=>{
 it("maps all four certificates to configured tack tiers and slots",()=>{
  for(const [level,tier,budget]of [[1,"Entry",1],[2,"Quality",2],[3,"Elite",3],[4,"Legendary",4]])expect(sql).toContain(`(${level},'${tier}',${budget},true)`);
  for(const slot of["bridle","saddle","saddle_pad","leg_protection"])expect(sql).toContain(`'${slot}'`);
 });
 it("server-validates Effective-only allocations",()=>{expect(sql).toContain("Invalid Effective Stat allocation");expect(sql).toContain("Allocate between 1 and % Effective Stat points");expect(sql).toContain("custom_tack_bonuses");});
 it("atomically pays the maker and delivers a Tack Room item",()=>{expect(sql).toContain("update stables set balance=balance-rate");expect(sql).toContain("update stables set balance=balance+rate");expect(sql).toContain("insert into currency_ledger");expect(sql).toContain("insert into player_store_items");expect(ui).toContain("purchase_leatherwork_commission");});
 it("snapshots branded and unbranded maker provenance",()=>{for(const field of["maker_brand_id","maker_brand_code","maker_stable_name","maker_account_number"])expect(sql).toContain(field);expect(inventory).toContain("Crafted by");});
 it("supports isolated QA makers without consuming public account numbers",()=>{expect(qaProvenance).toContain("maker_account_number drop not null");});
 it("counts only paid non-QA commissions for advancement",()=>{expect(sql).toContain("not owner_qa and client_id<>provider_id and price>0");});
});
