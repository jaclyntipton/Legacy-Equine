import { createHmac, timingSafeEqual } from "node:crypto";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

type DigestConfig={enabled:boolean;window_days:number;max_articles:number;subject_prefix:string};
type DigestPost={id:string;title:string;summary:string;body:string;category:string;destination_url:string|null;published_at:string|null;publish_at:string|null;created_at:string;pinned:boolean;expires_at:string|null};
type Preference={stable_id:string};
type Run={id:string;status:string;article_ids:string[]};
type ProviderResult={id:string};

const siteUrl=()=>new URL(process.env.APP_URL||"https://legacyequines.com").origin;
const esc=(value:string)=>value.replace(/[&<>'"]/g,char=>({"&":"&amp;","<":"&lt;",">":"&gt;","'":"&#39;",'"':"&quot;"})[char]!);
const effectiveDate=(post:DigestPost)=>new Date(post.published_at||post.publish_at||post.created_at);
const mondayKey=(date=new Date())=>{const copy=new Date(Date.UTC(date.getUTCFullYear(),date.getUTCMonth(),date.getUTCDate()));copy.setUTCDate(copy.getUTCDate()-((copy.getUTCDay()+6)%7));return copy.toISOString().slice(0,10)};
const unsubscribeSecret=()=>process.env.EMAIL_UNSUBSCRIBE_SECRET||process.env.CRON_SECRET||"";
export const unsubscribeSignature=(stableId:string)=>createHmac("sha256",unsubscribeSecret()).update(stableId).digest("hex");
export const validUnsubscribeSignature=(stableId:string,signature:string)=>{const expected=unsubscribeSignature(stableId),provided=Buffer.from(signature);return Boolean(unsubscribeSecret())&&provided.length===expected.length&&timingSafeEqual(provided,Buffer.from(expected))};
const unsubscribeUrl=(stableId:string)=>`${siteUrl()}/api/email/unsubscribe?account=${encodeURIComponent(stableId)}&signature=${unsubscribeSignature(stableId)}`;

function renderDigest(posts:DigestPost[],stableId:string){
 const base=siteUrl(),unsubscribe=unsubscribeUrl(stableId),items=posts.map(post=>{const href=post.destination_url?new URL(post.destination_url,base).toString():`${base}/news/${post.id}`;return `<article style="padding:16px 0;border-bottom:1px solid #e4d9ec"><div style="font:700 11px Arial;color:#765492;text-transform:uppercase">${esc(post.category.replaceAll("_"," "))}</div><h2 style="margin:6px 0;font:700 20px Georgia;color:#432d5f">${esc(post.title)}</h2><p style="margin:0 0 10px;color:#4f4555;line-height:1.55">${esc(post.summary||post.body).slice(0,800)}</p><a href="${esc(href)}" style="color:#6f42a1;font-weight:700">Read on Legacy Equine →</a></article>`}).join("");
 const html=`<!doctype html><html><body style="margin:0;background:#f5f0f8;font-family:Arial,sans-serif;color:#342b39"><div style="max-width:640px;margin:auto;padding:28px 18px"><header style="padding:24px;border-radius:16px 16px 0 0;background:#432d5f;color:white"><div style="font-size:12px;letter-spacing:.14em">LEGACY EQUINE</div><h1 style="margin:7px 0 0;font:700 28px Georgia">Weekly Game Digest</h1></header><main style="padding:4px 24px 24px;background:white">${items}<p style="margin:22px 0 0"><a href="${base}/home" style="color:#6f42a1;font-weight:700">View all News &amp; Updates →</a></p></main><footer style="padding:18px 24px;color:#716778;font-size:12px;line-height:1.5">You received this because you opted into the weekly Legacy Equine Digest. Security and account emails are managed separately.<br><a href="${esc(unsubscribe)}" style="color:#6f42a1">Unsubscribe from weekly game news</a></footer></div></body></html>`;
 const text=["LEGACY EQUINE — Weekly Game Digest","",...posts.flatMap(post=>[post.title,post.summary||post.body,post.destination_url?new URL(post.destination_url,base).toString():`${base}/news/${post.id}`,""]),`All News: ${base}/home`,`Unsubscribe: ${unsubscribe}`].join("\n");
 return{html,text,unsubscribe};
}

async function sendWithProvider(input:{to:string;subject:string;html:string;text:string;unsubscribe:string;idempotencyKey:string}):Promise<ProviderResult>{
 const key=process.env.RESEND_API_KEY,from=process.env.EMAIL_FROM;
 if(!key||!from)throw new Error("email_provider_unavailable");
 const response=await fetch("https://api.resend.com/emails",{method:"POST",headers:{Authorization:`Bearer ${key}`,"Content-Type":"application/json","Idempotency-Key":input.idempotencyKey},body:JSON.stringify({from,to:[input.to],subject:input.subject,html:input.html,text:input.text,headers:{"List-Unsubscribe":`<${input.unsubscribe}>`,"List-Unsubscribe-Post":"List-Unsubscribe=One-Click"}})});
 if(!response.ok)throw new Error(`provider_${response.status}`);
 const value=await response.json()as{id?:string};return{id:value.id||"accepted"};
}

export function adminClient(){const url=process.env.NEXT_PUBLIC_SUPABASE_URL,service=process.env.SUPABASE_SERVICE_ROLE_KEY;if(!url||!service)throw new Error("supabase_admin_unavailable");return createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}})}
export const digestProviderReady=()=>Boolean(process.env.RESEND_API_KEY&&process.env.EMAIL_FROM&&unsubscribeSecret());

async function claimDelivery(db:SupabaseClient,runId:string,stableId:string){
 const inserted=await db.from("news_digest_deliveries").insert({run_id:runId,stable_id:stableId,status:"processing"}).select("id").maybeSingle();
 if(!inserted.error&&inserted.data)return true;
 if(inserted.error?.code!=="23505")throw inserted.error;
 const existing=await db.from("news_digest_deliveries").select("status,updated_at").eq("run_id",runId).eq("stable_id",stableId).single();
 if(existing.error||existing.data.status!=="failed"||Date.now()-new Date(existing.data.updated_at).getTime()<300000)return false;
 const retry=await db.from("news_digest_deliveries").update({status:"processing",error_code:null,updated_at:new Date().toISOString()}).eq("run_id",runId).eq("stable_id",stableId).eq("status","failed").select("id").maybeSingle();
 return Boolean(retry.data);
}

export async function runWeeklyNewsDigest(){
 const db=adminClient(),week=mondayKey(),now=new Date();
 const cfgResult=await db.from("news_digest_config").select("enabled,window_days,max_articles,subject_prefix").eq("singleton",true).single();
 if(cfgResult.error)throw cfgResult.error;const config=cfgResult.data as DigestConfig;
 if(!config.enabled)return{status:"skipped",reason:"digest_disabled"};
 if(!digestProviderReady())return{status:"skipped",reason:"provider_not_configured"};
 const cutoff=now.getTime()-config.window_days*86400000;
 const postResult=await db.from("news_posts").select("id,title,summary,body,category,destination_url,published_at,publish_at,created_at,pinned,expires_at").eq("status","published").order("pinned",{ascending:false}).order("published_at",{ascending:false}).limit(100);
 if(postResult.error)throw postResult.error;
 const posts=(postResult.data as DigestPost[]).filter(post=>{const date=effectiveDate(post).getTime();return date<=now.getTime()&&date>=cutoff&&(!post.expires_at||new Date(post.expires_at)>now)}).slice(0,config.max_articles);
 if(!posts.length)return{status:"skipped",reason:"no_recent_news"};
 let runResult=await db.from("news_digest_runs").insert({week_key:week,article_ids:posts.map(post=>post.id)}).select("id,status,article_ids").maybeSingle();
 if(runResult.error?.code==="23505")runResult=await db.from("news_digest_runs").select("id,status,article_ids").eq("week_key",week).single();
 if(runResult.error||!runResult.data)throw runResult.error||new Error("digest_run_unavailable");const run=runResult.data as Run;
 if(run.status==="complete")return{status:"complete",reason:"already_sent"};
 const prefResult=await db.from("news_email_preferences").select("stable_id").eq("subscribed",true);if(prefResult.error)throw prefResult.error;
 const recipients=prefResult.data as Preference[];let sent=0,failed=0,skipped=0;
 for(const recipient of recipients){
  if(!await claimDelivery(db,run.id,recipient.stable_id))continue;
  const auth=await db.auth.admin.getUserById(recipient.stable_id),user=auth.data.user;
  if(auth.error||!user?.email||!user.email_confirmed_at){skipped++;await db.from("news_digest_deliveries").update({status:"skipped",error_code:auth.error?"auth_lookup_failed":!user?.email?"email_missing":"email_unverified",updated_at:new Date().toISOString()}).eq("run_id",run.id).eq("stable_id",recipient.stable_id);continue}
  try{const rendered=renderDigest(posts,recipient.stable_id),result=await sendWithProvider({to:user.email,subject:`${config.subject_prefix} — ${now.toLocaleDateString("en-US",{month:"short",day:"numeric",timeZone:"America/New_York"})}`,html:rendered.html,text:rendered.text,unsubscribe:rendered.unsubscribe,idempotencyKey:`le-weekly-${run.id}-${recipient.stable_id}`});sent++;await db.from("news_digest_deliveries").update({status:"sent",provider_message_id:result.id,updated_at:new Date().toISOString()}).eq("run_id",run.id).eq("stable_id",recipient.stable_id)}catch(error){failed++;await db.from("news_digest_deliveries").update({status:"failed",error_code:error instanceof Error?error.message.slice(0,80):"provider_error",updated_at:new Date().toISOString()}).eq("run_id",run.id).eq("stable_id",recipient.stable_id)}
 }
 const status=failed?"partial":"complete";await db.from("news_digest_runs").update({status,eligible_count:recipients.length,sent_count:sent,failed_count:failed,skip_reason:skipped?`${skipped} ineligible verified emails`:null,completed_at:new Date().toISOString()}).eq("id",run.id);
 return{status,eligible:recipients.length,sent,failed,skipped,articles:posts.length};
}
