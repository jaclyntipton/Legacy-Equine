import{createClient}from"@supabase/supabase-js";
export const runtime="nodejs";
const url=process.env.NEXT_PUBLIC_SUPABASE_URL!,anonKey=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;
async function authenticate(request:Request){const token=request.headers.get("authorization")?.replace(/^Bearer\s+/i,"");if(!token||!url||!anonKey)return false;const client=createClient(url,anonKey,{auth:{persistSession:false}});const{data,error}=await client.auth.getUser(token);return !error&&Boolean(data.user)}
/** Retained as a compatibility tombstone; this endpoint can never spend image-generation credits. */
export async function POST(request:Request){if(!await authenticate(request))return Response.json({error:"Authentication required"},{status:401});return Response.json({claimed:0,approved:0,fallback:0,disabled:true,message:"Production horse AI generation is retired. Approved deterministic visual layers are used instead."},{status:410})}
