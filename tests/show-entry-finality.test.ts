import{describe,expect,it}from"vitest";
import{readFileSync}from"node:fs";

const migration=readFileSync("supabase/migrations/202609210003_show_entries_final_no_refunds.sql","utf8");
const admin=readFileSync("app/admin-shows.tsx","utf8");
const shows=readFileSync("app/shows-v2.tsx","utf8");

describe("final paid Show entries",()=>{
 it("runs any positive number of actual entries without a minimum",()=>{
  expect(migration).toContain("if entry_count=0 then");
  expect(migration).not.toMatch(/minimum_entries|min_entries|entry_count[<]=?\s*[123]/);
  expect(migration).toContain("where e.show_id=sh.id");
 });
 it("completes zero-entry Shows without a ledger write",()=>{
  const emptyBranch=migration.slice(migration.indexOf("if entry_count=0 then"),migration.indexOf("rank_no:=0"));
  expect(emptyBranch).toContain("completion_reason='no_entries'");
  expect(emptyBranch).not.toContain("currency_ledger");
  expect(shows).toContain('"Completed — No Entries"');
  expect(admin).toContain('"COMPLETED — NO ENTRIES"');
 });
 it("does not revalidate, remove, or refund accepted entries at execution",()=>{
  const processor=migration.slice(migration.indexOf("create or replace function public.process_due_player_shows"),migration.indexOf("-- Normal Shows cannot be cancelled"));
  expect(processor).not.toContain("revalidate_show_entries");
  expect(processor).not.toContain("delete from player_show_entries");
  expect(processor).not.toContain("refund");
 });
 it("rejects cancellation server-side and removes the Admin cancellation control",()=>{
  expect(migration).toContain("if p_action='cancel'then raise exception'Normal Shows cannot be cancelled; paid entries are final'");
  expect(admin).not.toContain(">Cancel Show<");
 });
 it("keeps purse funding scoped to accepted entry fees and explicit sponsorship",()=>{
  expect(migration).toContain("purse:=sh.entry_fee_purse+sh.show_fund_allocation+sh.treasury_allocation");
 });
});
