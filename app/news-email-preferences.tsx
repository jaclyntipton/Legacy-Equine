"use client";
import{useCallback,useEffect,useState}from"react";
import{createClient}from"@/lib/supabase/client";
import"./news-email-preferences.css";

const supabase=createClient();
type Preference={subscribed:boolean;consented_at:string|null;unsubscribed_at:string|null;frequency:"weekly"};

export function NewsEmailPreferences({notify}:{notify:(message:string)=>void}){
 const[pref,setPref]=useState<Preference|null>(null),[selected,setSelected]=useState(false),[busy,setBusy]=useState(false);
 const load=useCallback(async()=>{const{data,error}=await supabase.rpc("get_news_email_preference");if(error)return notify(error.message);const value=data as Preference;setPref(value);setSelected(value.subscribed)},[notify]);
 useEffect(()=>{const timer=setTimeout(()=>void load(),0);return()=>clearTimeout(timer)},[load]);
 const save=async()=>{setBusy(true);const{data,error}=await supabase.rpc("save_news_email_preference",{p_subscribed:selected});setBusy(false);if(error)return notify(error.message);setPref(data as Preference);notify(selected?"Weekly Legacy Equine Digest enabled.":"Weekly Legacy Equine Digest disabled.")};
 return <section className="panel digestpreferences"><div><p className="eyebrow">EMAIL PREFERENCES</p><h2>Legacy Equine Weekly Digest</h2><p>Receive one weekly roundup of major game updates, special Shows, contests and meaningful community news.</p></div>{pref?<><label className="digestoptin"><input type="checkbox" checked={selected} onChange={event=>setSelected(event.target.checked)}/><span><b>Email me the weekly game-news digest</b><small>This is optional and separate from essential account and security messages. You can unsubscribe at any time.</small></span></label><div className="digestpreferenceactions"><button className="primary" disabled={busy||selected===pref.subscribed} onClick={()=>void save()}>{busy?"Saving…":"Save Email Preference"}</button><span>{pref.subscribed&&pref.consented_at?`Subscribed ${new Date(pref.consented_at).toLocaleDateString()}`:"Not subscribed"}</span></div></>:<p>Loading email preference…</p>}</section>
}
