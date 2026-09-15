import sharp from "sharp";
import { mkdir } from "node:fs/promises";

const source="public/horse-visuals/masters/qh_mare_master_01.png";
const output="public/horse-visuals/proofs/qh_mare_master_01";
await mkdir(output,{recursive:true});
const{data,info}=await sharp(source).ensureAlpha().raw().toBuffer({resolveWithObject:true});
const variants={
 sorrel:{body:[174,76,38],hair:[116,50,29],points:null},
 bay:{body:[126,61,38],hair:[25,20,19],points:[30,24,22]},
 black:{body:[39,36,35],hair:[19,18,18],points:[20,19,18]},
 palomino:{body:[188,137,58],hair:[226,207,157],points:null},
 buckskin:{body:[169,126,72],hair:[27,23,20],points:[31,26,22]},
};

const clamp=n=>Math.max(0,Math.min(255,Math.round(n)));
const whiteMark=(r,g,b,x,y)=>{
 const max=Math.max(r,g,b),min=Math.min(r,g,b);
 const pale=max>168&&max-min<64;
 const markingZone=(x>1120&&y<410)||(y>720&&((x>170&&x<430)||(x>820&&x<1085)));
 return pale&&markingZone;
};
const maskSvg=(paths,blur=2)=>Buffer.from(`<svg width="${info.width}" height="${info.height}" xmlns="http://www.w3.org/2000/svg"><filter id="b"><feGaussianBlur stdDeviation="${blur}"/></filter><g fill="white" filter="url(#b)">${paths.map(d=>`<path d="${d}"/>`).join('')}</g></svg>`);
const hairMask=await sharp(maskSvg([
 "M35 1030 C30 720 22 470 78 365 C120 315 185 282 287 248 C245 337 216 450 199 590 C185 735 225 875 218 1030 Z",
 "M500 244 C650 252 720 294 820 273 C950 228 1010 128 1210 64 C1174 128 1149 205 1158 272 C1048 258 964 288 818 291 C680 294 590 266 500 244 Z"
],2.5)).removeAlpha().greyscale().raw().toBuffer();
const pointMask=await sharp(maskSvg([
 "M181 640 C225 632 273 633 318 640 L330 1030 L174 1030 Z",
 "M306 646 C350 636 402 635 450 642 L456 1030 L302 1030 Z",
 "M838 644 C878 637 927 636 970 642 L973 1030 L834 1030 Z",
 "M956 632 C1001 624 1048 623 1090 630 L1093 1030 L952 1030 Z"
],8)).removeAlpha().greyscale().raw().toBuffer();
const sourceCoat=(r,g,b)=>r>42&&r>g*1.16&&r>b*1.42;
const paint=(rgb,target,strength=1)=>{
 const [r,g,b]=rgb;
 const lum=(.299*r+.587*g+.114*b)/255;
 const shade=Math.max(.32,Math.min(1.6,lum/.43));
 return target.map((c,i)=>clamp(c*shade*strength+(i===0?Math.max(0,lum-.63)*25:0)));
};

for(const[name,palette]of Object.entries(variants)){
 if(name==='sorrel'){
  await sharp(source).png({compressionLevel:9}).toFile(`${output}/${name}.png`);
  continue;
 }
 const out=Buffer.from(data);
 for(let y=0;y<info.height;y++)for(let x=0;x<info.width;x++){
  const i=(y*info.width+x)*4,r=data[i],g=data[i+1],b=data[i+2],a=data[i+3];
  if(a<10||whiteMark(r,g,b,x,y))continue;
  if(!sourceCoat(r,g,b))continue;
  let target=palette.body;
  const hairWeight=hairMask[y*info.width+x]/255;
  const pointWeight=palette.points?pointMask[y*info.width+x]/255:0;
  const overlayWeight=Math.max(hairWeight,pointWeight);
  const overlay=hairWeight>=pointWeight?palette.hair:palette.points;
  if(overlay&&overlayWeight>0)target=target.map((c,j)=>c*(1-overlayWeight)+overlay[j]*overlayWeight);
  const[p1,p2,p3]=paint([r,g,b],target);
  out[i]=p1;out[i+1]=p2;out[i+2]=p3;
 }
 await sharp(out,{raw:info}).png({compressionLevel:9}).toFile(`${output}/${name}.png`);
}

const markMask=Buffer.alloc(info.width*info.height*4);
const silhouette=Buffer.alloc(info.width*info.height*4);
for(let y=0;y<info.height;y++)for(let x=0;x<info.width;x++){
 const i=(y*info.width+x)*4,r=data[i],g=data[i+1],b=data[i+2],a=data[i+3];
 silhouette[i]=silhouette[i+1]=silhouette[i+2]=255;silhouette[i+3]=a;
 const marked=whiteMark(r,g,b,x,y)&&a>10;
 markMask[i]=markMask[i+1]=markMask[i+2]=255;markMask[i+3]=marked?a:0;
}
await sharp(silhouette,{raw:info}).png({compressionLevel:9}).toFile(`${output}/anatomy-alpha-mask.png`);
await sharp(markMask,{raw:info}).png({compressionLevel:9}).toFile(`${output}/source-white-markings-mask.png`);
