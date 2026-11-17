import {readFileSync,readdirSync} from "node:fs";
import {describe,expect,it} from "vitest";
import {grayStageOpacity} from "../lib/game/horse-coat-compositor";

const compositor=readFileSync(new URL("../lib/game/horse-coat-compositor.ts",import.meta.url),"utf8");
const root=new URL("../public/horse-visuals/coat-layers/",import.meta.url);

describe("age-progressive grey rendering",()=>{
 it("uses the clean body mask instead of noisy grey artwork for ordinary age stages",()=>{
  expect(compositor).toContain('const source=layer.category==="gray"&&body?body:layer');
  expect(compositor).not.toContain('blur(12px)');
 });
 it("lightens progressively without treating normal grey as flea-bitten",()=>{
  expect(["early","mid","dapple","late","white"].map(grayStageOpacity)).toEqual([.18,.38,.58,.78,.94]);
 });
 it("keeps every registered master on the shared grey-stage path",()=>{
  const masters=readdirSync(root).filter(name=>readdirSync(new URL(`${name}/`,root)).includes("manifest.json"));
  for(const name of masters){
   const manifest=JSON.parse(readFileSync(new URL(`${name}/manifest.json`,root),"utf8")) as {layers:{category:string;trait_key:string;compositing_group:string}[]};
   const greys=manifest.layers.filter(layer=>layer.category==="gray");
   expect(greys.length).toBeGreaterThan(0);
   if(!name.includes("foal"))expect(greys.map(layer=>layer.trait_key).sort()).toEqual(["dapple","early","late","mid","white"]);
   expect(greys.every(layer=>layer.compositing_group==="erase")).toBe(true);
  }
 });
});
