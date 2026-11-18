import{createClient}from"@supabase/supabase-js";
import{digestProviderReady}from"@/lib/weekly-news-digest";

export const dynamic="force-dynamic";
export async function GET(request:Request){
 const token=request.headers.get("authorization")?.replace(/^Bearer\s+/i,""),url=process.env.NEXT_PUBLIC_SUPABASE_URL,anon=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
 if(!token||!url||!anon)return Response.json({error:"Authentication required"},{status:401});
 const client=createClient(url,anon,{global:{headers:{Authorization:`Bearer ${token}`}},auth:{persistSession:false}}),{error}=await client.rpc("admin_get_news_digest");
 if(error)return Response.json({error:"News administration required"},{status:403});
 return Response.json({provider_ready:digestProviderReady(),schedule:"Sunday morning ET",tracking:false},{headers:{"Cache-Control":"no-store"}});
}
