/* eslint-disable @next/next/no-img-element */
"use client";
import{useCallback,useEffect,useState}from"react";
import{createClient}from"@/lib/supabase/client";
const supabase=createClient();
type Summary={unlimited:boolean;current_usage:number;effective_capacity:number|null;over_capacity:boolean;privilege:string;max_upload_bytes:number;max_dimension:number};
type Item={id:string;storage_path:string;width:number;height:number;created_at:string};
export function ArtworkAlbum({upload,notify}:{upload:(file:File)=>Promise<string|null>;notify:(message:string)=>void}){
 const[summary,setSummary]=useState<Summary|null>(null),[items,setItems]=useState<Item[]>([]),[busy,setBusy]=useState(false);
 const load=useCallback(async()=>{const[{data:s,error},{data:i}]=await Promise.all([supabase.rpc("artwork_storage_summary"),supabase.from("artwork_album_items").select("id,storage_path,width,height,created_at").eq("status","active").order("created_at",{ascending:false})]);if(error)notify(error.message);else setSummary(s as Summary);setItems((i??[])as Item[])},[notify]);
 useEffect(()=>{const timer=setTimeout(()=>void load(),0);return()=>clearTimeout(timer)},[load]);
 const url=(path:string)=>supabase.storage.from("legacy-equine-media").getPublicUrl(path).data.publicUrl;
 const add=async(file:File)=>{setBusy(true);const result=await upload(file);if(result)notify("Artwork added to your Album.");await load();setBusy(false)};
 const remove=async(item:Item)=>{setBusy(true);const{error}=await supabase.rpc("remove_artwork_album_item",{p_item:item.id});if(error)notify(error.message);else notify("Artwork removed from your Album. Existing horse selections are not changed.");await load();setBusy(false)};
 return <section className="panel artworkalbum"><div className="albumheading"><div><p className="eyebrow">MY PROFILE · ARTWORK ALBUM</p><h2>Your hosted artwork</h2></div><strong>{summary?.unlimited?"Artwork Storage: Unlimited":`${summary?.current_usage??0} / ${summary?.effective_capacity??0} images`}</strong></div><p className="panelsub">Upload once, then select the artwork from any horse you own. JPG, PNG, or WebP · 5 MB incoming maximum · stored at no more than 1200 × 1200.</p>{summary?.over_capacity&&<p className="capacitywarning">Your Album is over capacity. Existing artwork remains safe, but new uploads are paused.</p>}<label className="albumupload">+ Add artwork<input type="file" accept="image/jpeg,image/png,image/webp" disabled={busy||Boolean(summary?.over_capacity)} onChange={e=>{const file=e.target.files?.[0];if(file)void add(file);e.currentTarget.value=""}}/></label><div className="albumgrid">{items.map(item=><article key={item.id}><img src={url(item.storage_path)} alt="Artwork Album item"/><span><small>{item.width} × {item.height}</small><time>{new Date(item.created_at).toLocaleDateString()}</time></span><button disabled={busy} onClick={()=>void remove(item)}>Remove</button></article>)}</div>{!items.length&&<p className="featurehint">Your Artwork Album is ready for its first image.</p>}</section>
}
