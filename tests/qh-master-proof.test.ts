import{describe,expect,it}from"vitest";
import{createHash}from"node:crypto";
import fs from"node:fs";
import sharp from"sharp";

const root="public/horse-visuals";
const mare=`${root}/masters/qh_mare_master_01.png`;
const stallion=`${root}/masters/qh_stallion_master_01.png`;
const coats=["sorrel","bay","black","palomino","buckskin"];
const sha=(path:string)=>createHash("sha256").update(fs.readFileSync(path)).digest("hex");

describe("approved Quarter Horse masters and coat proof",()=>{
 it("preserves the exact approved source files",()=>{
  expect(sha(mare)).toBe("23e79c1f3e61fd974feff11f51d78a407a4e6dc9f7ada5b47f49145f0a2bc72a");
  expect(sha(stallion)).toBe("d8c6c21ce376f004daae79ec6c1ddb714880b2db7fba62db6a98ec2529168486");
 });
 it("keeps every proof on the exact master canvas and alpha geometry",async()=>{
  const sourceMeta=await sharp(mare).metadata();
  const sourceAlpha=await sharp(mare).ensureAlpha().extractChannel(3).raw().toBuffer();
  const proofs=await Promise.all(coats.map(async coat=>({meta:await sharp(`${root}/proofs/qh_mare_master_01/${coat}.png`).metadata(),alpha:await sharp(`${root}/proofs/qh_mare_master_01/${coat}.png`).ensureAlpha().extractChannel(3).raw().toBuffer()})));
  for(const proof of proofs){
   expect(proof.meta.width).toBe(sourceMeta.width);expect(proof.meta.height).toBe(sourceMeta.height);
   expect(proof.alpha.equals(sourceAlpha)).toBe(true);
  }
 },15000);
 it("imports both masters as approved active immutable body templates",()=>{
  const sql=fs.readFileSync("supabase/migrations/202609150056_qh_approved_master_templates.sql","utf8");
  expect(sql).toContain("'qh_mare_master_01','body_template','Quarter Horse','Mare'");
  expect(sql).toContain("'qh_stallion_master_01','body_template','Quarter Horse','Stallion'");
  expect(sql).toContain("'approved',true");
  expect(sql).toContain("if old.immutable_source then raise exception");
 });
});
