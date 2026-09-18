"use client";
import{useEffect,useState}from"react";
import{createClient}from"@/lib/supabase/client";
const supabase=createClient();
export function AdminProfessions({notify}:{notify:(message:string)=>void}){const[data,setData]=useState<Record<string,unknown>|null>(null);useEffect(()=>{void supabase.rpc("admin_owner_profession_evidence").then(({data,error})=>{if(error)notify(error.message);else setData(data as Record<string,unknown>)})},[notify]);return <section className="panel adminempty"><p className="eyebrow">PROFESSION OPERATIONS</p><h2>Professions</h2><details open><summary>Owner #1 Farrier persistence evidence</summary><pre data-testid="owner-profession-evidence">{data?JSON.stringify(data,null,2):"Loading authoritative production records…"}</pre></details></section>}
