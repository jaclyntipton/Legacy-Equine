import { runWeeklyNewsDigest } from "@/lib/weekly-news-digest";

export const dynamic="force-dynamic";
export const runtime="nodejs";

export async function GET(request:Request){
 const secret=process.env.CRON_SECRET;
 if(!secret||request.headers.get("authorization")!==`Bearer ${secret}`)return Response.json({error:"Unauthorized"},{status:401});
 try{return Response.json(await runWeeklyNewsDigest(),{headers:{"Cache-Control":"no-store"}})}
 catch(error){const requestId=crypto.randomUUID();console.error("weekly digest failed",{requestId,error:error instanceof Error?error.message:"unknown"});return Response.json({error:"Weekly digest processing failed",request_id:requestId},{status:500,headers:{"Cache-Control":"no-store"}})}
}
