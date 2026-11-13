import{createHash}from"node:crypto";
import{readFileSync}from"node:fs";
import{describe,expect,it}from"vitest";

const root=new URL("../public/horse-visuals/vector-masters/qh_01/layers/phase1a_rev2/",import.meta.url);
const approval=JSON.parse(readFileSync(new URL("APPROVED.json",root),"utf8"));
const sql=readFileSync(new URL("../supabase/migrations/202611130009_qh_mare_phase1a_rev2.sql",import.meta.url),"utf8");
const hash=(name:string)=>createHash("sha256").update(readFileSync(new URL(name,root))).digest("hex");

describe("approved Quarter Horse mare Phase 1A Revision 2",()=>{
 it("preserves every approved SVG byte-for-byte",()=>{for(const[file,sha]of approval.layers)expect(hash(file)).toBe(sha)});
 it("remains bound to the exact approved master",()=>expect(approval.master_sha256).toBe("3e239ed8c0571b27b42219739329825ec87386528747379a3aa8081a2ff632f1"));
 it("registers all eight layers with multiply compositing",()=>{expect((sql.match(/'qh_mare_phase1a_/g)??[]).length).toBeGreaterThanOrEqual(8);expect(sql).toContain("'multiply','mature'");expect(sql).toContain("blend_mode in('normal','multiply')")});
 it("adds black leg points to the deterministic taxonomy",()=>{expect(sql).toContain("values('leg_points','black','Black Points'");expect(sql).toContain("a.asset_type='leg_points'")});
 it("keeps approved layers out of Production until the set is complete",()=>{expect(sql).toContain("status='approved'");expect(sql).not.toContain("status='production'");expect(approval.production_ready).toBe(false)});
});
