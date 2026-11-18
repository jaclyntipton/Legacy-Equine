import {describe,expect,it} from "vitest";
import {resolveCoatLayers,type CoatLayer,type CoatManifest,type CoatRecipe} from "../lib/game/horse-coat-compositor";

const layer=(category:string,trait_key:string,stacking_order:number):CoatLayer=>({layer_id:`${category}:${trait_key}`,category,trait_key,stacking_order,compositing_group:"top",blend_mode:"normal",variant_for_base:null,leg:null,file:`${trait_key}.svg`});
const manifest:CoatManifest={master:{key:"qh_mare_master_01",asset_key:"qh_mare_vector_master_01"},canvas:{width:1496,height:1051},layers:[
 layer("base_coat","bay",100),...['blanket','snowcap','spotted_blanket','leopard','fewspot','snowflake','frost','varnish_roan'].map(value=>layer("leopard_complex",value,620)),
 layer("visual_detail","mottled_skin",700),layer("visual_detail","striped_hooves",701),layer("visual_detail","visible_sclera",702),
]};
const recipe=(pattern:string):CoatRecipe=>({horse_id:"test",template_id:"qh_mare_vector_master_01",master_url:"/master.svg",custom_url:null,life_stage:"mature",traits:{underlying_base:"bay",leopard_complex:pattern,appaloosa_details:true},genetics:{},markings:{},modifiers:{}});

describe("Appaloosa deterministic coat layers",()=>{
 it.each([["leopard_01","leopard_complex:leopard"],["varnish_roan_01","leopard_complex:varnish_roan"]])("renders %s with breed details",(pattern,expected)=>{
  const selected=resolveCoatLayers(manifest,recipe(pattern)).map(value=>value.layer_id);
  expect(selected).toContain(expected);
  expect(selected).toEqual(expect.arrayContaining(["visual_detail:mottled_skin","visual_detail:striped_hooves","visual_detail:visible_sclera"]));
 });
 it.each([
  ["blanket_01","blanket"],["snowcap_01","snowcap"],["spotted_blanket_01","spotted_blanket"],
  ["leopard_01","leopard"],["few_spot_leopard","fewspot"],["snowflake_01","snowflake"],
  ["varnish_roan_01","varnish_roan"],["frost","frost"],["pintaloosa","spotted_blanket"],
 ])("maps approved Appaloosa pattern %s to registered art",(pattern,expected)=>{
  expect(resolveCoatLayers(manifest,recipe(pattern)).map(value=>value.layer_id)).toContain(`leopard_complex:${expected}`);
 });
 it("does not add Appaloosa layers when leopard complex is absent",()=>expect(resolveCoatLayers(manifest,recipe("none")).map(value=>value.layer_id)).toEqual(["base_coat:bay"]));
});
