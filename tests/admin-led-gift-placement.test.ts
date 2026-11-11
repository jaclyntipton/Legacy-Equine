import {describe,expect,it} from "vitest";
import fs from "node:fs";

const page=fs.readFileSync("app/page.tsx","utf8");
const gift=fs.readFileSync("app/admin-led-gift.tsx","utf8");
const treasury=fs.readFileSync("app/treasury.tsx","utf8");
const sql=fs.readFileSync("supabase/migrations/202611110005_admin_led_gift_workspace.sql","utf8");

describe("Personal LED gift placement",()=>{
 it("places personal gifts in Admin Accounts",()=>{
  expect(page).toContain('topic==="accounts"');
  expect(page).toContain("<AdminLedGift");
  expect(gift).toContain("ADMIN → ACCOUNTS → PLAYER GIFT");
 });
 it("keeps Treasury controls institutional",()=>{
  expect(treasury).toContain("treasury_award");
  expect(treasury).not.toContain("admin_gift_player_led");
 });
 it("loads the exact personal balance and excludes the sender",()=>{
  expect(sql).toContain("'balance_exact',source.balance::text");
  expect(sql).toContain("s.id<>source.id");
  expect(gift).toContain("This never uses Treasury or Show Fund money");
 });
});
