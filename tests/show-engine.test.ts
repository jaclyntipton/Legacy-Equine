import {describe,expect,it} from "vitest";
import {competitionScore,placingLabel,PROVISIONAL_DISCIPLINE_STATS,rankDeterministically,type EffectiveBreakdown} from "../lib/game/show-engine";

const effective=(values:Record<string,number>,tack:Record<string,number>={}):EffectiveBreakdown=>Object.fromEntries(Object.entries(values).map(([stat,base])=>[stat,{base,training:0,tack:tack[stat]??0,service:0,effective:base+(tack[stat]??0)}]));

describe("Legacy Equine show engine",()=>{
  it("defines every provisional discipline mapping",()=>expect(Object.keys(PROVISIONAL_DISCIPLINE_STATS)).toEqual(["hunters","jumpers","dressage","halter","reining","western_pleasure","trail","driving","steeplechase","fox_hunting","racing","cross_country"]));
  it.each([
    ["hunters",["Agility","Temperament","Conformation","Intelligence"]],
    ["jumpers",["Agility","Strength","Speed","Intelligence"]],
    ["dressage",["Agility","Temperament","Intelligence","Conformation"]],
    ["halter",["Conformation","Temperament","Strength"]],
    ["reining",["Agility","Temperament","Intelligence","Strength"]],
    ["western_pleasure",["Temperament","Conformation","Intelligence","Agility"]],
    ["trail",["Temperament","Intelligence","Agility","Endurance"]],
    ["driving",["Strength","Temperament","Endurance","Intelligence"]],
    ["steeplechase",["Speed","Endurance","Agility","Strength"]],
    ["fox_hunting",["Endurance","Agility","Temperament","Intelligence"]],
    ["racing",["Speed","Endurance","Strength"]],
    ["cross_country",["Endurance","Agility","Strength","Temperament"]],
  ] as const)("maps %s to its configured stats",(id,stats)=>expect(PROVISIONAL_DISCIPLINE_STATS[id]).toEqual(stats));
  it("averages a three-stat discipline",()=>expect(competitionScore(PROVISIONAL_DISCIPLINE_STATS.racing,effective({Speed:50,Endurance:44,Strength:47}))).toBe(47));
  it("averages a four-stat discipline",()=>expect(competitionScore(PROVISIONAL_DISCIPLINE_STATS.hunters,effective({Agility:51,Temperament:48,Conformation:50,Intelligence:46}))).toBe(48.75));
  it("uses effective stats including tack",()=>expect(competitionScore(PROVISIONAL_DISCIPLINE_STATS.racing,effective({Speed:47,Endurance:44,Strength:47},{Speed:3}))).toBe(47));
  it("ranks highest average first",()=>expect(rankDeterministically([{score:20,baseScore:20,careerPoints:0,enteredAt:"1",horseId:"b"},{score:21,baseScore:21,careerPoints:0,enteredAt:"1",horseId:"a"}]).map(x=>x.horseId)).toEqual(["a","b"]));
  it("breaks exact ties deterministically",()=>expect(rankDeterministically([{score:20,baseScore:20,careerPoints:5,enteredAt:"2",horseId:"b"},{score:20,baseScore:20,careerPoints:5,enteredAt:"1",horseId:"a"}]).map(x=>x.horseId)).toEqual(["a","b"]));
  it("uses Win, Place, and Show terminology",()=>expect([1,2,3].map(placingLabel)).toEqual(["WIN","PLACE","SHOW"]));
});
