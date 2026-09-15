/* eslint-disable @typescript-eslint/no-explicit-any */
import {generateImage} from "ai";
import {gateway} from "@ai-sdk/gateway";
import {createClient} from "@supabase/supabase-js";
import sharp from "sharp";
import {buildHorseImagePrompt,type VisualPhenotype} from "@/lib/game/horse-visual";

export const runtime="nodejs";
export const maxDuration=300;
type ImageJob={job_id:string;horse_id:string;visual_phenotype:VisualPhenotype;markings:Record<string,string>;image_url:string};
const url=process.env.NEXT_PUBLIC_SUPABASE_URL!,anonKey=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,serviceKey=process.env.SUPABASE_SERVICE_ROLE_KEY!;

async function authenticate(request:Request){const token=request.headers.get("authorization")?.replace(/^Bearer\s+/i,"");if(!token)return false;const client=createClient(url,anonKey,{auth:{persistSession:false}});const{data,error}=await client.auth.getUser(token);return !error&&Boolean(data.user)}
async function claim(admin:any){const{data,error}=await admin.rpc("claim_store_horse_image_job");if(error)throw error;return(data?.[0]??null)as ImageJob|null}
async function fail(admin:any,job:ImageJob,error:unknown){const message=error instanceof Error?error.message:"Image generation failed",providerUnavailable=/credit card|gateway|authentication|rate limit/i.test(message);const{data}=await admin.from("store_horse_image_jobs").select("attempts").eq("id",job.job_id).single(),terminal=!providerUnavailable&&(data?.attempts??1)>=3;await admin.from("store_horse_image_jobs").update({status:terminal?"failed":"pending",last_error:message.slice(0,500),next_attempt_at:new Date(Date.now()+(providerUnavailable?30:15)*60*1000).toISOString()}).eq("id",job.job_id);await admin.from("horses").update({image_generation_status:terminal?"failed":"pending"}).eq("id",job.horse_id);return providerUnavailable?"Image generation is waiting for the production image provider to be enabled.":"Artwork generation will retry automatically."}

// Remove light neutral pixels connected to the canvas edge. This deliberately
// includes fake transparency checkerboards produced by image models. Enclosed
// white horse markings remain opaque because they are not edge-connected.
async function transparentBackground(input:Uint8Array){
 const image=sharp(input).ensureAlpha(),{data,info}=await image.raw().toBuffer({resolveWithObject:true});
 const seen=new Uint8Array(info.width*info.height),queue=new Int32Array(info.width*info.height);let head=0,tail=0;
 const add=(index:number)=>{if(index<0||index>=seen.length||seen[index])return;const p=index*4,r=data[p],g=data[p+1],b=data[p+2];if(Math.min(r,g,b)<145||Math.max(r,g,b)-Math.min(r,g,b)>48)return;seen[index]=1;queue[tail++]=index};
 for(let x=0;x<info.width;x++){add(x);add((info.height-1)*info.width+x)}for(let y=0;y<info.height;y++){add(y*info.width);add(y*info.width+info.width-1)}
 while(head<tail){const i=queue[head++],x=i%info.width;data[i*4+3]=0;if(x>0)add(i-1);if(x<info.width-1)add(i+1);add(i-info.width);add(i+info.width)}
 // Feather only the one-pixel silhouette boundary to avoid a jagged matte.
 for(let i=0;i<seen.length;i++){if(seen[i])continue;const x=i%info.width,y=Math.floor(i/info.width),touches=(x>0&&seen[i-1])||(x<info.width-1&&seen[i+1])||(y>0&&seen[i-info.width])||(y<info.height-1&&seen[i+info.width]);if(touches)data[i*4+3]=Math.min(data[i*4+3],190)}
 return sharp(data,{raw:info}).png().toBuffer();
}

async function processJob(admin:any,job:ImageJob){const prompt=buildHorseImagePrompt(job.visual_phenotype);try{let source:Uint8Array;if(job.image_url.includes("/generated/")&&!job.image_url.includes("-v12.")){const response=await fetch(job.image_url);if(!response.ok)throw new Error("Existing artwork could not be loaded for background repair");source=new Uint8Array(await response.arrayBuffer())}else{const result=await generateImage({model:gateway.imageModel("bfl/flux-2-pro"),prompt,aspectRatio:"4:3",maxRetries:1});source=result.image.uint8Array}const png=await transparentBackground(source),objectPath=`generated/horses/${job.horse_id}-v12.png`;const uploaded=await admin.storage.from("legacy-equine-media").upload(objectPath,png,{contentType:"image/png",cacheControl:"31536000",upsert:true});if(uploaded.error)throw uploaded.error;const publicUrl=admin.storage.from("legacy-equine-media").getPublicUrl(objectPath).data.publicUrl,completed=await admin.rpc("complete_horse_image_job",{target_job:job.job_id,target_horse:job.horse_id,new_image_url:publicUrl,used_prompt:prompt,prompt_version:"horse-v12"});if(completed.error)throw completed.error;return{ok:true as const}}catch(error){return{ok:false as const,error:await fail(admin,job,error)}}}

export async function POST(request:Request){if(!url||!anonKey||!serviceKey)return Response.json({error:"Image worker is not configured"},{status:503});if(!await authenticate(request))return Response.json({error:"Authentication required"},{status:401});const admin=createClient(url,serviceKey,{auth:{persistSession:false}});let completed=0,failed=0;const messages=new Set<string>();for(let batch=0;batch<8;batch++){const job=await claim(admin);if(!job)break;const result=await processJob(admin,job);if(result.ok)completed++;else{failed++;messages.add(result.error);break}}return Response.json({completed,failed,message:messages.values().next().value??null})}
