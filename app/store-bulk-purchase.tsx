"use client";
import {useRef,useState}from"react";
import styles from"./store-bulk-purchase.module.css";

export function StoreBulkPurchase({department,price,balance,disabled,onBuy}:{department:"feed"|"tack";price:number;balance:number;disabled:boolean;onBuy:(quantity:number,requestKey:string)=>Promise<boolean>}){
 const max=department==="feed"?50:10,quick=department==="feed"?[1,5,10,25,50]:[1,2,5,10],initial=department==="feed"?10:1;
 const[quantity,setQuantity]=useState(initial),[custom,setCustom]=useState(false),[buying,setBuying]=useState(false),request=useRef("");
 const setSafe=(value:number)=>setQuantity(Math.max(1,Math.min(max,Math.trunc(value)||1)));
 const buy=async()=>{if(buying)return;setBuying(true);request.current ||= crypto.randomUUID();const success=await onBuy(quantity,request.current);if(success)request.current="";setBuying(false)};
 return <div className={styles.purchase}>
  <div className={styles.quick} aria-label="Quick quantities">{quick.map(value=><button type="button" className={quantity===value&&!custom?styles.active:""} key={value} onClick={()=>{setCustom(false);setSafe(value)}}>{value}</button>)}<button type="button" className={custom?styles.active:""} onClick={()=>setCustom(true)}>Custom</button></div>
  <div className={styles.stepper}><span>Quantity</span><button type="button" aria-label="Decrease quantity" onClick={()=>setSafe(quantity-1)} disabled={quantity<=1}>−</button><input aria-label="Purchase quantity" type="number" inputMode="numeric" min="1" max={max} value={quantity} onFocus={()=>setCustom(true)} onChange={event=>{setCustom(true);setSafe(Number(event.target.value))}}/><button type="button" aria-label="Increase quantity" onClick={()=>setSafe(quantity+1)} disabled={quantity>=max}>+</button></div>
  <div className={styles.total}><small>Price each: {price.toLocaleString()} LED</small><strong>Total: {(price*quantity).toLocaleString()} LED</strong></div>
  <button type="button" className={`primary ${styles.buy}`} disabled={disabled||buying||balance<price*quantity} onClick={()=>void buy()}>{buying?"BUYING…":`BUY ${quantity}`}</button>
 </div>;
}
