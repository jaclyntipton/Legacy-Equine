"use client";
import{useCallback,useEffect,useState}from"react";
import{createClient}from"@/lib/supabase/client";
import"./news-email-preferences.css";

const supabase=createClient();
type Preference={subscribed:boolean;consented_at:string|null;unsubscribed_at:string|null;prompted_at:string|null;frequency:"weekly"};

async function savePreference(subscribed:boolean){return supabase.rpc("save_news_email_preference",{p_subscribed:subscribed})}

export function NewsDigestSignInPrompt({notify}:{notify:(message:string)=>void}){
 const[open,setOpen]=useState(false),[busy,setBusy]=useState(false);
 useEffect(()=>{let active=true;const timer=setTimeout(()=>void supabase.rpc("get_news_email_preference").then(({data,error})=>{if(!active)return;if(error)return notify(error.message);setOpen(!(data as Preference).prompted_at)}),0);return()=>{active=false;clearTimeout(timer)}},[notify]);
 const choose=async(subscribed:boolean)=>{setBusy(true);const{error}=await savePreference(subscribed);setBusy(false);if(error)return notify(error.message);setOpen(false);notify(subscribed?"Weekly Legacy Equine Digest enabled.":"No problem — you can enable weekly updates later in Profile Settings.")};
 if(!open)return null;
 return <div className="digestpromptbackdrop" role="presentation"><section className="digestprompt" role="dialog" aria-modal="true" aria-labelledby="digest-prompt-title"><div className="digestpromptmark">LE</div><p className="eyebrow">STAY IN THE LOOP</p><h2 id="digest-prompt-title">Get the Legacy Equine Weekly Digest?</h2><p>Receive one weekly email with major game updates, special Shows, contests and important community news.</p><ul><li>Optional and easy to unsubscribe</li><li>No routine gameplay spam</li><li>Separate from essential account emails</li></ul><div><button className="primary" disabled={busy} onClick={()=>void choose(true)}>{busy?"Saving…":"GET WEEKLY UPDATES"}</button><button disabled={busy} onClick={()=>void choose(false)}>NOT NOW</button></div><small>You can change this anytime in My Profile → Settings.</small></section></div>
}

export function NewsEmailPreferences({notify}:{notify:(message:string)=>void}){
 const[pref,setPref]=useState<Preference|null>(null),[selected,setSelected]=useState(false),[busy,setBusy]=useState(false);
 const load=useCallback(async()=>{const{data,error}=await supabase.rpc("get_news_email_preference");if(error)return notify(error.message);const value=data as Preference;setPref(value);setSelected(value.subscribed)},[notify]);
 useEffect(()=>{const timer=setTimeout(()=>void load(),0);return()=>clearTimeout(timer)},[load]);
 const save=async()=>{setBusy(true);const{data,error}=await savePreference(selected);setBusy(false);if(error)return notify(error.message);setPref(data as Preference);notify(selected?"Weekly Legacy Equine Digest enabled.":"Weekly Legacy Equine Digest disabled.")};
 return <section className="panel digestpreferences"><div><p className="eyebrow">EMAIL PREFERENCES</p><h2>Legacy Equine Weekly Digest</h2><p>Receive one weekly roundup of major game updates, special Shows, contests and meaningful community news.</p></div>{pref?<><label className="digestoptin"><input type="checkbox" checked={selected} onChange={event=>setSelected(event.target.checked)}/><span><b>Email me the weekly game-news digest</b><small>This is optional and separate from essential account and security messages. You can unsubscribe at any time.</small></span></label><div className="digestpreferenceactions"><button className="primary" disabled={busy||selected===pref.subscribed} onClick={()=>void save()}>{busy?"Saving…":"Save Email Preference"}</button><span>{pref.subscribed&&pref.consented_at?`Subscribed ${new Date(pref.consented_at).toLocaleDateString()}`:"Not subscribed"}</span></div></>:<p>Loading email preference…</p>}</section>
}
