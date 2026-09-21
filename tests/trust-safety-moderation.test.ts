import{describe,expect,it}from"vitest";
import{readFileSync}from"node:fs";
const sql=readFileSync("supabase/migrations/202609210007_trust_safety_moderation.sql","utf8");
const pages=readFileSync("app/safety-pages.tsx","utf8");
const auth=readFileSync("app/public-auth.tsx","utf8");
const chat=readFileSync("app/community-chat.tsx","utf8");

describe("central content moderation architecture",()=>{
 it("keeps one private, forced-RLS rule bank",()=>{expect(sql).toContain("content_moderation_rules force row level security");expect(sql).toContain("revoke all on table public.content_moderation_rules");expect(sql).not.toMatch(/grant select on public\.content_moderation_rules to authenticated/)});
 it("covers every required safety category and action",()=>{for(const value of["sexual_explicit","sexual_solicitation","harassment","threats_violence","self_harm","hate","predatory","personal_information","spam_scam","warn","block","review","urgent_review"])expect(sql).toContain(value)});
 it("moderates Mailbox and Chat before insertion",()=>{expect(sql.indexOf("decision:=moderate_player_content(p_body")).toBeLessThan(sql.indexOf("insert into mailbox_messages"));expect(sql.indexOf("decision:=moderate_player_content(message_content")).toBeLessThan(sql.indexOf("insert into chat_messages"));expect(chat).toMatch(/if\s*\(!data\)/)});
 it("moderates every initial public-text surface",()=>{for(const fn of["update_stable_profile","save_public_stable_content","save_public_stable_customization","save_profession_business_profile"])expect(sql).toMatch(new RegExp(`function public\\.${fn}[\\s\\S]*?require_safe_player_content`))});
 it("preserves report/block primitives and support integration",()=>{const baseline=readFileSync("supabase/migrations/202609210006_account_safety_age_gate.sql","utf8");expect(baseline).toContain("block_mailbox_player");expect(baseline).toContain("report_mailbox_message");expect(baseline).toContain("support_tickets")});
 it("does not include ordinary equestrian terminology in rules",()=>{for(const term of["stallion","mare","breeding","stud fee","mount","saddle","gelding","in heat"])expect(sql.toLowerCase()).not.toContain(`'${term}'`)});
});

describe("privacy transparency",()=>{
 it("explains collection, purpose, visibility, access, and support",()=>{for(const phrase of["What we collect","Why we collect it","What other players can see","Who may access","/support"])expect(pages).toContain(phrase)});
 it("labels DOB as an age gate rather than identity verification",()=>expect(pages).toMatch(/age gate, not formal identity\s+verification/));
 it("links signup to Privacy & Safety",()=>expect(auth).toContain('href="/privacy-safety"'));
 it("does not publish the hidden moderation term bank",()=>expect(pages).not.toContain("content_moderation_rules"));
});
