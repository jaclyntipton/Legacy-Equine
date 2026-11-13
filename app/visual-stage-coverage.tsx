"use client";
import{useCallback,useEffect,useState}from"react";
import{createClient}from"@/lib/supabase/client";

type Coverage={breed:string;life_stage:"foal"|"mature";sex:string;master_key:string|null;master_status:string;production_requirements:number;incomplete_requirements:number;display_ready:boolean};
const supabase=createClient();

export function VisualStageCoverage({notify}:{notify:(message:string)=>void}){
 const[rows,setRows]=useState<Coverage[]>([]),[loading,setLoading]=useState(true);
 const load=useCallback(async()=>{setLoading(true);const{data,error}=await supabase.rpc("admin_visual_stage_coverage");if(error)notify(error.message);else setRows((data??[])as Coverage[]);setLoading(false)},[notify]);
 useEffect(()=>{void load()},[load]);
 const ready=rows.filter(row=>row.display_ready).length;
 return <section className="panel visualstagecoverage"><p className="eyebrow">HORSE VISUAL LIBRARY · AGE COVERAGE</p><h2>Foal and mature body coverage</h2><p className="panelsub">A horse keeps the neutral fallback until its exact breed, stage, and sex master has a complete Owner-approved Production layer set. Foals change to the mature stage at exact age 2.</p><div className="stats"><div><small>DISPLAY-READY SETS</small><b>{ready}</b></div><div><small>REQUIRED SETS</small><b>{rows.length}</b></div><div><small>STAGES</small><b>2</b></div></div>{loading?<p>Loading visual coverage…</p>:<div className="geneticstable"><div className="geneticshead"><b>Breed</b><b>Stage</b><b>Sex</b><b>Master</b><b>Production</b><b>Status</b></div>{rows.map(row=><div key={`${row.breed}-${row.life_stage}-${row.sex}`}><span><b>{row.breed}</b></span><span>{row.life_stage}</span><span>{row.sex}</span><span>{row.master_key??"Missing"}</span><span>{row.production_requirements} ready · {row.incomplete_requirements} incomplete</span><span><b>{row.display_ready?"DISPLAY READY":row.master_key?"INCOMPLETE":"MASTER NEEDED"}</b></span></div>)}</div>}<button onClick={()=>void load()} disabled={loading}>Refresh coverage</button></section>;
}
