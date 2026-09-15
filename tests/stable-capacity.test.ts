import{describe,expect,it}from"vitest";import{stableCapacity}from"../lib/game/stable-capacity";
describe("stable capacity",()=>{
 it("gives a new player five base stalls",()=>expect(stableCapacity([{source:"base",quantity:5}],0).total).toBe(5));
 it("allows acquisition only while a stall is available",()=>{expect(stableCapacity([{source:"base",quantity:5}],4).canAcquire).toBe(true);expect(stableCapacity([{source:"base",quantity:5}],5).canAcquire).toBe(false)});
 it("stacks repeated permanent purchases exactly",()=>expect(stableCapacity([{source:"base",quantity:5},{source:"purchased",quantity:5},{source:"purchased",quantity:5}],5).total).toBe(15));
 it("tracks complimentary grants separately and ignores reversals",()=>expect(stableCapacity([{source:"base",quantity:5},{source:"admin",quantity:10},{source:"admin",quantity:25,status:"reversed"}],0).total).toBe(15));
 it("models owner capacity explicitly as unlimited",()=>expect(stableCapacity([{source:"base",quantity:5},{source:"owner_unlimited",quantity:0,unlimited:true}],100000).canAcquire).toBe(true));
 it("freeing a horse immediately frees a stall",()=>expect(stableCapacity([{source:"base",quantity:5}],4).available).toBe(1));
});
