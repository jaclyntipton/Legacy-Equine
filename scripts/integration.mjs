import { createClient } from "@supabase/supabase-js";
import assert from "node:assert/strict";
const url=process.env.SUPABASE_URL,key=process.env.SUPABASE_SERVICE_ROLE_KEY;
if(!url||!key)throw new Error("Missing integration credentials");
const admin=createClient(url,key,{auth:{persistSession:false}});const stamp=Date.now();const password=`LE-${stamp}-Test!`;const ids=[];
async function makeUser(n){const email=`legacy-equine-test-${stamp}-${n}@example.com`;const{data,error}=await admin.auth.admin.createUser({email,password,email_confirm:true});if(error)throw error;ids.push(data.user.id);const marked=await admin.from("test_identities").insert({user_id:data.user.id});if(marked.error)throw marked.error;const client=createClient(url,process.env.SUPABASE_ANON_KEY,{auth:{persistSession:false}});const signed=await client.auth.signInWithPassword({email,password});if(signed.error)throw signed.error;return{client,id:data.user.id}}
try{
 const a=await makeUser(1),b=await makeUser(2);
 let r=await a.client.rpc("initialize_stable",{stable_name:"Integration Acres"});assert.ifError(r.error);assert.equal(r.data.account_number,null);
 r=await a.client.rpc("initialize_stable",{stable_name:"Duplicate Attempt"});assert.ifError(r.error);assert.equal(r.data.account_number,null);
 let q=await admin.from("currency_ledger").select("*").eq("stable_id",a.id).eq("reason","Starting funds");assert.equal(q.data.length,1);
 r=await b.client.rpc("initialize_stable",{stable_name:"Sequence Farm"});assert.ifError(r.error);assert.equal(r.data.account_number,null);
 const bought=[];for(let i=0;i<3;i++){r=await a.client.rpc("purchase_foundation_horse");assert.ifError(r.error);bought.push(r.data)}assert.notEqual(bought[0].sex,bought[1].sex);
 r=await a.client.rpc("purchase_foundation_horse");assert.ok(r.error);q=await admin.from("stables").select("balance,foundation_purchases").eq("id",a.id).single();assert.deepEqual(q.data,{balance:0,foundation_purchases:3});
 const strangerUpdate=await b.client.from("horses").update({name:"Stolen"}).eq("id",bought[0].id).select();assert.equal(strangerUpdate.data.length,0);
 r=await a.client.rpc("train_horse",{target_horse:bought[0].id,stat_name:"Speed"});assert.ifError(r.error);r=await a.client.rpc("train_horse",{target_horse:bought[0].id,stat_name:"Speed"});assert.ok(r.error);
 await admin.from("horses").update({sex:"Stallion",stud_fee:0}).eq("id",bought[0].id);await admin.from("horses").update({sex:"Mare"}).eq("id",bought[1].id);
 r=await a.client.rpc("breed_horses",{stallion_id:bought[0].id,mare_id:bought[1].id});assert.ifError(r.error);assert.equal(r.data.sire_id,bought[0].id);assert.equal(r.data.dam_id,bought[1].id);for(const value of Object.values(r.data.stats))assert.ok(Number.isInteger(value)&&value>=1);
 r=await a.client.rpc("breed_horses",{stallion_id:bought[0].id,mare_id:bought[1].id});assert.ok(r.error);
 q=await admin.from("breeding_records").select("foal_id").eq("foal_id",r.data?.id??"00000000-0000-0000-0000-000000000000");
 console.log("Production integration checks passed");
}finally{for(const id of ids){await admin.from("training_log").delete().eq("stable_id",id);await admin.from("currency_ledger").delete().eq("stable_id",id);await admin.from("breeding_records").delete().eq("owner_id",id);await admin.from("inventory").delete().eq("owner_id",id);await admin.from("horses").delete().eq("owner_id",id);await admin.from("stables").delete().eq("id",id);await admin.auth.admin.deleteUser(id)}}
