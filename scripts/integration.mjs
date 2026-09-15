import { createClient } from "@supabase/supabase-js";
import assert from "node:assert/strict";

const url=process.env.SUPABASE_URL,key=process.env.SUPABASE_SERVICE_ROLE_KEY;
if(!url||!key||!process.env.SUPABASE_ANON_KEY)throw new Error("Missing integration credentials");
const admin=createClient(url,key,{auth:{persistSession:false}});const stamp=Date.now();const password=`LE-${stamp}-Test!`;const ids=[],mediaPaths=[];

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
  for(const [player,name,suffix] of [[a,"Integration Acres Updated","a"],[b,"Sequence Farm","b"],[c,"Boundary Ranch","c"]]){const profile=await player.client.rpc("update_stable_profile",{new_name:name,new_username:`it_${stamp}_${suffix}`,new_bio:"Automated QA stable"});assert.ifError(profile.error);assert.equal(profile.data.name,name);assert.equal(profile.data.username,`it_${stamp}_${suffix}`);}
  const duplicateUsername=await b.client.rpc("update_stable_profile",{new_name:"Sequence Farm",new_username:`it_${stamp}_a`,new_bio:""});assert.ok(duplicateUsername.error);assert.match(duplicateUsername.error.message,/taken/i);
  let optionalUsername=await b.client.rpc("update_stable_profile",{new_name:"Renamed Without Username",new_username:"",new_bio:""});assert.ifError(optionalUsername.error);assert.equal(optionalUsername.data.username,null);optionalUsername=await b.client.rpc("update_stable_profile",{new_name:"Sequence Farm",new_username:`it_${stamp}_b`,new_bio:"Automated QA stable"});assert.ifError(optionalUsername.error);
  const pixel=Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=","base64"),ranchPath=`${a.id}/ranches/${stamp}.png`,avatarPath=`${a.id}/avatars/${stamp}.png`;let media=await a.client.storage.from("legacy-equine-media").upload(ranchPath,pixel,{contentType:"image/png"});assert.ifError(media.error);mediaPaths.push(ranchPath);media=await a.client.storage.from("legacy-equine-media").upload(avatarPath,pixel,{contentType:"image/png"});assert.ifError(media.error);mediaPaths.push(avatarPath);const forbiddenMedia=await b.client.storage.from("legacy-equine-media").upload(`${a.id}/avatars/forbidden-${stamp}.png`,pixel,{contentType:"image/png"});assert.ok(forbiddenMedia.error);const ranchUrl=a.client.storage.from("legacy-equine-media").getPublicUrl(ranchPath).data.publicUrl,avatarUrl=a.client.storage.from("legacy-equine-media").getPublicUrl(avatarPath).data.publicUrl;const images=await a.client.rpc("update_stable_images",{new_ranch_image_url:ranchUrl,new_avatar_url:avatarUrl});assert.ifError(images.error);assert.equal(images.data.ranch_image_url,ranchUrl);assert.equal(images.data.avatar_url,avatarUrl);

  const first=await a.client.rpc("get_store_inventory");assert.ifError(first.error);assert.equal(first.data.length,6);
  const second=await b.client.rpc("get_store_inventory");assert.ifError(second.error);assert.deepEqual(second.data.map(horseIdentity),first.data.map(horseIdentity));
  assert.ok(new Set(first.data.map(h=>h.breed)).size>1);for(const h of first.data){assert.equal(h.name,"Unnamed Foundation Horse");assert.equal(h.image_url,"/foundation-horse.png");assert.equal(Object.keys(h.stats).length,7);}

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
  const renamed=await winner.client.rpc("update_horse_profile",{target_horse:bought[0].id,new_name:"Test Legacy",new_biography:"",new_image_url:bought[0].image_url});assert.ifError(renamed.error);assert.equal(renamed.data.name,"Test Legacy");bought[0].name="Test Legacy";
  const horsePath=`${winner.id}/horses/${bought[0].id}-${stamp}.png`;media=await winner.client.storage.from("legacy-equine-media").upload(horsePath,pixel,{contentType:"image/png"});assert.ifError(media.error);mediaPaths.push(horsePath);const horseUrl=winner.client.storage.from("legacy-equine-media").getPublicUrl(horsePath).data.publicUrl;const horseImage=await winner.client.rpc("update_horse_profile",{target_horse:bought[0].id,new_name:bought[0].name,new_biography:"",new_image_url:horseUrl});assert.ifError(horseImage.error);assert.equal(horseImage.data.image_url,horseUrl);assert.notEqual(horseUrl,ranchUrl);assert.notEqual(horseUrl,avatarUrl);
  let trained=await winner.client.rpc("train_horse",{target_horse:bought[0].id,stat_name:"Speed"});assert.ifError(trained.error);trained=await winner.client.rpc("train_horse",{target_horse:bought[0].id,stat_name:"Speed"});assert.ok(trained.error);
  await admin.from("horses").update({sex:"Stallion",stud_fee:0}).eq("id",bought[0].id);await admin.from("horses").update({sex:"Mare"}).eq("id",bought[1].id);
  let bred=await winner.client.rpc("breed_horses",{stallion_id:bought[0].id,mare_id:bought[1].id});assert.ifError(bred.error);assert.equal(bred.data.sire_id,bought[0].id);assert.equal(bred.data.dam_id,bought[1].id);for(const value of Object.values(bred.data.stats))assert.ok(Number.isInteger(value)&&value>=1);
  bred=await winner.client.rpc("breed_horses",{stallion_id:bought[0].id,mare_id:bought[1].id});assert.ok(bred.error);

  const openShows=await winner.client.rpc("get_open_shows");assert.ifError(openShows.error);assert.ok(openShows.data.length>=3);let entry=await winner.client.rpc("enter_show",{target_competition:openShows.data[0].id,target_horse:bought[0].id});assert.ifError(entry.error);assert.ok(entry.data.points_awarded>0);entry=await winner.client.rpc("enter_show",{target_competition:openShows.data[0].id,target_horse:bought[0].id});assert.ok(entry.error);
  const listing=await winner.client.rpc("list_horse_for_sale",{target_horse:bought[2].id,asking_price:500});assert.ifError(listing.error);const market=await c.client.rpc("get_marketplace");assert.ifError(market.error);assert.ok(market.data.some(x=>x.listing_id===listing.data.id&&x.horse_id===bought[2].id));const marketBuy=await c.client.rpc("buy_marketplace_horse",{target_listing:listing.data.id});assert.ifError(marketBuy.error);assert.equal(marketBuy.data.id,bought[2].id);q=await admin.from("horses").select("owner_id").eq("id",bought[2].id).single();assert.equal(q.data.owner_id,c.id);
  const rootPost=await winner.client.rpc("create_forum_post",{post_body:"Integration community post",reply_to:null});assert.ifError(rootPost.error);const replyPost=await c.client.rpc("create_forum_post",{post_body:"Integration reply",reply_to:rootPost.data.id});assert.ifError(replyPost.error);const feed=await a.client.rpc("get_forum_posts");assert.ifError(feed.error);assert.ok(feed.data.some(x=>x.id===rootPost.data.id));assert.ok(feed.data.some(x=>x.parent_id===rootPost.data.id));

  store=await a.client.rpc("get_store_inventory");const beforeRotation=store.data.map(h=>h.inventory_id);await admin.from("store_inventory").update({generated_at:new Date(Date.now()-61*60*1000).toISOString()}).eq("status","active");
  const rotated=await b.client.rpc("get_store_inventory");assert.ifError(rotated.error);assert.equal(rotated.data.length,6);assert.ok(rotated.data.every(h=>!beforeRotation.includes(h.inventory_id)));
  q=await admin.from("store_inventory").select("status").in("id",beforeRotation);assert.ok(q.data.every(x=>x.status==="expired"));

  const boundaryTarget=rotated.data[0],boundaryIdentity=horseIdentity(boundaryTarget);await admin.from("store_inventory").update({generated_at:new Date(Date.now()-61*60*1000).toISOString()}).eq("status","active");
  const boundary=await Promise.all([c.client.rpc("purchase_store_horse",{target_inventory:boundaryTarget.inventory_id}),a.client.rpc("get_store_inventory")]);
  assert.ifError(boundary[1].error);assert.equal(boundary[1].data.length,6);
  if(boundary[0].error){assert.match(boundary[0].error.message,/just purchased|no longer available/i);q=await admin.from("store_inventory").select("status").eq("id",boundaryTarget.inventory_id).single();assert.equal(q.data.status,"expired");}
  else{assert.deepEqual(horseIdentity(boundary[0].data),boundaryIdentity);q=await admin.from("horses").select("owner_id").eq("id",boundaryTarget.horse_id).single();assert.equal(q.data.owner_id,c.id);}

  console.log("Production integration checks passed: isolated media, profiles, training, shows, marketplace, community, inventory, locking, ledger, and limits");
}finally{
  if(mediaPaths.length)await admin.storage.from("legacy-equine-media").remove(mediaPaths);
  for(const id of ids){
    await admin.from("forum_posts").delete().eq("stable_id",id);await admin.from("competition_entries").delete().eq("stable_id",id);await admin.from("marketplace_listings").delete().or(`seller_id.eq.${id},buyer_id.eq.${id}`);await admin.from("training_log").delete().eq("stable_id",id);await admin.from("currency_ledger").delete().eq("stable_id",id);await admin.from("breeding_records").delete().eq("owner_id",id);await admin.from("inventory").delete().eq("owner_id",id);
    await admin.from("store_inventory").delete().eq("sold_to",id);await admin.from("horses").delete().eq("owner_id",id);await admin.from("stables").delete().eq("id",id);await admin.auth.admin.deleteUser(id);
  }
}
