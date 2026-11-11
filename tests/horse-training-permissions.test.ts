import{readFileSync}from"node:fs";
import{describe,expect,it}from"vitest";

const profile=readFileSync("app/horse-profile.tsx","utf8");
const training=readFileSync("supabase/migrations/202609160011_age_two_training_and_breeding.sql","utf8");

describe("horse training permissions",()=>{
 it("shows training actions only to the current horse owner",()=>{
  expect(profile).toContain('{canEdit&&<button disabled={!canTrain(h)} onClick={()=>train(stat)}>Train +1</button>}');
  expect(profile).toContain("Only this horse’s current owner may perform training sessions.");
 });
 it("independently enforces ownership on the server",()=>{
  expect(training).toContain("h.owner_id<>auth.uid()");
  expect(training).toContain("Horse not found or not owned");
 });
 it("keeps administrative AP correction separately Admin-gated",()=>{
  expect(profile).toContain('<HorseAllocatablePoints horseId={h.id} stats={h.stats} canAllocate={canEdit} isAdmin={isAdmin}');
 });
});
