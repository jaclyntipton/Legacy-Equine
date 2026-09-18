import{readFileSync}from"node:fs";import{describe,expect,it}from"vitest";
const dry=readFileSync("supabase/migrations/202609180013_record_historical_show_ap_dry_run.sql","utf8");
const apply=readFileSync("supabase/migrations/202609180014_apply_historical_show_ap_reconciliation.sql","utf8");
describe("one-time historical Show AP reconciliation",()=>{
 it("uses horse-specific authoritative result rows and fixed 3/2/1 awards",()=>{expect(dry).toContain("r.horse_id,r.placement");expect(apply).toContain("case r.placement when 1 then 3 when 2 then 2 when 3 then 1");expect(apply).not.toMatch(/stable.*(points|ap)/i)});
 it("excludes non-production and post-activation Shows",()=>{for(const sql of[dry,apply]){expect(sql).toContain("sh.status='complete'");expect(sql).toContain("not coalesce(sh.is_private,false)");expect(sql).toContain("not coalesce(sh.is_admin_qa,false)");expect(sql).toContain("coalesce(sh.processed_at,r.created_at)<")}});
 it("records one award per result and skips all existing awards",()=>{expect(apply).toContain("left join public.horse_ap_awards as a on a.show_result_id=r.id");expect(apply).toContain("a.show_result_id is null");expect(apply).toContain("on conflict(show_result_id)do nothing")});
 it("only raises available and lifetime-earned AP on the horse",()=>{expect(apply).toContain("allocatable_points=h.allocatable_points+c.points");expect(apply).toContain("lifetime_ap_earned=h.lifetime_ap_earned+c.points");expect(apply).not.toMatch(/set\s+stats=/i);expect(apply).not.toMatch(/set\s+career_points=/i)});
 it("verifies allocation, stats, and Career Points remain unchanged",()=>{expect(apply).toContain("h.lifetime_ap_allocated<>c.allocated_before");expect(apply).toContain("h.stats<>c.stats_before");expect(apply).toContain("h.career_points<>c.career_points_before")});
 it("fails closed if apply differs from dry run and proves a second pass awards zero",()=>{expect(apply).toContain("v_credited_results<>v_run.eligible_results");expect(apply).toContain("v_credited_ap<>v_run.total_ap");expect(apply).toContain("if v_second_run_ap<>0")});
});
