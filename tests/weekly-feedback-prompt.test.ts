import{describe,expect,it}from"vitest";
import{readFileSync}from"node:fs";
const ui=readFileSync(new URL("../app/weekly-feedback-prompt.tsx",import.meta.url),"utf8"),css=readFileSync(new URL("../app/weekly-feedback-prompt.module.css",import.meta.url),"utf8"),shell=readFileSync(new URL("../app/page.tsx",import.meta.url),"utf8"),support=readFileSync(new URL("../app/support-center.tsx",import.meta.url),"utf8"),sql=readFileSync(new URL("../supabase/migrations/202611160001_weekly_beta_feedback_prompt.sql",import.meta.url),"utf8");
describe("weekly beta feedback prompt",()=>{
 it("waits for meaningful gameplay and avoids active dialogs",()=>{expect(ui).toContain("interactions.current<3");expect(ui).toContain("gameplayPath");expect(ui).toContain("[role=\"dialog\"]");expect(ui).toContain("2500")});
 it("offers share, weekly deferral, and permanent opt-out",()=>{for(const label of["Share Feedback","Maybe Later","Don&apos;t Ask Again"])expect(ui).toContain(label);expect(sql).toContain("interval'7 days'");expect(sql).toContain("opted_out")});
 it("persists cadence securely per authenticated player",()=>{expect(sql).toContain("stable_id=auth.uid()");expect(sql).toContain("pg_advisory_xact_lock");expect(sql).toContain("enable row level security");expect(sql).toContain("revoke all on table public.player_feedback_prompt_state from public,anon,authenticated")});
 it("opens the existing private support form prefilled for beta feedback",()=>{expect(ui).toContain("/support?feedback=1");expect(support).toContain('initialFeedback=params.get("feedback")==="1"');expect(support).toContain("Legacy Equine beta feedback")});
 it("is mounted globally and remains mobile friendly",()=>{expect(shell).toContain("<WeeklyFeedbackPrompt");expect(css).toContain("@media(max-width:480px)");expect(css).toContain("min-height:44px")});
});
