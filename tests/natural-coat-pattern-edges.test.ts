import fs from"node:fs";
import path from"node:path";
import{describe,expect,it}from"vitest";

const traits=["tobiano","frame_overo","sabino","splash_white","tovero","lp_blanket","lp_snowcap","lp_spotted_blanket","lp_leopard","lp_varnish_roan"];

describe("natural coat-pattern edges",()=>{
 for(const sex of["mare","stallion"]){
  it(`${sex} pattern masks use anatomy-clipped organic edge displacement`,()=>{
   const master=`qh_${sex}_master_01`;
   for(const trait of traits){
    const svg=fs.readFileSync(path.join(process.cwd(),"public/horse-visuals/coat-layers",master,"layers",`${master}__${trait}.svg`),"utf8");
    expect(svg).toContain("<feTurbulence");
    expect(svg).toContain("<feDisplacementMap");
    expect(svg).toContain('<feComponentTransfer in="displaced">');
    expect(svg).toContain('<feFuncA type="discrete" tableValues="0 0 1 1"/>');
    expect(svg).toMatch(new RegExp(`<g id="${master}__${trait}__coat"[^>]+filter="url\\(#${master}__${trait}__organic-edge\\)"`));
    expect(svg).toContain(`mask="url(#${master}__${trait}__mask-anatomy)"`);
   }
  });
 }
});
