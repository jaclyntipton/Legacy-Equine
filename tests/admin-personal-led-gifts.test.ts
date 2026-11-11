import {describe,expect,it} from "vitest";
import fs from "node:fs";

const ui=fs.readFileSync("app/treasury.tsx","utf8");
const sql=fs.readFileSync("supabase/migrations/202611110004_admin_personal_led_gifts.sql","utf8");

describe("Admin personal LED gifts",()=>{
 it("uses the signed-in Admin's personal balance, not Treasury or Show Fund",()=>{
  expect(sql).toContain("set balance=balance-p_amount where id=v_sender.id");
  expect(sql).toContain("set balance=balance+p_amount where id=v_recipient.id");
  expect(sql).not.toContain("update public.system_funds");
  expect(ui).toContain('supabase.rpc("admin_gift_player_led"');
 });
 it("creates both ledger sides and an audit record",()=>{
  expect(sql.match(/insert into public\.currency_ledger/g)).toHaveLength(2);
  expect(sql).toContain("economy.player_led_gift");
  expect(sql).toContain("perform public.require_admin()");
 });
 it("is idempotent and confirms the exact gift before sending",()=>{
  expect(sql).toContain("request_id uuid not null unique");
  expect(sql).toContain("'idempotent',true");
  expect(ui).toContain("Confirm personal LED gift");
  expect(ui).toContain("Review Gift of");
 });
});
