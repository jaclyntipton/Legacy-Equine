/* eslint-disable @typescript-eslint/no-explicit-any */
import {generateImage} from "ai";
import {gateway} from "@ai-sdk/gateway";
import {createClient} from "@supabase/supabase-js";
import {buildHorseImagePrompt,type VisualPhenotype} from "@/lib/game/horse-visual";

export const runtime="nodejs";
export const maxDuration=300;

type ImageJob={job_id:string;horse_id:string;visual_phenotype:VisualPhenotype;markings:Record<string,string>};
const url=process.env.NEXT_PUBLIC_SUPABASE_URL!;
const anonKey=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;
const serviceKey=process.env.SUPABASE_SERVICE_ROLE_KEY!;

async function authenticate(request:Request){const token=request.headers.get("authorization")?.replace(/^Bearer\s+/i,"");if(!token)return false;const client=createClient(url,anonKey,{auth:{persistSession:false}});const{data,error}=await client.auth.getUser(token);return !error&&Boolean(data.user)}
async function claim(admin:any){const{data,error}=await admin.rpc("claim_store_horse_image_job");if(error)throw error;return (data?.[0]??null) as ImageJob|null}
async function fail(admin:any,job:ImageJob,error:unknown){const message=error instanceof Error?error.message:"Image generation failed";const providerUnavailable=/credit card|gateway|authentication|rate limit/i.test(message);const{data}=await admin.from("store_horse_image_jobs").select("attempts").eq("id",job.job_id).single();const terminal=!providerUnavailable&&(data?.attempts??1)>=3;await admin.from("store_horse_image_jobs").update({status:terminal?"failed":"pending",last_error:message.slice(0,500),next_attempt_at:new Date(Date.now()+(providerUnavailable?30:15)*60*1000).toISOString()}).eq("id",job.job_id);await admin.from("horses").update({image_generation_status:terminal?"failed":"pending"}).eq("id",job.horse_id);return providerUnavailable?"Image generation is waiting for the production image provider to be enabled.":"Artwork generation will retry automatically."}
async function processJob(admin:any,job:ImageJob){const prompt=buildHorseImagePrompt(job.visual_phenotype);try{const result=await generateImage({model:gateway.imageModel("bfl/flux-2-pro"),prompt,aspectRatio:"4:3",maxRetries:1});const ext=result.image.mediaType.includes("jpeg")?"jpg":"png",objectPath=`generated/horses/${job.horse_id}-v6.${ext}`;const uploaded=await admin.storage.from("legacy-equine-media").upload(objectPath,result.image.uint8Array,{contentType:result.image.mediaType,cacheControl:"31536000",upsert:true});if(uploaded.error)throw uploaded.error;const publicUrl=admin.storage.from("legacy-equine-media").getPublicUrl(objectPath).data.publicUrl;const completed=await admin.rpc("complete_horse_image_job",{target_job:job.job_id,target_horse:job.horse_id,new_image_url:publicUrl,used_prompt:prompt,prompt_version:"horse-v6"});if(completed.error)throw completed.error;return{ok:true as const}}catch(error){return{ok:false as const,error:await fail(admin,job,error)}}}

export async function POST(request:Request){if(!url||!anonKey||!serviceKey)return Response.json({error:"Image worker is not configured"},{status:503});if(!await authenticate(request))return Response.json({error:"Authentication required"},{status:401});const admin=createClient(url,serviceKey,{auth:{persistSession:false}});let completed=0,failed=0;const messages=new Set<string>();for(let batch=0;batch<10;batch++){const jobs=(await Promise.all([claim(admin),claim(admin)])).filter((job):job is ImageJob=>Boolean(job));if(!jobs.length)break;const results=await Promise.all(jobs.map(job=>processJob(admin,job)));completed+=results.filter(x=>x.ok).length;failed+=results.filter(x=>!x.ok).length;for(const result of results)if(!result.ok)messages.add(result.error)}return Response.json({completed,failed,message:messages.values().next().value??null})}
