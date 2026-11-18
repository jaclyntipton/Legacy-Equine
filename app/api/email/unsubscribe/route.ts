import { adminClient, validUnsubscribeSignature } from "@/lib/weekly-news-digest";

export const dynamic="force-dynamic";
export const runtime="nodejs";

const headers={"Cache-Control":"no-store","Content-Security-Policy":"default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'","X-Content-Type-Options":"nosniff"};
const page=(message:string,status=200)=>new Response(`<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Legacy Equine Email Preferences</title></head><body style="margin:0;background:#f5f0f8;font:16px Arial;color:#342b39"><main style="max-width:560px;margin:12vh auto;padding:28px;border:1px solid #dfd3ea;border-radius:16px;background:#fff"><p style="font-size:12px;font-weight:700;color:#765492">LEGACY EQUINE</p><h1 style="font-family:Georgia;color:#432d5f">Weekly Digest</h1><p>${message}</p><a href="/profile/settings" style="color:#6f42a1;font-weight:700">Open Legacy Equine Settings →</a></main></body></html>`,{status,headers:{...headers,"Content-Type":"text/html; charset=utf-8"}});

async function unsubscribe(request:Request){
 const url=new URL(request.url),stableId=url.searchParams.get("account")||"",signature=url.searchParams.get("signature")||"";
 if(!/^[0-9a-f-]{36}$/i.test(stableId)||!validUnsubscribeSignature(stableId,signature))return{ok:false,status:400};
 const{error}=await adminClient().from("news_email_preferences").upsert({stable_id:stableId,subscribed:false,unsubscribed_at:new Date().toISOString(),updated_at:new Date().toISOString()},{onConflict:"stable_id"});
 return{ok:!error,status:error?500:200};
}
export async function GET(request:Request){const result=await unsubscribe(request);return result.ok?page("You have been unsubscribed from weekly game updates. Essential account and security emails are unaffected."):page(result.status===400?"This unsubscribe link is invalid or expired.":"We could not update this preference. Please use Profile → Settings in the game.",result.status)}
export async function POST(request:Request){const result=await unsubscribe(request);return Response.json(result.ok?{unsubscribed:true}:{error:result.status===400?"Invalid unsubscribe link":"Preference update failed"},{status:result.status,headers})}
