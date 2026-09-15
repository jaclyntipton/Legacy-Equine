/* eslint-disable @typescript-eslint/no-explicit-any */
import {generateImage,generateText,Output} from "ai";
import {gateway} from "@ai-sdk/gateway";
import {createClient} from "@supabase/supabase-js";
import {z} from "zod";
import {coatAccuracyConstraint,type VisualPhenotype} from "@/lib/game/horse-visual";

export const runtime="nodejs";
export const maxDuration=300;
type ImageJob={job_id:string;horse_id:string;visual_phenotype:VisualPhenotype;markings:Record<string,string>;image_url:string;template_id:string;template_url:string;is_fallback:boolean};
const url=process.env.NEXT_PUBLIC_SUPABASE_URL!,anonKey=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,serviceKey=process.env.SUPABASE_SERVICE_ROLE_KEY!;

async function authenticate(request:Request){const token=request.headers.get("authorization")?.replace(/^Bearer\s+/i,"");if(!token)return false;const client=createClient(url,anonKey,{auth:{persistSession:false}});const{data,error}=await client.auth.getUser(token);return !error&&Boolean(data.user)}
async function claim(admin:any){const{data,error}=await admin.rpc("claim_store_horse_image_job");if(error)throw error;return(data?.[0]??null)as ImageJob|null}
const absoluteTemplateUrl=(value:string)=>value.startsWith("http")?value:new URL(value,"https://legacy-equine.vercel.app").toString();

async function finish(admin:any,job:ImageJob,imageUrl:string,status:"approved"|"fallback",prompt:string){
 const completed=await admin.rpc("complete_horse_image_job",{target_job:job.job_id,target_horse:job.horse_id,new_image_url:imageUrl,used_prompt:prompt,prompt_version:"approved-template-v1"});if(completed.error)throw completed.error;
 const{error}=await admin.from("horses").update({image_template_id:job.template_id,image_quality_status:status,image_generation_status:"complete"}).eq("id",job.horse_id);if(error)throw error;
}

const qaSchema=z.object({approved:z.boolean(),template_geometry_matches:z.boolean(),four_complete_legs:z.boolean(),four_complete_hooves:z.boolean(),balanced_stance:z.boolean(),breed_type_matches:z.boolean(),phenotype_matches:z.boolean(),full_horse_visible:z.boolean(),clean_background:z.boolean(),has_text_or_signature:z.boolean(),reasons:z.array(z.string()).max(8)});
async function inspect(source:Uint8Array,template:Uint8Array,job:ImageJob){const v=job.visual_phenotype,{output}=await generateText({model:gateway("openai/gpt-5.4-mini"),output:Output.object({schema:qaSchema}),messages:[{role:"user",content:[{type:"text",text:`Strict Legacy Equine template-variation QA. Image 1 is the generated candidate; Image 2 is the human-approved anatomy template. The candidate must preserve the template's skeleton, limb placement, hoof placement, balance, breed conformation, framing, and pose. Expected breed ${v.breed}, sex ${v.sex}, color ${v.color}, coat ${v.coat}, mane/tail ${v.mane_tail}, pattern ${v.pattern}, face ${v.face_marking}, legs LF ${v.left_front}, RF ${v.right_front}, LH ${v.left_hind}, RH ${v.right_hind}. ${coatAccuracyConstraint(v.color,v.coat,v.mane_tail)} Reject any missing, merged, duplicate, floating, cropped, or malformed leg/hoof; impossible joint; detached part; changed body proportion; fake ground/object/blob; text, signature, watermark, logo, or phenotype mismatch. Approve only if every required boolean is true and has_text_or_signature is false.`},{type:"file",mediaType:"image/png",data:source},{type:"file",mediaType:"image/png",data:template}]}],maxRetries:1});return output}

function variationPrompt(v:VisualPhenotype){return `Edit the supplied human-approved Legacy Equine ${v.breed} anatomy template. Preserve its exact skeletal proportions, pose, limb and hoof positions, joint angles, topline, body outline, balance, framing, and breed type. Change appearance only. Render exact phenotype ${v.color}; coat ${v.coat}; mane/tail ${v.mane_tail}; pattern ${v.pattern}; face marking ${v.face_marking}; leg markings LF ${v.left_front}, RF ${v.right_front}, LH ${v.left_hind}, RH ${v.right_hind}. ${coatAccuracyConstraint(v.color,v.coat,v.mane_tail)} Keep exactly one complete horse, four complete legs, four complete hooves, entire ears/nose/hooves/tail visible. General-audience sex presentation; omit all genitalia. Preserve a transparent background if the template is transparent; otherwise use only the template's existing uniform Legacy Equine neutral background. No floor, ground, cast shadow, colored blob, scenery, prop, tack, person, text, letters, numbers, signature, watermark, logo, or artist mark. Do not redesign or regenerate anatomy.`}

async function processJob(admin:any,job:ImageJob){const fallback="/foundation-horse.png";if(job.is_fallback){await finish(admin,job,fallback,"fallback","No approved breed template; official Foundation fallback used.");return{ok:true as const,fallback:true}}
 try{
  const response=await fetch(absoluteTemplateUrl(job.template_url));if(!response.ok)throw new Error("Approved template could not be loaded");const template=new Uint8Array(await response.arrayBuffer()),prompt=variationPrompt(job.visual_phenotype);
  const result=await generateImage({model:gateway.imageModel("openai/gpt-image-1.5"),prompt:{images:[template],text:prompt},aspectRatio:"4:3",maxRetries:1});const source=result.image.uint8Array,qa=await inspect(source,template,job);
  const approved=qa.approved&&qa.template_geometry_matches&&qa.four_complete_legs&&qa.four_complete_hooves&&qa.balanced_stance&&qa.breed_type_matches&&qa.phenotype_matches&&qa.full_horse_visible&&qa.clean_background&&!qa.has_text_or_signature;
  await admin.from("horse_image_qa_reviews").insert({horse_id:job.horse_id,job_id:job.job_id,approved,checks:{...qa,template_id:job.template_id,pipeline:"approved-template-v1"}});
  if(!approved)throw new Error(`Template variation rejected: ${qa.reasons.join("; ")}`);
  const objectPath=`generated/template-variations/${job.horse_id}-${Date.now()}.png`,uploaded=await admin.storage.from("legacy-equine-media").upload(objectPath,source,{contentType:"image/png",cacheControl:"31536000",upsert:false});if(uploaded.error)throw uploaded.error;
  const publicUrl=admin.storage.from("legacy-equine-media").getPublicUrl(objectPath).data.publicUrl;await finish(admin,job,publicUrl,"approved",prompt);return{ok:true as const,fallback:false};
 }catch(error){
  await admin.from("horse_image_qa_reviews").insert({horse_id:job.horse_id,job_id:job.job_id,approved:false,checks:{pipeline:"approved-template-v1",template_id:job.template_id,error:error instanceof Error?error.message:"Template variation failed",fallback:true}});
  await finish(admin,job,fallback,"fallback","Template variation failed QA; official Foundation fallback used.");return{ok:true as const,fallback:true};
 }
}

export async function POST(request:Request){if(!url||!anonKey||!serviceKey)return Response.json({error:"Image worker is not configured"},{status:503});if(!await authenticate(request))return Response.json({error:"Authentication required"},{status:401});const admin=createClient(url,serviceKey,{auth:{persistSession:false}}),jobs:ImageJob[]=[];for(let batch=0;batch<12;batch++){const job=await claim(admin);if(!job)break;jobs.push(job)}const results=await Promise.all(jobs.map(job=>processJob(admin,job)));return Response.json({claimed:jobs.length,approved:results.filter(r=>!r.fallback).length,fallback:results.filter(r=>r.fallback).length})}
