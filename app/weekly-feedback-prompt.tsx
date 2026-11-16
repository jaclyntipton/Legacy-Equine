"use client";
import{useEffect,useRef,useState}from"react";
import{createClient}from"@/lib/supabase/client";
import styles from"./weekly-feedback-prompt.module.css";
const supabase=createClient();
const gameplayPath=(path:string)=>/^\/(?:home|stable|horses|stables|players|store|marketplace|shows|training|professions|community|bank|sanctuary)(?:\/|\?|#|$)/.test(path);

export function WeeklyFeedbackPrompt({navigate}:{navigate:(href:string)=>void}){
 const[open,setOpen]=useState(false),interactions=useRef(0),checked=useRef(false),checking=useRef(false),navigateRef=useRef(navigate);navigateRef.current=navigate;
 useEffect(()=>{let timer=0;const activity=(event:MouseEvent)=>{if(open||checked.current||checking.current||!gameplayPath(`${location.pathname}${location.search}`))return;const target=event.target instanceof Element?event.target.closest("button,a,input,select"):null;if(!target||target.closest('[role="dialog"]'))return;interactions.current+=1;if(interactions.current<3)return;checked.current=true;timer=window.setTimeout(async()=>{if(document.querySelector('[role="dialog"],[aria-busy="true"]')){checked.current=false;return}checking.current=true;const status=await supabase.rpc("weekly_feedback_prompt_status");if(!status.error&&(status.data as{should_show?:boolean})?.should_show){const shown=await supabase.rpc("record_weekly_feedback_prompt",{p_action:"shown"});if(!shown.error&&shown.data)setOpen(true)}checking.current=false},2500)};document.addEventListener("click",activity,true);return()=>{document.removeEventListener("click",activity,true);window.clearTimeout(timer)}},[open]);
 const act=async(action:"later"|"never"|"share")=>{const source=`${location.pathname}${location.search}${location.hash}`;setOpen(false);await supabase.rpc("record_weekly_feedback_prompt",{p_action:action});if(action==="share")navigateRef.current(`/support?feedback=1&from=${encodeURIComponent(source)}`)};
 if(!open)return null;
 return <div className={styles.backdrop} role="dialog" aria-modal="true" aria-labelledby="beta-feedback-title"><section className={styles.card}><button className={styles.close} aria-label="Maybe later" onClick={()=>void act("later")}>×</button><p>BETA FEEDBACK</p><h2 id="beta-feedback-title">Help shape Legacy Equine</h2><span>Legacy Equine is still in beta, and your experience matters. Found a problem or thought of something that would make the game better?</span><div className={styles.actions}><button className={styles.primary} onClick={()=>void act("share")}>Share Feedback</button><button onClick={()=>void act("later")}>Maybe Later</button><button className={styles.text} onClick={()=>void act("never")}>Don&apos;t Ask Again</button></div></section></div>;
}
