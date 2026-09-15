import { createClient } from "@supabase/supabase-js";
import assert from "node:assert/strict";

const url=process.env.SUPABASE_URL,key=process.env.SUPABASE_SERVICE_ROLE_KEY;
if(!url||!key||!process.env.SUPABASE_ANON_KEY)throw new Error("Missing integration credentials");
const admin=createClient(url,key,{auth:{persistSession:false}});const stamp=Date.now();const password=`LE-${stamp}-Test!`;const ids=[];

async function makeUser(n){
  const email=`legacy-equine-test-${stamp}-${n}@example.com`;
  const{data,error}=await admin.auth.admin.createUser({email,password,email_confirm:true});if(error)throw error;
  ids.push(data.user.id);const marked=await admin.from("test_identities").insert({user_id:data.user.id});if(marked.error)throw marked.error;
  const client=createClient(url,process.env.SUPABASE_ANON_KEY,{auth:{persistSession:false}});const signed=await client.auth.signInWithPassword({email,password});if(signed.error)throw signed.error;
  return{client,id:data.user.id};
}

const horseIdentity=h=>({id:h.id??h.horse_id,name:h.name,breed:h.breed,sex:h.sex,color:h.color,birth_date:h.birth_date,stats:h.stats,image_url:h.image_url});

try{
  const a=await makeUser(1),b=await makeUser(2),c=await makeUser(3);
  for(const [player,name] of [[a,"Integration Acres"],[b,"Sequence Farm"],[c,"Boundary Ranch"]]){
    const created=await player.client.rpc("initialize_stable",{stable_name:name});assert.ifError(created.error);assert.equal(created.data.account_number,null);
  }
  let repeat=await a.client.rpc("initialize_stable",{stable_name:"Duplicate Attempt"});assert.ifError(repeat.error);assert.equal(repeat.data.name,"Integration Acres");
  let q=await admin.from("currency_ledger").select("*").eq("stable_id",a.id).eq("reason","Starting funds");assert.equal(q.data.length,1);

  const first=await a.client.rpc("get_store_inventory");assert.ifError(first.error);assert.equal(first.data.length,6);
  const second=await b.client.rpc("get_store_inventory");assert.ifError(second.error);assert.deepEqual(second.data.map(horseIdentity),first.data.map(horseIdentity));
  assert.ok(new Set(first.data.map(h=>h.breed)).size>1);for(const h of first.data){assert.equal(h.image_url,"/foundation-horse.png");assert.equal(Object.keys(h.stats).length,7);}

  const target=first.data[0],expected=horseIdentity(target);
  const raced=await Promise.all([a.client.rpc("purchase_store_horse",{target_inventory:target.inventory_id}),b.client.rpc("purchase_store_horse",{target_inventory:target.inventory_id})]);
  assert.equal(raced.filter(x=>!x.error).length,1);assert.equal(raced.filter(x=>x.error).length,1);assert.match(raced.find(x=>x.error).error.message,/just purchased|no longer available/i);
  const winner=raced[0].error?b:a;const bought=[raced.find(x=>!x.error).data];assert.deepEqual(horseIdentity(bought[0]),expected);

  let store=await winner.client.rpc("get_store_inventory");assert.ifError(store.error);assert.equal(store.data.length,6);assert.ok(!store.data.some(h=>h.inventory_id===target.inventory_id));
  for(let i=0;i<2;i++){const result=await winner.client.rpc("purchase_store_horse",{target_inventory:store.data[i].inventory_id});assert.ifError(result.error);bought.push(result.data);store=await winner.client.rpc("get_store_inventory");assert.equal(store.data.length,6);}
  const limited=await winner.client.rpc("purchase_store_horse",{target_inventory:store.data[0].inventory_id});assert.ok(limited.error);assert.match(limited.error.message,/limit/i);
  q=await admin.from("stables").select("balance,foundation_purchases").eq("id",winner.id).single();assert.deepEqual(q.data,{balance:0,foundation_purchases:3});
  q=await admin.from("currency_ledger").select("amount,horse_id").eq("stable_id",winner.id).lt("amount",0);assert.equal(q.data.length,3);assert.equal(q.data.reduce((sum,x)=>sum+x.amount,0),-3000);assert.ok(q.data.every(x=>bought.some(h=>h.id===x.horse_id)));

  const stranger=winner.id===a.id?b:a;const strangerUpdate=await stranger.client.from("horses").update({name:"Stolen"}).eq("id",bought[0].id).select();assert.equal(strangerUpdate.data.length,0);
  let trained=await winner.client.rpc("train_horse",{target_horse:bought[0].id,stat_name:"Speed"});assert.ifError(trained.error);trained=await winner.client.rpc("train_horse",{target_horse:bought[0].id,stat_name:"Speed"});assert.ok(trained.error);
  await admin.from("horses").update({sex:"Stallion",stud_fee:0}).eq("id",bought[0].id);await admin.from("horses").update({sex:"Mare"}).eq("id",bought[1].id);
  let bred=await winner.client.rpc("breed_horses",{stallion_id:bought[0].id,mare_id:bought[1].id});assert.ifError(bred.error);assert.equal(bred.data.sire_id,bought[0].id);assert.equal(bred.data.dam_id,bought[1].id);for(const value of Object.values(bred.data.stats))assert.ok(Number.isInteger(value)&&value>=1);
  bred=await winner.client.rpc("breed_horses",{stallion_id:bought[0].id,mare_id:bought[1].id});assert.ok(bred.error);

  store=await a.client.rpc("get_store_inventory");const beforeRotation=store.data.map(h=>h.inventory_id);await admin.from("store_inventory").update({generated_at:new Date(Date.now()-61*60*1000).toISOString()}).eq("status","active");
  const rotated=await b.client.rpc("get_store_inventory");assert.ifError(rotated.error);assert.equal(rotated.data.length,6);assert.ok(rotated.data.every(h=>!beforeRotation.includes(h.inventory_id)));
  q=await admin.from("store_inventory").select("status").in("id",beforeRotation);assert.ok(q.data.every(x=>x.status==="expired"));

  const boundaryTarget=rotated.data[0],boundaryIdentity=horseIdentity(boundaryTarget);await admin.from("store_inventory").update({generated_at:new Date(Date.now()-61*60*1000).toISOString()}).eq("status","active");
  const boundary=await Promise.all([c.client.rpc("purchase_store_horse",{target_inventory:boundaryTarget.inventory_id}),a.client.rpc("get_store_inventory")]);
  assert.ifError(boundary[1].error);assert.equal(boundary[1].data.length,6);
  if(boundary[0].error){assert.match(boundary[0].error.message,/just purchased|no longer available/i);q=await admin.from("store_inventory").select("status").eq("id",boundaryTarget.inventory_id).single();assert.equal(q.data.status,"expired");}
  else{assert.deepEqual(horseIdentity(boundary[0].data),boundaryIdentity);q=await admin.from("horses").select("owner_id").eq("id",boundaryTarget.horse_id).single();assert.equal(q.data.owner_id,c.id);}

  console.log("Production integration checks passed: persistent inventory, exact purchase, replacement, locking, rotation, ledger, and limits");
}finally{
  for(const id of ids){
    await admin.from("training_log").delete().eq("stable_id",id);await admin.from("currency_ledger").delete().eq("stable_id",id);await admin.from("breeding_records").delete().eq("owner_id",id);await admin.from("inventory").delete().eq("owner_id",id);
    await admin.from("store_inventory").delete().eq("sold_to",id);await admin.from("horses").delete().eq("owner_id",id);await admin.from("stables").delete().eq("id",id);await admin.auth.admin.deleteUser(id);
  }
}
