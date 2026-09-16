import { describe, expect, it } from "vitest";
import { canBreed, canTrain, isBreedingAge } from "./simulation";
import type { Horse } from "./types";
import { GAME } from "./config";
const now=new Date("2026-09-15T12:00:00.000Z");
const horseAt=(years:number,sex:"Mare"|"Stallion"):Horse=>({id:`${sex}-${years}`,name:"Boundary Horse",breed:"Morgan",sex,color:"Bay",origin:"Bred",birthDate:new Date(now.getTime()-years*365.25*86400000/GAME.age.gameDaysPerRealDay).toISOString(),createdAt:now.toISOString(),sireId:null,damId:null,generation:1,birthStats:Object.fromEntries(GAME.stats.map(stat=>[stat,12])),stats:Object.fromEntries(GAME.stats.map(stat=>[stat,12])),tackBonuses:{},biography:"",imageUrl:"",studFee:100,lastBredAt:null,lastTrainedAt:null,retired:false});
describe.each(["Mare","Stallion"] as const)("%s age boundaries",sex=>{
 it("rejects training and breeding below exact age 2",()=>{for(const value of[1,1.99,2-1e-7]){expect(canTrain(horseAt(value,sex),now)).toBe(false);expect(canBreed(horseAt(value,sex),now)).toBe(false)}});
 it("accepts training and breeding from exact age 2 through before 26",()=>{for(const value of[2,25.99,26-1e-7]){expect(canTrain(horseAt(value,sex),now)).toBe(true);expect(canBreed(horseAt(value,sex),now)).toBe(true)}});
 it("keeps training but retires breeding at exact age 26 and beyond",()=>{for(const value of[26,30]){expect(canTrain(horseAt(value,sex),now)).toBe(true);expect(isBreedingAge(horseAt(value,sex),now)).toBe(false);expect(canBreed(horseAt(value,sex),now)).toBe(false)}});
});
it("requires both parents to pass age eligibility",()=>{const sire=horseAt(12,"Stallion"),dam=horseAt(14,"Mare");expect(canBreed(sire,now)&&canBreed(dam,now)).toBe(true);expect(canBreed(horseAt(1.99,"Stallion"),now)&&canBreed(dam,now)).toBe(false);expect(canBreed(sire,now)&&canBreed(horseAt(26,"Mare"),now)).toBe(false)});
