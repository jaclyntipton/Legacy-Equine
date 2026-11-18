import {describe,expect,it} from "vitest";
import {pintoVariationPlan,resolveCoatLayers,type CoatLayer,type CoatManifest,type CoatRecipe} from "../lib/game/horse-coat-compositor";

const layer=(trait_key:string):CoatLayer=>({layer_id:`pinto:${trait_key}`,category:"pinto",trait_key,stacking_order:600,compositing_group:"erase",blend_mode:"normal",variant_for_base:null,leg:null,file:`${trait_key}.svg`});
const manifest:CoatManifest={master:{key:"qh_mare_master_01",asset_key:"qh_mare_vector_master_01"},canvas:{width:1496,height:1051},layers:[
 {layer_id:"base:bay",category:"base_coat",trait_key:"bay",stacking_order:100,compositing_group:"pigment",blend_mode:"multiply",variant_for_base:null,leg:null,file:"bay.svg"},
 {layer_id:"dilution:cream_single:bay",category:"dilution",trait_key:"cream_single",stacking_order:200,compositing_group:"pigment",blend_mode:"multiply",variant_for_base:"bay",leg:null,file:"cream.svg"},
 {layer_id:"dilution:dun:bay",category:"dilution",trait_key:"dun",stacking_order:210,compositing_group:"pigment",blend_mode:"multiply",variant_for_base:"bay",leg:null,file:"dun.svg"},
 {layer_id:"roan:roan",category:"roan",trait_key:"roan",stacking_order:400,compositing_group:"pigment",blend_mode:"normal",variant_for_base:null,leg:null,file:"roan.svg"},
 layer("tobiano"),layer("frame_overo"),layer("sabino"),layer("splash_white"),layer("tovero"),
]};
const recipe=(patterns:string[]):CoatRecipe=>({horse_id:"paint",template_id:"qh_mare_vector_master_01",master_url:"/master.svg",custom_url:null,life_stage:"mature",traits:{underlying_base:"bay",pinto_patterns:patterns},genetics:{},markings:{},modifiers:{}});

describe("Paint pattern composition",()=>{
 it("uses the deliberate Tovero artwork for Tobiano plus an overo-family pattern",()=>{
  const selected=resolveCoatLayers(manifest,recipe(["tobiano","frame_overo"])).map(value=>value.layer_id);
  expect(selected).toContain("pinto:tovero");
  expect(selected).not.toContain("pinto:tobiano");
  expect(selected).not.toContain("pinto:frame_overo");
 });
 it("uses Tovero for multi-pattern Paint combinations without stacking masks",()=>{
  const selected=resolveCoatLayers(manifest,recipe(["tobiano","sabino","splashed white"])).map(value=>value.layer_id);
  expect(selected.filter(value=>value.startsWith("pinto:"))).toEqual(["pinto:tovero"]);
 });
 it.each(["tobiano","frame_overo","sabino","splash_white"])("keeps the single %s pattern distinct",pattern=>expect(resolveCoatLayers(manifest,recipe([pattern])).map(value=>value.layer_id)).toContain(`pinto:${pattern}`));
 it("normalizes approved reference aliases",()=>expect(resolveCoatLayers(manifest,recipe(["overo"])).map(value=>value.layer_id)).toContain("pinto:frame_overo"));
 it("does not activate absent cream, dun, or roan modifiers",()=>{
  const selected=resolveCoatLayers(manifest,recipe(["tobiano"])).map(value=>value.layer_id);
  expect(selected).toContain("base:bay");
  expect(selected).toContain("pinto:tobiano");
  expect(selected).not.toContain("dilution:cream_single:bay");
  expect(selected).not.toContain("dilution:dun:bay");
  expect(selected).not.toContain("roan:roan");
 });
 it("gives each horse a stable, bounded expression variation",()=>{
  const first=pintoVariationPlan("horse-alpha"),repeat=pintoVariationPlan("horse-alpha"),second=pintoVariationPlan("horse-beta");
  expect(first).toEqual(repeat);
  expect(second).not.toEqual(first);
  expect(first).toHaveLength(4);
  expect(first.map(value=>value.kind)).toEqual(["white","white","white","white"]);
  for(const patch of [...first,...second]){expect(patch.x).toBeGreaterThanOrEqual(240);expect(patch.x).toBeLessThanOrEqual(1120);expect(patch.y).toBeGreaterThanOrEqual(240);expect(patch.y).toBeLessThanOrEqual(540)}
 });
});
