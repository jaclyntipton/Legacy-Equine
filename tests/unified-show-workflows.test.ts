import {describe,expect,it} from "vitest";
import fs from "node:fs";
import path from "node:path";

const root=path.resolve(process.cwd());
const sql=fs.readFileSync(path.join(root,"supabase/migrations/202609170003_unified_show_workflows_and_reconciliation.sql"),"utf8");
const ui=fs.readFileSync(path.join(root,"app/shows-v2.tsx"),"utf8");

describe("unified Show workflows",()=>{
 it("uses one creation RPC with quantity, scheduling, and per-Show audit rows",()=>{
  expect(ui).toContain('supabase.rpc("create_shows"');
  expect(ui).toContain("Number of Shows");
  expect(ui).not.toContain("Advanced Bulk Entry");
  expect(sql).toContain("creation_batch_id");
  expect(sql).toContain("for v_i in 1..p_count loop");
  expect(sql).toContain("'show_creation_fee'");
 });
 it("previews without mutation and confirms atomically with idempotency",()=>{
  const preview=sql.slice(sql.indexOf("function public.preview_show_entries"),sql.indexOf("function public.confirm_show_entries"));
  expect(preview).not.toMatch(/insert into|update stables|delete from/i);
  expect(sql).toContain("show_action_requests");
  expect(sql).toContain("for update");
  expect(sql).toContain("exception when unique_violation");
  expect(ui).toContain("Only authoritative eligible horse and Show pairs are selected");
  expect(ui).toContain("SELECT ALL ELIGIBLE");
 });
 it("allows many horses in one Show without requiring multi-Show capability",()=>{
  expect(sql).toContain("count(distinct x->>'show_id')");
 });
 it("records entry inflow and its exact purse allocation",()=>{
  expect(sql).toContain("'show_entry_fee'");
  expect(sql).toContain("'show_purse_allocation'");
  expect(sql).toContain("lifetime_inflow=lifetime_inflow+v_show.entry_fee,lifetime_outflow=lifetime_outflow+v_show.entry_fee");
 });
 it("reconciliation is evidence-linked, idempotent, and does not make historic purse money spendable",()=>{
  expect(sql).toContain("currency_ledger_id uuid primary key");
  expect(sql).toContain("Historical Show purse");
  expect(sql).toContain("if v_category='show_creation_fee'");
  expect(sql).toContain("lifetime_outflow=lifetime_outflow-v_row.amount");
 });
});
