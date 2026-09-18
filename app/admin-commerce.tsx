"use client";
import{useCallback,useEffect,useState}from"react";
import{createClient}from"@/lib/supabase/client";
const supabase=createClient();
type Row=Record<string,unknown>;
type Workspace={config:Row|null;products:Row[];orders:Row[];subscriptions:Row[];entitlements:Row[];failures:Row[];reversals:Row[];audit:Row[]};
const empty:Workspace={config:null,products:[],orders:[],subscriptions:[],entitlements:[],failures:[],reversals:[],audit:[]};
const value=(input:unknown)=>typeof input==="object"?JSON.stringify(input):String(input??"—");
function Rows({rows,fields,emptyText}:{rows:Row[];fields:string[];emptyText:string}){return <div className="adminaccounts">{rows.map((row,index)=><div key={String(row.id??row.product_id??index)}><span>{fields.map((field,i)=>i===0?<b key={field}>{value(row[field])}</b>:<small key={field}>{field.replaceAll("_"," ")}: {value(row[field])}</small>)}</span></div>)}{!rows.length&&<p className="featurehint">{emptyText}</p>}</div>}
export function AdminCommerce({notify}:{notify:(message:string)=>void}){
 const[data,setData]=useState<Workspace>(empty),[loading,setLoading]=useState(true);
 const load=useCallback(async()=>{setLoading(true);const{data:result,error}=await supabase.rpc("admin_commerce_workspace");if(error)notify(error.message);else setData(result as Workspace);setLoading(false)},[notify]);
 useEffect(()=>{const timer=setTimeout(()=>void load(),0);return()=>clearTimeout(timer)},[load]);
 if(loading)return <section className="panel"><p>Loading Commerce readiness…</p></section>;
 return <div className="adminaccordions"><section className="panel settingsform"><p className="eyebrow">OWNER ONLY · COMMERCE READINESS</p><h2>Commerce</h2><p className="panelsub">Provider-neutral catalog, orders, subscriptions, entitlements, reversals, and audit. No checkout or live payment collection is enabled.</p><div className="systemstatus"><div><b>Live Payments</b><span className="health-not-configured">{data.config?.live_payments_enabled?"Enabled":"Disabled"}</span></div><div><b>Commerce Test Mode</b><span className="health-healthy">{data.config?.test_mode_enabled?"Ready":"Disabled"}</span></div><div><b>Payment Credentials</b><span>Never exposed here</span></div></div></section>
 <details open><summary>Product Catalog</summary><Rows rows={data.products} fields={["name","product_id","purchase_type","price_minor","currency","active","version","entitlement_effect"]} emptyText="No commerce products configured."/></details>
 <details><summary>Purchase History</summary><Rows rows={data.orders} fields={["id","account_id","product_id","amount_minor","currency","provider","mode","status","created_at"]} emptyText="No commerce orders recorded."/></details>
 <details><summary>Subscription Status</summary><Rows rows={data.subscriptions} fields={["id","account_id","product_id","status","mode","effective_at","end_at"]} emptyText="No commerce subscriptions recorded."/></details>
 <details><summary>Entitlement History</summary><Rows rows={data.entitlements} fields={["entitlement_key","account_id","action","grant_type","source_type","mode","created_at"]} emptyText="No commerce entitlement events recorded."/></details>
 <details><summary>Failed / Reversed Events</summary><Rows rows={[...data.failures,...data.reversals]} fields={["id","status","reason","error_message","created_at"]} emptyText="No failed or reversed commerce events."/></details>
 <details><summary>Audit Trail</summary><Rows rows={data.audit} fields={["action","account_id","order_id","mode","created_at","details"]} emptyText="No commerce audit entries."/></details></div>;
}
