import{describe,expect,it}from"vitest";
import fs from"node:fs";
const ui=fs.readFileSync("app/professions.tsx","utf8");
const sql=fs.readFileSync("supabase/migrations/202609170028_profession_persistence_reconciliation.sql","utf8");
describe("authoritative Profession persistence",()=>{
 it("uses temporary QA level only while normal gameplay is off",()=>{expect(ui).toContain("const qa = career.qa && !runNormal");expect(ui).toContain("const level = qa ? qaLevel");expect(ui).toContain("const rateLevel = qa ? qaLevel : p.level")});
 it("returns to the permanent career route after a real passed test",()=>{expect(ui).toContain("`/professions/${testing.id}`");expect(ui).toContain("setCareer({ id: testing.id, qa: false })")});
 it("reconciles certificates only from passed permanent attempts",()=>{expect(sql).toContain("certification_attempts a");expect(sql).toContain("a.passed");expect(sql).toContain("QA grading never writes certification_attempts")});
 it("reconciles rates only from enabled in-range persistent offerings",()=>{expect(sql).toContain("o.enabled and o.price between sc.min_price and sc.max_price");expect(sql).toContain("having count(*)=count(o.service_id)")});
 it("exposes a server-side persistence snapshot",()=>{expect(sql).toContain("get_my_profession_persistence");expect(sql).toContain("player_profession_certifications");expect(sql).toContain("player_service_offerings")});
});
