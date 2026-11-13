import{readFileSync}from"node:fs";
import{describe,expect,it}from"vitest";

const approval=JSON.parse(readFileSync(new URL("../public/horse-visuals/approvals/2026-11-13-twh-rmh-coat-layers.json",import.meta.url),"utf8"));

describe("Owner-approved TWH and RMH coat-layer packages",()=>{
 it("records all four exact master sets",()=>expect(approval.sets).toHaveLength(4));
 it("records all 442 approved layers",()=>expect(approval.sets.reduce((sum:number,set:{layer_count:number})=>sum+set.layer_count,0)).toBe(442));
 it("pins every package and master by SHA-256",()=>{for(const set of approval.sets){expect(set.package_sha256).toMatch(/^[a-f0-9]{64}$/);expect(set.master_sha256).toMatch(/^[a-f0-9]{64}$/)}});
 it("does not falsely activate incomplete composites",()=>expect(approval.activation).toBe("approved_pending_full_layer_import"));
});
