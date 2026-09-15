import { describe, expect, it } from "vitest";
import { canBreed, isBreedingAge } from "./simulation";
import type { Horse } from "./types";
import { GAME } from "./config";
const now=new Date("2026-09-15T12:00:00.000Z");
const horseAt=(years:number,sex:"Mare"|"Stallion"):Horse=>({id:`${sex}-${years}`,name:"Boundary Horse",breed:"Morgan",sex,color:"Bay",origin:"Bred",birthDate:new Date(now.getTime()-years*365.25*86400000/GAME.age.gameDaysPerRealDay).toISOString(),createdAt:now.toISOString(),sireId:null,damId:null,generation:1,birthStats:Object.fromEntries(GAME.stats.map(stat=>[stat,12])),stats:Object.fromEntries(GAME.stats.map(stat=>[stat,12])),tackBonuses:{},biography:"",imageUrl:"",studFee:100,lastBredAt:null,lastTrainedAt:null,retired:false});
describe.each(["Mare","Stallion"] as const)("%s breeding-age boundaries",sex=>{
 it("rejects age 2 and immediately before age 3",()=>{expect(canBreed(horseAt(2,sex),now)).toBe(false);expect(isBreedingAge(horseAt(3-1e-7,sex),now)).toBe(false)});
 it("accepts exact age 3 and all of displayed age 25",()=>{expect(canBreed(horseAt(3,sex),now)).toBe(true);expect(canBreed(horseAt(25,sex),now)).toBe(true);expect(canBreed(horseAt(26-1e-7,sex),now)).toBe(true)});
 it("rejects exact age 26 and beyond",()=>{expect(isBreedingAge(horseAt(26,sex),now)).toBe(false);expect(canBreed(horseAt(30,sex),now)).toBe(false)});
});
it("requires both parents to pass age eligibility",()=>{const sire=horseAt(12,"Stallion"),dam=horseAt(14,"Mare");expect(canBreed(sire,now)&&canBreed(dam,now)).toBe(true);expect(canBreed(horseAt(2,"Stallion"),now)&&canBreed(dam,now)).toBe(false);expect(canBreed(sire,now)&&canBreed(horseAt(26,"Mare"),now)).toBe(false)});
