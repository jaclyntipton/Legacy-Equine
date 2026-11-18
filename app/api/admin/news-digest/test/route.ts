import{adminClient,sendWeeklyNewsDigestTest}from"@/lib/weekly-news-digest";

export const dynamic="force-dynamic";
export const runtime="nodejs";

const maskEmail=(email:string)=>{const[local,domain]=email.split("@");return `${local.slice(0,2)}***@${domain}`};

export async function POST(request:Request){
 const token=request.headers.get("authorization")?.replace(/^Bearer\s+/i,"");
 if(!token)return Response.json({error:"Authentication required"},{status:401});
 const db=adminClient(),auth=await db.auth.getUser(token),user=auth.data.user;
 if(auth.error||!user)return Response.json({error:"Authentication required"},{status:401});
 const stable=await db.from("stables").select("account_number").eq("id",user.id).single();
 if(stable.error||![1,2].includes(Number(stable.data.account_number)))return Response.json({error:"Owner access required"},{status:403});
 if(!user.email||!user.email_confirmed_at)return Response.json({error:"Owner login email must be verified"},{status:400});
 try{
  const result=await sendWeeklyNewsDigestTest(user.id,user.email);
  return Response.json({...result,sent_to:maskEmail(user.email)},{headers:{"Cache-Control":"no-store"}});
 }catch(error){
  const message=error instanceof Error?error.message:"test_send_failed";
  console.error("Owner weekly digest test failed",{owner:user.id,error:message});
  return Response.json({error:message},{status:500,headers:{"Cache-Control":"no-store"}});
 }
}
