import {describe,expect,it} from "vitest";
import {competitionScore,competitionTier,placingLabel,PROVISIONAL_DISCIPLINE_STATS,rankDeterministically,type EffectiveBreakdown,type CompetitionTier} from "../lib/game/show-engine";

const effective=(values:Record<string,number>,tack:Record<string,number>={}):EffectiveBreakdown=>Object.fromEntries(Object.entries(values).map(([stat,base])=>[stat,{base,training:0,tack:tack[stat]??0,service:0,effective:base+(tack[stat]??0)}]));

describe("Legacy Equine show engine",()=>{
  const tiers:CompetitionTier[]=[{id:"novice",name:"Novice",minimum_points:0,maximum_points:99,sort_order:1},{id:"intermediate",name:"Intermediate",minimum_points:100,maximum_points:249,sort_order:2},{id:"advanced",name:"Advanced",minimum_points:250,maximum_points:499,sort_order:3},{id:"elite",name:"Elite",minimum_points:500,maximum_points:null,sort_order:4}];
  it.each([[0,"novice"],[99,"novice"],[100,"intermediate"],[249,"intermediate"],[250,"advanced"],[499,"advanced"],[500,"elite"],[5000,"elite"]])("maps %i Career Points to %s from database-shaped tiers",(points,id)=>expect(competitionTier(points,tiers)?.id).toBe(id));
  it("moves a horse into its new tier immediately after a level-up",()=>{expect(competitionTier(92,tiers)?.id).toBe("novice");expect(competitionTier(117,tiers)?.id).toBe("intermediate")});
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
  it("allows one stable's independently scored horses to sweep Win, Place, and Show",()=>expect(rankDeterministically(Array.from({length:12},(_,i)=>({score:100-i,baseScore:100-i,careerPoints:0,enteredAt:String(i),horseId:`same-owner-${i}`}))).slice(0,3).map((_,i)=>placingLabel(i+1))).toEqual(["WIN","PLACE","SHOW"]));
});
