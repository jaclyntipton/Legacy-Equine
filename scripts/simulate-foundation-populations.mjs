const populations={
 "Quarter Horse":{Extension:.75,Agouti:.55,Cream:.07,Dun:.05,Pearl:.008,Gray:.012,Roan:.06,Sabino1:.004,Tobiano:.00010,Frame:.00010,Splash1:.00025},
 "Thoroughbred":{Extension:.79,Agouti:.69,Gray:.105,Cream:.0002,Sabino1:.00010,Splash1:.00005},
 "American Paint Horse":{Extension:.74,Agouti:.54,Cream:.07,Dun:.045,Gray:.015,Roan:.045,Tobiano:.32,Frame:.10,Sabino1:.07,Splash1:.07,Splash2:.008,W20:.012}
};
let state=0x5eed1234;
const random=()=>{state=(Math.imul(state,1664525)+1013904223)>>>0;return state/4294967296};
const pair=frequency=>[random()<frequency,random()<frequency];
const count=value=>value.filter(Boolean).length;
const genotype=breed=>Object.fromEntries(Object.entries(populations[breed]).map(([locus,frequency])=>[locus,pair(frequency)]));
function phenotype(g){
 let base=count(g.Extension??[])===0?"Chestnut":count(g.Agouti??[])>0?"Bay":"Black";
 const cream=count(g.Cream??[]);if(cream===1)base=base==="Chestnut"?"Palomino":base==="Bay"?"Buckskin":"Smoky Black";else if(cream===2)base=base==="Chestnut"?"Cremello":base==="Bay"?"Perlino":"Smoky Cream";
 if(count(g.Dun??[])>0)base=base==="Chestnut"?"Red Dun":base==="Bay"?"Bay Dun":base==="Black"?"Grullo":`${base} Dun`;if(count(g.Gray??[])>0)base="Gray";
 return base;
}
for(const breed of Object.keys(populations)){
 const totals={};let generated=0,rejectedLethal=0,loud=0;
 while(generated<10000){const g=genotype(breed);if(count(g.Frame??[])===2){rejectedLethal++;continue}generated++;const color=phenotype(g);totals[color]=(totals[color]??0)+1;
  for(const locus of["Tobiano","Frame","Sabino1","Splash1","Splash2"]){if(count(g[locus]??[])>0)totals[locus]=(totals[locus]??0)+1}
  if(["Tobiano","Frame","Splash1","Splash2"].some(locus=>count(g[locus]??[])>0))loud++;
 }
 console.log(`\n${breed} — 10,000 viable Foundation horses (${rejectedLethal} lethal genotypes rejected)`);
 for(const[key,value]of Object.entries(totals).sort((a,b)=>b[1]-a[1]))console.log(`${key.padEnd(18)} ${(value/100).toFixed(2)}%`);
 console.log(`${"Any loud pattern".padEnd(18)} ${(loud/100).toFixed(2)}%`);
}
