import {describe,expect,it} from "vitest";
import {resolveCoatLayers,type CoatLayer,type CoatManifest,type CoatRecipe} from "../lib/game/horse-coat-compositor";

const layer=(trait_key:string):CoatLayer=>({layer_id:`pinto:${trait_key}`,category:"pinto",trait_key,stacking_order:600,compositing_group:"erase",blend_mode:"normal",variant_for_base:null,leg:null,file:`${trait_key}.svg`});
const manifest:CoatManifest={master:{key:"qh_mare_master_01",asset_key:"qh_mare_vector_master_01"},canvas:{width:1496,height:1051},layers:[
 {layer_id:"base:bay",category:"base_coat",trait_key:"bay",stacking_order:100,compositing_group:"pigment",blend_mode:"multiply",variant_for_base:null,leg:null,file:"bay.svg"},
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
});
