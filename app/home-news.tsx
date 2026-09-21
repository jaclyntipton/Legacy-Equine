"use client";
/* eslint-disable @next/next/no-img-element */
import Link from"next/link";
import{useCallback,useEffect,useRef,useState}from"react";
import{createClient}from"@/lib/supabase/client";
import"./home-news.css";

const supabase=createClient();
type Post={id:string;title:string;summary:string;body:string;category:string;author_source:string;image_url:string|null;destination_url:string|null;pinned:boolean;published_at:string;source_type:string};
type FeedResponse={posts:Post[];new_count:number;last_viewed_at:string|null;published_count:number;eligible_count:number};
const labels:Record<string,string>={official:"Official News",updates:"Game Updates",shows:"Shows & Events",contests:"Contests",community:"Community"};
const filters=[["","All"],["official","Official"],["updates","Updates"],["shows","Shows & Events"],["contests","Contests"],["community","Community"]];
const quickLinks=[["/stable/horses","My Stable"],["/shows","Enter Shows"],["/store/foundation-horses","LE Store"],["/marketplace","Marketplace"],["/professions","Professions"],["/community","Community"]];
const articleIdFromPath=(path:string)=>path.match(/^\/news\/([0-9a-f-]{36})\/?$/i)?.[1]??"";
const dateLabel=(value:string)=>new Date(value).toLocaleDateString(undefined,{month:"short",day:"numeric",year:"numeric"});

export function HomeNews({notify,onNewCount,path="/home",navigate}:{notify:(m:string)=>void;onNewCount?:(n:number)=>void;path?:string;navigate?:(href:string)=>void}){
 const[posts,setPosts]=useState<Post[]>([]),[category,setCategory]=useState(""),[offset,setOffset]=useState(0),[more,setMore]=useState(false),[lastViewed,setLastViewed]=useState<string|null>(null),[article,setArticle]=useState<Post|null>(null),[articleLoading,setArticleLoading]=useState(false),filtersRef=useRef<HTMLDivElement>(null),articleId=articleIdFromPath(path);
 const load=useCallback(async(reset=true)=>{const start=reset?0:offset,{data,error}=await supabase.rpc("get_home_news",{p_category:category||null,p_offset:start,p_limit:20});if(error)return notify(error.message);const response=(data??{})as FeedResponse,rows=response.posts??[];setPosts(current=>reset?rows:[...current,...rows]);setMore(rows.length===20);setOffset(start+rows.length);setLastViewed(response.last_viewed_at??null);onNewCount?.(Number(response.new_count??0));await supabase.rpc("mark_news_viewed")},[category,notify,offset,onNewCount]);
 useEffect(()=>{if(articleId)return;filtersRef.current?.scrollTo({left:0});const timer=setTimeout(()=>void load(true),0);return()=>clearTimeout(timer)},[category,articleId]);
 useEffect(()=>{const timer=setTimeout(()=>{if(!articleId){setArticle(null);return}setArticleLoading(true);void supabase.rpc("get_news_article",{p_id:articleId}).then(({data,error})=>{setArticleLoading(false);if(error)notify(error.message);setArticle((data??null)as Post|null)})},0);return()=>clearTimeout(timer)},[articleId,notify]);
 const go=(href:string)=>navigate?navigate(href):window.location.assign(href),isNew=(post:Post)=>Boolean(lastViewed&&new Date(post.published_at)>new Date(lastViewed)),pinned=posts.filter(post=>post.pinned),around=category?[]:posts.filter(post=>post.source_type!=="editorial"&&post.source_type!=="system").slice(0,4);
 if(articleId)return <NewsArticle post={article} loading={articleLoading} back={()=>go("/home")}/>;
 return <div className="homenews">
  <header className="homeheadline"><p className="eyebrow">LEGACY EQUINE</p><h1>News &amp; Updates</h1><p>What&apos;s happening around Legacy Equine</p></header>
  {pinned.length>0&&<section className="featurednews" aria-labelledby="featured-news-title"><div className="sectionheading"><p className="eyebrow">FEATURED STORY</p><h2 id="featured-news-title">Featured / Important</h2></div><div className="featuredlist">{pinned.map(post=><NewsCard key={post.id} post={post} featured isNew={isNew(post)} open={()=>go(`/news/${post.id}`)}/>)}</div></section>}
  <div className="homecontentgrid">
   <section className="latestnews" aria-labelledby="latest-news-title"><div className="sectionheading"><p className="eyebrow">THE LATEST</p><h2 id="latest-news-title">Latest News</h2></div><div ref={filtersRef} className="newsfilterviewport" aria-label="News categories"><div className="newsfilters">{filters.map(([id,label])=><button className={category===id?"active":""} onClick={()=>setCategory(id)} key={id}>{label}</button>)}</div></div><div className="newsfeed">{posts.map(post=><NewsCard key={post.id} post={post} isNew={isNew(post)} open={()=>go(`/news/${post.id}`)}/>)}{!posts.length&&<p className="newsempty">No news in this category yet.</p>}</div>{more&&<button className="loadnews" onClick={()=>void load(false)}>LOAD MORE</button>}</section>
   <aside className="homenewsside"><section className="homequick"><div className="sectionheading"><p className="eyebrow">JUMP BACK IN</p><h2>Quick Links</h2></div><nav>{quickLinks.map(([href,label])=><Link href={href} key={href}>{label}<span>→</span></Link>)}</nav></section>{around.length>0&&<section className="aroundle"><div className="sectionheading"><p className="eyebrow">COMMUNITY MOMENTS</p><h2>Around Legacy Equine</h2></div><div>{around.map(post=><button key={post.id} onClick={()=>go(`/news/${post.id}`)}><span>{labels[post.category]??post.category}</span><b>{post.title}</b><small>{dateLabel(post.published_at)}</small></button>)}</div></section>}</aside>
  </div>
 </div>
}

function NewsCard({post,featured=false,isNew=false,open}:{post:Post;featured?:boolean;isNew?:boolean;open:()=>void}){return <article className={`newscard${featured?" featuredcard":""}`}>{post.image_url&&<img src={post.image_url} alt=""/>}<div className="newsstory"><p className="newsmeta">{labels[post.category]??post.category}<span>•</span>{dateLabel(post.published_at)}{isNew&&<b>NEW</b>}</p><h3>{post.title}</h3><p className="newssummary">{post.summary||post.body}</p><div className="newsactions"><button onClick={open}>{featured?"Read Article":"Read More"} →</button>{post.destination_url&&<Link href={post.destination_url}>View Details</Link>}</div></div></article>}

function NewsArticle({post,loading,back}:{post:Post|null;loading:boolean;back:()=>void}){if(loading)return <section className="newsarticle"><button className="newsback" onClick={back}>← Back to News</button><p>Loading article…</p></section>;if(!post)return <section className="newsarticle"><button className="newsback" onClick={back}>← Back to News</button><h1>Article unavailable</h1><p>This News article is not published or is no longer available.</p></section>;return <article className="newsarticle"><button className="newsback" onClick={back}>← Back to News</button><header><p className="newsmeta">{labels[post.category]??post.category}<span>•</span>{dateLabel(post.published_at)}</p><h1>{post.title}</h1>{post.summary&&<p className="newsarticlelead">{post.summary}</p>}</header>{post.image_url&&<img className="newsarticleimage" src={post.image_url} alt=""/>}<div className="newsarticlebody">{post.body}</div>{post.destination_url&&<Link className="newsarticlecta" href={post.destination_url}>View Details →</Link>}</article>}
