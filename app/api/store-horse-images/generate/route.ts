/* eslint-disable @typescript-eslint/no-explicit-any */
import {readFile} from "node:fs/promises";
import path from "node:path";
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
async function fail(admin:any,job:ImageJob,error:unknown){const message=error instanceof Error?error.message:"Image generation failed";const{data}=await admin.from("store_horse_image_jobs").select("attempts").eq("id",job.job_id).single();const terminal=(data?.attempts??1)>=3;await admin.from("store_horse_image_jobs").update({status:terminal?"failed":"pending",last_error:message.slice(0,500),next_attempt_at:new Date(Date.now()+15*60*1000).toISOString()}).eq("id",job.job_id);await admin.from("horses").update({image_generation_status:terminal?"failed":"pending"}).eq("id",job.horse_id)}
async function processJob(admin:any,reference:Buffer,job:ImageJob){const prompt=buildHorseImagePrompt(job.visual_phenotype);try{const result=await generateImage({model:gateway.imageModel("openai/gpt-image-2.5-sunburst"),prompt:{text:prompt,images:[reference]},aspectRatio:"4:3",maxRetries:1});const ext=result.image.mediaType.includes("jpeg")?"jpg":"png",objectPath=`generated/store/${job.horse_id}.${ext}`;const uploaded=await admin.storage.from("legacy-equine-media").upload(objectPath,result.image.uint8Array,{contentType:result.image.mediaType,cacheControl:"31536000",upsert:true});if(uploaded.error)throw uploaded.error;const publicUrl=admin.storage.from("legacy-equine-media").getPublicUrl(objectPath).data.publicUrl;const horseUpdate=await admin.from("horses").update({image_url:publicUrl,image_generation_status:"complete",image_prompt_version:"store-horse-v1"}).eq("id",job.horse_id);if(horseUpdate.error)throw horseUpdate.error;await admin.from("store_horse_image_jobs").update({status:"complete",prompt,completed_at:new Date().toISOString(),last_error:null}).eq("id",job.job_id);return true}catch(error){await fail(admin,job,error);return false}}

export async function POST(request:Request){if(!url||!anonKey||!serviceKey)return Response.json({error:"Image worker is not configured"},{status:503});if(!await authenticate(request))return Response.json({error:"Authentication required"},{status:401});const admin=createClient(url,serviceKey,{auth:{persistSession:false}});const reference=await readFile(path.join(process.cwd(),"public","foundation-horse.png"));let completed=0,failed=0;for(let batch=0;batch<3;batch++){const jobs=(await Promise.all([claim(admin),claim(admin)])).filter((job):job is ImageJob=>Boolean(job));if(!jobs.length)break;const results=await Promise.all(jobs.map(job=>processJob(admin,reference,job)));completed+=results.filter(Boolean).length;failed+=results.filter(x=>!x).length}return Response.json({completed,failed})}
