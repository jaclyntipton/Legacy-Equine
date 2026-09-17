/* eslint-disable @next/next/no-img-element */
"use client";
import {useMemo,useState} from "react";
import {horseArtworkCandidates} from "@/lib/game/horse-artwork";

type Props={url?:string|null;alt:string;className?:string;onPrimaryFailure?:(url:string)=>void};

/** Shared full-body renderer. Mismatched aspect ratios are letterboxed, never cropped. */
export function ContainedHorseArtwork({url,alt,className="",onPrimaryFailure}:Props){
 const candidates=useMemo(()=>horseArtworkCandidates(url??""),[url]),[index,setIndex]=useState(0),[loaded,setLoaded]=useState(false),current=candidates[index];
 if(!current)return null;
 return <div className={`containedhorseart ${loaded?"loaded":"loading-art"} ${className}`} data-horse-artwork="full-body">{!loaded&&<div className="artworkloader" role="status"><span/><small>Loading horse artwork…</small></div>}<div className="containedhorseart-inner"><img key={current} src={current} alt={alt} onLoad={()=>setLoaded(true)} onError={()=>{if(index===0&&url)onPrimaryFailure?.(url);setLoaded(false);setIndex(value=>value+1)}}/></div></div>;
}
