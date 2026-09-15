import {createClient} from "@supabase/supabase-js";
export const runtime="nodejs";
const url=process.env.NEXT_PUBLIC_SUPABASE_URL!,anon=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,service=process.env.SUPABASE_SERVICE_ROLE_KEY!;
export async function POST(request:Request){
 const stripe=process.env.STRIPE_SECRET_KEY;if(!stripe||!service)return Response.json({error:"Secure stall checkout is not configured yet."},{status:503});
 const token=request.headers.get("authorization")?.replace(/^Bearer\s+/i,"");if(!token)return Response.json({error:"Sign in required"},{status:401});
 const auth=createClient(url,anon,{auth:{persistSession:false}}),{data:{user}}=await auth.auth.getUser(token);if(!user)return Response.json({error:"Sign in required"},{status:401});
 const admin=createClient(url,service,{auth:{persistSession:false}}),{data:pkg}=await admin.from("stall_packages").select("*").eq("id","permanent_5").eq("active",true).single();if(!pkg)return Response.json({error:"Stall package is unavailable"},{status:503});
 const{data:payment,error}=await admin.from("stall_payment_transactions").insert({stable_id:user.id,package_id:pkg.id,usd_amount_cents:pkg.price_usd_cents,stall_quantity:pkg.stall_quantity}).select("id").single();if(error)return Response.json({error:error.message},{status:500});
 const origin=new URL(request.url).origin,body=new URLSearchParams({mode:"payment",success_url:`${origin}/?stalls=success`,cancel_url:`${origin}/?stalls=cancelled`,"line_items[0][quantity]":"1","line_items[0][price_data][currency]":"usd","line_items[0][price_data][unit_amount]":String(pkg.price_usd_cents),"line_items[0][price_data][product_data][name]":`Legacy Equine — ${pkg.display_name}`,client_reference_id:payment.id,"metadata[payment_id]":payment.id,"metadata[stable_id]":user.id});
 const response=await fetch("https://api.stripe.com/v1/checkout/sessions",{method:"POST",headers:{Authorization:`Bearer ${stripe}`,"Content-Type":"application/x-www-form-urlencoded"},body});const result=await response.json();if(!response.ok){await admin.from("stall_payment_transactions").update({status:"failed"}).eq("id",payment.id);return Response.json({error:result.error?.message??"Checkout could not be created"},{status:502})}await admin.from("stall_payment_transactions").update({checkout_session_id:result.id}).eq("id",payment.id);return Response.json({url:result.url});
}
