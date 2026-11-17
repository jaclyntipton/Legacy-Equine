import {readFileSync,readdirSync} from "node:fs";
import {describe,expect,it} from "vitest";

const compositor=readFileSync(new URL("../lib/game/horse-coat-compositor.ts",import.meta.url),"utf8");
const root=new URL("../public/horse-visuals/coat-layers/",import.meta.url);

describe("age-progressive grey rendering",()=>{
 it("smooths ordinary grey-stage pigment loss instead of rendering noise as flea bites",()=>{
  expect(compositor).toContain('layer.category==="gray"?"blur(12px)":"none"');
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
