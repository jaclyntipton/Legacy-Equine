import{createHash}from"node:crypto";
import{readFileSync}from"node:fs";
import{fileURLToPath}from"node:url";
import{describe,expect,it}from"vitest";
import sharp from"sharp";

const root=new URL("../public/horse-visuals/vector-masters/arabian_01/",import.meta.url);
const approval=JSON.parse(readFileSync(new URL("APPROVED.json",root),"utf8"));
const sourceHash=(name:string)=>createHash("sha256").update(readFileSync(new URL(name,root))).digest("hex");
const required=["horse","body","head","neck","mane","tail","eyes","hooves","legs","marking-regions","tack-anchors","body-base","body-highlight","body-shadow","head-base","muzzle","ear-left","ear-right","eye-left","eye-right","mane-base","tail-base","leg-lf","leg-rf","leg-lh","leg-rh","hoof-lf","hoof-rf","hoof-lh","hoof-rh","face-forehead","face-bridge","face-muzzle","pattern-neck","pattern-shoulder","pattern-barrel","pattern-belly","pattern-hindquarter","marking-leg-lf","marking-leg-rf","marking-leg-lh","marking-leg-rh"];

describe("Owner-approved Arabian vector masters",()=>{
 it("preserves every approved SVG byte-for-byte",()=>{for(const master of approval.masters)expect(sourceHash(master.file)).toBe(master.sha256)});
 it("uses the registered canvas and safe standalone SVG structure",()=>{for(const master of approval.masters){const svg=readFileSync(new URL(master.file,root),"utf8"),ids=[...svg.matchAll(/\bid="([^"]+)"/g)].map(match=>match[1]);expect(svg).toContain('viewBox="0 0 1496 1051"');expect(new Set(ids).size).toBe(ids.length);for(const id of required)expect(ids).toContain(id);expect(svg).not.toMatch(/<(?:script|image|foreignObject|text)\b/i);expect(svg).not.toMatch(/\btransform=/);expect(svg).not.toMatch(/\b(?:href|xlink:href)="(?!#)/i)}});
 it("ships exact-size transparent previews",async()=>{for(const master of approval.masters){const preview=master.file.replace(".svg","_preview.png"),meta=await sharp(fileURLToPath(new URL(preview,root))).metadata();expect(meta).toMatchObject({width:1496,height:1051,hasAlpha:true})}});
 it("records that no Arabian foal master was supplied",()=>expect(approval.foal_master_supplied).toBe(false));
 it("registers approved immutable mature masters without bypassing readiness",()=>{const sql=readFileSync(new URL("../supabase/migrations/202611130005_arabian_vector_masters_01.sql",import.meta.url),"utf8");expect(sql).toContain("'approved',true");expect(sql).toContain("immutable_source");expect(sql).toContain("horse_visual_asset_requirements");expect(sql).toContain("'mature'");expect(sql).not.toContain("image_url=excluded.image_url")});
});
