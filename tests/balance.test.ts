import {describe,expect,it} from "vitest";
import {GAME} from "../lib/game/config";
import {createFoal,createFoundationHorse,developHorse} from "../lib/game/simulation";
import {seededRandom} from "../lib/game/random";

describe("100,000 breeding line-improvement simulation",()=>{
  it("models intentional linear generational growth without temporary inheritance",()=>{
    const random=seededRandom(20260914);
    let population=Array.from({length:200},()=>createFoundationHorse(random));
    const generationMeans:number[]=[];
    for(let generation=0;generation<10;generation++){
      const developed=population.map(h=>developHorse(h,Object.fromEntries(GAME.stats.map(stat=>[stat,20]))));
      const next=[];
      for(let i=0;i<10000;i++){
        const sire={...developed[Math.floor(random()*developed.length)],sex:"Stallion" as const,tackBonuses:Object.fromEntries(GAME.stats.map(stat=>[stat,999]))};
        const dam={...developed[Math.floor(random()*developed.length)],sex:"Mare" as const};
        next.push(createFoal(sire,dam,random));
      }
      population=next;
      generationMeans.push(population.flatMap(h=>Object.values(h.birthStats)).reduce((a,b)=>a+b,0)/(population.length*GAME.stats.length));
    }
    console.info({breedings:100000,generationMeans});
    expect(generationMeans.at(-1)!).toBeGreaterThan(generationMeans[0]+150);
    expect(generationMeans.at(-1)!).toBeLessThan(generationMeans[0]+250);
    expect(Math.max(...population.flatMap(h=>Object.values(h.birthStats)))).toBeGreaterThan(100);
  });
});
