import { describe, expect, it } from "vitest";
import fs from "node:fs";

const chat=fs.readFileSync("app/community-chat.tsx","utf8");
const chatMessageCss=fs.readFileSync("app/chat-message.css","utf8");
const page=fs.readFileSync("app/page.tsx","utf8");
const sql=fs.readFileSync("supabase/migrations/202611110003_chat_username_setup.sql","utf8");

describe("Community username setup",()=>{
 it("lets a signed-in player create the missing username directly in Chat Rooms",()=>{
  expect(chat).toContain('supabase.rpc("set_my_community_username"');
  expect(chat).toContain("Save Username & Start Chatting");
  expect(chat).toContain("activeUsername ?");
 });
 it("validates uniqueness and updates only the authenticated player's Stable",()=>{
  expect(sql).toContain("where id=auth.uid()");
  expect(sql).toContain("exception when unique_violation");
  expect(sql).toContain("to authenticated");
  expect(sql).toContain("from public,anon");
 });
 it("shows Community profile settings before private identity status",()=>{
  const settings=page.slice(page.lastIndexOf('{profileTab==="settings"'));
  expect(settings.indexOf("<SettingsView")).toBeLessThan(settings.indexOf("<AccountInformationPanel"));
 });
 it("reloads the authoritative room after a successful post instead of depending on realtime delivery",()=>{
  const send=chat.slice(chat.indexOf("const send = async"),chat.indexOf("const saveRoom"));
  expect(send).toContain('rpc("send_chat_message"');
  expect(send).toContain("await loadMessages()");
  expect(send).toContain('notify("Message posted.")');
  expect(chat).toContain('sending ? "Sending…" : "Send"');
 });
 it("keeps chat author metadata compact and readable",()=>{
  expect(chatMessageCss).toContain(".chatmessage header");
  expect(chatMessageCss).toContain("width: fit-content");
  expect(chatMessageCss).toContain("background: transparent");
  expect(chatMessageCss).toContain("color: #432d5f");
 });
 it("presents moderation controls as a cohesive responsive dialog",()=>{
  expect(chat).toContain('className="panel exam chatmoderation"');
  expect(chatMessageCss).toContain(".chatmoderation");
  expect(chatMessageCss).toContain("grid-template-columns: repeat(2, minmax(0, 1fr))");
  expect(chatMessageCss).toContain("max-height: min(760px, calc(100dvh - 28px))");
 });
});
