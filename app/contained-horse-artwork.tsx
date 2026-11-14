/* eslint-disable @next/next/no-img-element */
"use client";
import {useEffect,useMemo,useRef,useState} from "react";
import {horseArtworkCandidates} from "@/lib/game/horse-artwork";
import {createClient} from "@/lib/supabase/client";
import {paintCoat,resolveCoatLayers,type CoatManifest,type CoatRecipe} from "@/lib/game/horse-coat-compositor";

type Props={url?:string|null;horseId?:string|null;alt:string;className?:string;onPrimaryFailure?:(url:string)=>void;showFallbackLabel?:boolean};

/** Shared full-body renderer. Mismatched aspect ratios are letterboxed, never cropped. */
export function ContainedHorseArtwork({url,horseId,alt,className="",onPrimaryFailure}:Props){
 const candidates=useMemo(()=>horseArtworkCandidates(url??""),[url]),[index,setIndex]=useState(0),[loaded,setLoaded]=useState(false),[recipe,setRecipe]=useState<CoatRecipe|null>(null),canvas=useRef<HTMLCanvasElement>(null),current=candidates[index];
 useEffect(()=>{let alive=true;if(!horseId){setRecipe(null);return}const supabase=createClient();void supabase.rpc("get_horse_visual_recipe",{p_horse_id:horseId}).then(({data})=>{if(alive)setRecipe(data as CoatRecipe|null)});return()=>{alive=false}},[horseId]);
 useEffect(()=>{let alive=true;if(!recipe?.master_url||recipe.custom_url||recipe.life_stage!=="mature"||!canvas.current)return;const key=recipe.template_id?.replace("_vector_master_01","_master_01");if(!key||!/(tennessee_walking_horse|rocky_mountain_horse)_(mare|stallion)_master_01/.test(key))return;void fetch(`/horse-visuals/coat-layers/${key}/manifest.json`).then(r=>r.ok?r.json():Promise.reject()).then(async(manifest:CoatManifest)=>{await paintCoat(canvas.current!,manifest,recipe,resolveCoatLayers(manifest,recipe));if(alive)setLoaded(true)}).catch(()=>{if(alive)setRecipe(null)});return()=>{alive=false}},[recipe]);
 const composed=Boolean(recipe?.master_url&&!recipe.custom_url&&recipe.life_stage==="mature"&&/(tennessee_walking_horse|rocky_mountain_horse)/.test(recipe.template_id??""));
 if(!current)return null;
 return <div className={`containedhorseart ${loaded?"loaded":"loading-art"} ${className}`} data-horse-artwork="full-body">{!loaded&&<div className="artworkloader" role="status"><span/><small>Loading horse artwork…</small></div>}<div className="containedhorseart-inner">{composed?<canvas ref={canvas} role="img" aria-label={alt}/>:<img key={current} src={current} alt={alt} onLoad={()=>setLoaded(true)} onError={()=>{if(index===0&&url)onPrimaryFailure?.(url);setLoaded(false);setIndex(value=>value+1)}}/>}</div></div>;
}
