import {createClient} from "@supabase/supabase-js";
import sharp from "sharp";

export const runtime="nodejs";
const WIDTH=1496,HEIGHT=1051,MAX_BYTES=10*1024*1024;

type Box={left:number;top:number;width:number;height:number};
async function alphaBox(input:Buffer):Promise<Box|null>{
 const {data,info}=await sharp(input).ensureAlpha().raw().toBuffer({resolveWithObject:true});
 let left=info.width,top=info.height,right=-1,bottom=-1;
 for(let y=0;y<info.height;y++)for(let x=0;x<info.width;x++)if(data[(y*info.width+x)*4+3]>4){left=Math.min(left,x);top=Math.min(top,y);right=Math.max(right,x);bottom=Math.max(bottom,y)}
 return right<0?null:{left,top,width:right-left+1,height:bottom-top+1};
}
const delta=(a:Box,b:Box)=>({x:a.left-b.left,y:a.top-b.top,width:a.width-b.width,height:a.height-b.height});

export async function POST(request:Request){
 try{
  const token=request.headers.get("authorization")?.replace(/^Bearer\s+/i,"");
  const url=process.env.NEXT_PUBLIC_SUPABASE_URL,anon=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,service=process.env.SUPABASE_SERVICE_ROLE_KEY;
  if(!token||!url||!anon||!service)return Response.json({error:"Visual preparation is not configured."},{status:503});
  const auth=createClient(url,anon,{global:{headers:{Authorization:`Bearer ${token}`}},auth:{persistSession:false}}),admin=createClient(url,service,{auth:{persistSession:false}});
  const{data:{user}}=await auth.auth.getUser(token);if(!user)return Response.json({error:"Sign in required."},{status:401});
  const{data:owner}=await admin.from("stables").select("account_number,is_admin").eq("id",user.id).single();
  if(!owner||owner.account_number!==1)return Response.json({error:"Only Owner Account #1 can prepare visual assets for review."},{status:403});
  const form=await request.formData(),file=form.get("file"),requirementId=String(form.get("requirement_id")??"");
  if(!(file instanceof File)||!requirementId)return Response.json({error:"Choose a candidate and its exact requirement."},{status:400});
  if(file.size<=0||file.size>MAX_BYTES)return Response.json({error:"Candidate artwork must be 10 MB or smaller."},{status:400});
  const{data:req}=await admin.from("horse_visual_asset_requirements").select("id,body_template_key,category,trait_key,anatomical_position,variant,canvas_width,canvas_height").eq("id",requirementId).single();
  if(!req)return Response.json({error:"The selected visual requirement no longer exists."},{status:404});
  const{data:master}=await admin.from("horse_visual_assets").select("image_url").eq("asset_key",req.body_template_key).eq("immutable_source",true).single();
  if(!master)return Response.json({error:"The immutable master reference is unavailable."},{status:409});
  const source=Buffer.from(await file.arrayBuffer()),meta=await sharp(source).metadata();
  if(!["png","webp"].includes(meta.format??"")||!meta.hasAlpha)return Response.json({error:"Candidate must be a transparent PNG or WebP."},{status:400});
  const sourceBox=await alphaBox(source);if(!sourceBox)return Response.json({error:"Candidate contains no visible artwork."},{status:400});
  let prepared:Buffer;
  if(meta.width===req.canvas_width&&meta.height===req.canvas_height)prepared=await sharp(source).ensureAlpha().png().toBuffer();
  else{const safeWidth=req.canvas_width-12,safeHeight=req.canvas_height-12,contained=await sharp(source).resize(safeWidth,safeHeight,{fit:"contain",position:"centre",background:{r:0,g:0,b:0,alpha:0},withoutEnlargement:false}).ensureAlpha().png().toBuffer();prepared=await sharp({create:{width:req.canvas_width,height:req.canvas_height,channels:4,background:{r:0,g:0,b:0,alpha:0}}}).composite([{input:contained,left:6,top:6}]).png().toBuffer()}
  const preparedBox=(await alphaBox(prepared))!;
  const masterResponse=await fetch(master.image_url);if(!masterResponse.ok)return Response.json({error:"The immutable master could not be loaded for comparison."},{status:502});
  const masterBuffer=Buffer.from(await masterResponse.arrayBuffer()),masterRegistered=await sharp(masterBuffer).resize(req.canvas_width,req.canvas_height,{fit:"contain",background:{r:0,g:0,b:0,alpha:0}}).png().toBuffer(),masterBox=await alphaBox(masterRegistered);
  if(!masterBox)return Response.json({error:"The immutable master has no readable silhouette."},{status:409});
  const warnings:string[]=[];
  const fullHorse=["clean_body","base_coat","modifier","dapple"].includes(req.category),d=delta(preparedBox,masterBox);
  if(meta.width!==req.canvas_width||meta.height!==req.canvas_height)warnings.push(`Normalized from ${meta.width}×${meta.height} to the registered ${req.canvas_width}×${req.canvas_height} canvas without cropping or stretching.`);
  if(fullHorse&&(Math.abs(d.x)>40||Math.abs(d.y)>40||Math.abs(d.width)>60||Math.abs(d.height)>60))warnings.push("Horse registration differs from the immutable master; Owner visual review is required.");
  const clipped=preparedBox.left<=1||preparedBox.top<=1||preparedBox.left+preparedBox.width>=req.canvas_width-1||preparedBox.top+preparedBox.height>=req.canvas_height-1;
  if(clipped)return Response.json({error:"Preparation stopped because visible artwork touches the canvas edge and may be clipped."},{status:422});
  if(fullHorse&&(preparedBox.width<req.canvas_width*.45||preparedBox.height<req.canvas_height*.45))return Response.json({error:"Preparation stopped because the horse scale is too different for reliable compositing."},{status:422});
  const limb=req.anatomical_position?`_${req.anatomical_position.toLowerCase()}`:"",base=`${req.body_template_key.replace("_master","")}_${req.category}_${req.trait_key}${limb}_${String(req.variant).padStart(2,"0")}`.replace(/[^a-zA-Z0-9_-]/g,"_");
  const preparedPath=`${user.id}/visual-library/prepared/${crypto.randomUUID()}-${base}.png`,sourcePath=`${user.id}/visual-library/candidates/${crypto.randomUUID()}-${file.name.replace(/[^a-zA-Z0-9._-]/g,"-")}`;
  const sourceUpload=await admin.storage.from("legacy-equine-media").upload(sourcePath,source,{contentType:file.type,upsert:false});if(sourceUpload.error)throw sourceUpload.error;
  const preparedUpload=await admin.storage.from("legacy-equine-media").upload(preparedPath,prepared,{contentType:"image/png",upsert:false});if(preparedUpload.error)throw preparedUpload.error;
  const preparedUrl=admin.storage.from("legacy-equine-media").getPublicUrl(preparedPath).data.publicUrl,sourceUrl=admin.storage.from("legacy-equine-media").getPublicUrl(sourcePath).data.publicUrl;
  const validation={workflow:"owner_prepared_review",source_url:sourceUrl,prepared_filename:`${base}.png`,source_dimensions:{width:meta.width,height:meta.height},prepared_dimensions:{width:req.canvas_width,height:req.canvas_height},candidate_bbox:preparedBox,master_bbox:masterBox,registration_delta:d,clipping_detected:false,warnings};
  const{data:assetId,error}=await auth.rpc("owner_register_prepared_visual_asset",{p_requirement:req.id,p_asset_key:base,p_image_url:preparedUrl,p_width:req.canvas_width,p_height:req.canvas_height,p_file_size:prepared.length,p_validation:validation});
  if(error)throw error;
  return Response.json({asset_id:assetId,filename:`${base}.png`,image_url:preparedUrl,master_url:master.image_url,warnings,diagnostics:validation});
 }catch(error){const requestId=crypto.randomUUID();console.error("visual asset preparation failed",{requestId,error});return Response.json({error:"We couldn't prepare this artwork for review. Please try again.",details:error instanceof Error?error.message:String(error),request_id:requestId},{status:500})}
}
