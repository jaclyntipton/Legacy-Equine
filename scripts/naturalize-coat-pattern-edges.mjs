import{createHash}from"node:crypto";
import{readFileSync,writeFileSync}from"node:fs";
import{join}from"node:path";

const root=process.cwd();
const patterns=[
 ["tobiano",28,17],["frame_overo",24,23],["sabino",18,31],["sabino_roaning",14,37],
 ["splash_white",18,41],["medicine_hat",22,43],["tovero",26,47],
 ["lp_blanket",24,59],["lp_snowcap",24,61],["lp_spotted_blanket",22,67],
 ["lp_leopard",10,71],["lp_fewspot",10,73],["lp_snowflake",8,79],["lp_varnish_roan",15,83]
];
const sha=value=>createHash("sha256").update(value).digest("hex");

for(const sex of["mare","stallion"]){
 const master=`qh_${sex}_master_01`;
 const directory=join(root,"public/horse-visuals/coat-layers",master);
 const manifestPath=join(directory,"manifest.json");
 let manifest=readFileSync(manifestPath,"utf8");
 for(const[trait,scale,seed]of patterns){
  const layerId=`${master}__${trait}`;
  const filePath=join(directory,"layers",`${layerId}.svg`);
  const original=readFileSync(filePath,"utf8");
  const oldHash=sha(original);
  const filterId=`${layerId}__organic-edge`;
  const filter=`<filter id="${filterId}" x="-4%" y="-4%" width="108%" height="108%" color-interpolation-filters="sRGB"><feTurbulence type="fractalNoise" baseFrequency="0.014 0.021" numOctaves="2" seed="${seed}" result="edgeNoise"/><feDisplacementMap in="SourceGraphic" in2="edgeNoise" scale="${scale}" xChannelSelector="R" yChannelSelector="G" result="displaced"/><feComponentTransfer in="displaced"><feFuncA type="discrete" tableValues="0 0 1 1"/></feComponentTransfer></filter>`;
  let next=original;
  if(next.includes(filterId))next=next.replace(new RegExp(`<filter id="${filterId}"[^]*?</filter>`),filter);
  else next=next.replace("<defs>",`<defs>\n${filter}`);
  next=next.replace(new RegExp(`(<g id="${layerId}__coat"[^>]*?)(?: filter="[^"]+")?>`),`$1 filter="url(#${filterId})">`);
  if(next===original)throw new Error(`No render group updated for ${layerId}`);
  writeFileSync(filePath,next);
  const newHash=sha(next);
  const occurrence=`"sha256": "${oldHash}"`;
  if(!manifest.includes(occurrence))throw new Error(`Manifest hash missing for ${layerId}`);
  manifest=manifest.replace(occurrence,`"sha256": "${newHash}"`);
 }
 writeFileSync(manifestPath,manifest);
}
