import{describe,expect,it}from"vitest";
import fs from"node:fs";
import path from"node:path";

const root=path.resolve(__dirname,"..");
const ui=fs.readFileSync(path.join(root,"app/professions.tsx"),"utf8");
const originalSql=fs.readFileSync(path.join(root,"supabase/migrations/202609170007_operational_professional_market.sql"),"utf8");
const sql=originalSql+fs.readFileSync(path.join(root,"supabase/migrations/202609170009_profession_qa_and_direct_batch_services.sql"),"utf8");
const qaGuard=fs.readFileSync(path.join(root,"supabase/migrations/202609170013_fix_owner_profession_qa_guard.sql"),"utf8");
const qaVerification=fs.readFileSync(path.join(root,"supabase/migrations/202609170014_verify_profession_qa_isolation.sql"),"utf8");

describe("operational Professional Market",()=>{
 it("exposes all four profession categories",()=>{for(const label of ["Farriers","Veterinarians","Trainers","Massage Therapists"])expect(ui).toContain(label)});
 it("connects saved rates to discoverability",()=>{expect(ui).toContain('from("player_service_offerings")');expect(ui).toContain('rpc("set_service_offering"');expect(sql).toContain("from player_service_offerings o");expect(sql).toContain("o.enabled and pp.available")});
 it("uses direct multi-horse review and payment",()=>{for(const label of ["Provider","Service","Horses","Review / Pay","SELECT ALL ELIGIBLE","PAY "])expect(ui).toContain(label);expect(ui).toContain('rpc("preview_professional_services"');expect(ui).toContain('rpc("purchase_professional_services"')});
 it("authoritatively validates and records real services",()=>{expect(sql).toContain("for update");expect(sql).toContain("client.balance<total");expect(sql).toContain("insert into currency_ledger");expect(sql).toContain("insert into horse_service_records");expect(sql).toContain("lifetime_client_services=lifetime_client_services+horse_count");expect(sql).toContain("request_key uuid not null unique")});
 it("preserves care windows and applies trainer development",()=>{expect(sql).toContain("profession_id='veterinarian'");expect(sql).toContain("profession_id in('farrier','massage')");expect(sql).toContain("age<2");expect(sql).toContain("last_trained_at+interval '20 hours'");expect(sql).toContain("stats=jsonb_set")});
 it("isolates Owner QA from progression and economy",()=>{expect(sql).toContain("public.is_owner_account()");expect(sql).toContain("'Owner QA'");expect(sql).toContain("grade_profession_qa_test");expect(sql).toContain("if not qa and total>0");expect(ui).toContain("OPEN QA CAREER")});
 it("exposes the complete career workspace",()=>{for(const label of ['"overview"','"study"','"test"','"services"','"history"','"rates"','"progression"',"Run as Normal Gameplay"])expect(ui).toContain(label)});
 it("preserves sequential careers and normal rate gating",()=>{expect(sql).toContain("Complete your current career through Professional");expect(ui).toContain("item.minimum_level<=p.level")});
 it("opens every QA career and level through a server-authorized read-only workspace",()=>{expect(qaGuard).toContain("has_admin_permission('admin.professions.qa',p_user)");expect(qaGuard).toContain("target_level not between 1 and 4");expect(qaGuard).toContain("'read_only',true");expect(ui).toContain('supabase.rpc("open_profession_qa_career"')});
 it("routes QA test questions and grading around normal enrollment without mutating progression",()=>{expect(ui).toContain('qa?"get_profession_qa_questions":"get_certification_questions"');expect(qaGuard).toContain("perform public.open_profession_qa_career");expect(qaGuard).not.toMatch(/insert into player_professions|update player_professions|currency_ledger/)});
 it("verifies all four levels server-side without changing Owner progression/economy and retains the normal guard",()=>{expect(qaVerification).toContain("for v_level in 1..4 loop");expect(qaVerification).toContain("before_progress<>after_progress or before_balance<>after_balance or before_ledger<>after_ledger");expect(qaVerification).toContain("Complete your current career through Professional before enrolling in another")});
});
