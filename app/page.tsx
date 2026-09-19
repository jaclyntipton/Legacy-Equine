/* eslint-disable @next/next/no-img-element, react-hooks/static-components */
"use client";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { User } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/client";
import { GAME } from "@/lib/game/config";
import { ProfessionalCenter } from "@/app/professions";
import { PublicStableProfile } from "@/app/public-stable-profile";
import { PlayerShows } from "@/app/shows-v2";
import { TreasuryDashboard } from "@/app/treasury";
import { CommunityHub,PublicPlayerProfile } from "@/app/community-directory";
import { Bank } from "@/app/bank";
import { HorseProfile as HorsePage } from "@/app/horse-profile";
import { HorseImageTemplates } from "@/app/horse-image-templates";
import { BreedGeneticsAdmin } from "@/app/breed-genetics-admin";
import { VisualAssetRequirements } from "@/app/visual-asset-requirements";
import { StableInventory } from "@/app/stable-inventory";
import { StoreBulkPurchase } from "@/app/store-bulk-purchase";
import "@/app/store-filter-controls.css";
import { StoreWellnessAdmin } from "@/app/store-wellness-admin";
import { VisualAssetImporter } from "@/app/visual-asset-importer";
import { PublicAuth } from "@/app/public-auth";
import { StableBrandSettings } from "@/app/stable-brand-settings";
import { StableBrandsAdmin } from "@/app/stable-brands-admin";
import { NavIcon } from "@/app/nav-icons";
import { ContainedHorseArtwork } from "@/app/contained-horse-artwork";
import { ArtworkStorageAdmin } from "@/app/artwork-storage-admin";
import { ArtworkAlbum } from "@/app/artwork-album";
import { AdminShows } from "@/app/admin-shows";
import { AdminProfessions } from "@/app/admin-professions";
import { AdminCommerce } from "@/app/admin-commerce";
import { HomeNews } from "@/app/home-news";
import { AdminNews } from "@/app/admin-news";
import { isUniqueHorseArtwork } from "@/lib/game/horse-artwork";
import {competitionTier,type CompetitionTier} from "@/lib/game/show-engine";

type Horse = {
  id: string;
  owner_id: string | null;
  name: string;
  breed: string;
  sex: "Mare" | "Stallion" | "Gelding";
  color: string;
  origin: "Foundation" | "Bred" | "Admin Custom";
  birth_date: string;
  sire_id: string | null;
  dam_id: string | null;
  generation: number;
  career_points: number;
  birth_stats: Record<string, number>;
  stats: Record<string, number>;
  genetics: Record<string, string[]>;
  height_genetics: Record<string, string[]>;
  mature_height_hands: number;
  breed_composition: Record<string, number>;
  tack_bonuses: Record<string, number>;
  biography: string;
  image_url: string;
  image_generation_status?: string;
  stud_fee: number;
  last_bred_at: string | null;
  last_trained_at: string | null;
  retired: boolean;
  brand_code_at_assignment?: string | null;
  brand_mark_at_assignment?: string | null;
  brand_origin?: string | null;
  breeder_name_at_birth?: string | null;
  breeder_account_at_birth?: number | null;
};
type Stable = {
  id: string;
  account_number: number;
  name: string;
  username: string | null;
  bio: string;
  ranch_image_url: string;
  avatar_url: string;
  balance: number;
  foundation_purchases: number;
  created_at: string;
  is_admin: boolean;
  account_xp: number;
};
type AccountProgression={account_xp:number;level:number;legacy_stable:boolean;next_level_xp:number|null;weekly_allowance:number;shows_hosted_this_week:number;weekly_show_limit:number;custom_stable_layout:boolean};
type StableCapacity = {occupied:number;base_capacity:number;purchased_capacity:number;complimentary_capacity:number;total_capacity:number;unlimited:boolean;available:number|null};
type SanctuaryHorse = {id:string;name:string;breed:string;sex:"Mare"|"Stallion";color:string;birth_date:string;image_url:string;career_points:number;sanctuary_retired_at:string;former_owner_name:string;former_owner_account:number;former_owner_id:string};
type AdminStable = {
  id: string;
  account_number: number;
  name: string;
  username: string | null;
  balance: number;
  is_admin: boolean;
  stable_occupied: number;
  stable_capacity: number;
  unlimited_capacity: boolean;
  can_edit_horses: boolean;
};
type StoreHorse = {
  inventory_id: string;
  horse_id: string;
  name: string;
  breed: string;
  sex: "Mare" | "Stallion";
  color: string;
  birth_date: string;
  stats: Record<string, number>;
  image_url: string;
  mature_height_hands: number;
  price: number;
  generated_at: string;
  rotation_key: string;
};
type StoreProduct={id:string;department:"feed"|"tack"|"stable_supplies";name:string;description:string;price:number;feed_type:"hay"|"grain"|null;daily_starting_stock:number|null;remaining_stock:number|null;le_day:string|null;storage_used:number|null;storage_capacity:number|null;storage_unlimited:boolean|null;storage_available:number|null;feed_success_probability:number|null;development_min:number|null;development_max:number|null;eligible_stats:string[]|null;tack_slot:string|null;quality:string|null;tack_bonuses:Record<string,number>;icon_url:string|null;sort_order:number};
type Show = {
  id: string;
  discipline: string;
  class_name: string;
  starts_at: string;
  entry_count: number;
};
type MarketHorse = {
  listing_id: string;
  seller_id: string;
  horse_id: string;
  name: string;
  breed: string;
  sex: "Mare" | "Stallion";
  color: string;
  birth_date: string;
  stats: Record<string, number>;
  image_url: string;
  price: number;
  seller_name: string;
  seller_username: string | null;
  created_at: string;
  brand_code_at_assignment: string | null;
  brand_mark_at_assignment: string | null;
  brand_origin: string | null;
};
type ForumPost = {
  id: string;
  parent_id: string | null;
  body: string;
  created_at: string;
  stable_name: string;
  username: string;
  account_number: number;
  avatar_url: string;
};
const supabase = createClient();
type MainView="home"|"stable"|"publicstable"|"publicplayer"|"profile"|"store"|"storehorse"|"horse"|"pedigree"|"progeny"|"bank"|"training"|"shows"|"market"|"community"|"professions"|"sanctuary"|"stalls"|"settings"|"admin";
type StableTab="horses"|"tack"|"feed"|"supplies";type ProfileTab="profile"|"artwork"|"settings";type StoreDepartment="horses"|"feed"|"tack"|"supplies";
const routeFor=(view:MainView,state?:{stableTab?:StableTab;profileTab?:ProfileTab;storeDepartment?:StoreDepartment;selected?:string|null;storeSelected?:string|null;storeBreed?:string;publicStableId?:string;publicPlayerId?:string})=>{let path="/stable";if(view==="stable")path=state?.stableTab==="horses"?"/stable/horses":state?.stableTab==="tack"?"/stable/tack-room":state?.stableTab==="feed"?"/stable/feed-room":state?.stableTab==="supplies"?"/stable/supply-room":"/stable";else if(view==="publicstable"&&state?.publicStableId)path=`/stables/${state.publicStableId}`;else if(view==="publicplayer"&&state?.publicPlayerId)path=`/players/${state.publicPlayerId}`;else if(view==="profile")path=state?.profileTab==="artwork"?"/profile/artwork":state?.profileTab==="settings"?"/profile/settings":"/profile";else if(view==="store")path=state?.storeDepartment==="feed"?"/store/feed":state?.storeDepartment==="tack"?"/store/tack":state?.storeDepartment==="supplies"?"/store/supplies":"/store/foundation-horses";else if(view==="storehorse"&&state?.storeSelected)path=`/store/horses/${state.storeSelected}`;else if(view==="horse"&&state?.selected)path=`/horses/${state.selected}`;else path=`/${view==="market"?"marketplace":view}`;const query=view==="store"&&state?.storeBreed?`?breed=${encodeURIComponent(state.storeBreed)}`:"";return path+query};
const locationState=()=>{const path=location.pathname,query=new URLSearchParams(location.search),result:{view:MainView;stableTab?:StableTab;profileTab?:ProfileTab;storeDepartment?:StoreDepartment;selected?:string;storeSelected?:string;storeBreed?:string;publicStableId?:string;publicPlayerId?:string}={view:"home"};if(/^\/players\/[^/]+/.test(path)){result.view="publicplayer";result.publicPlayerId=path.split("/")[2]}else if(/^\/stables\/[^/]+/.test(path)){result.view="publicstable";result.publicStableId=path.split("/")[2]}else if(path.startsWith("/profile")){result.view="profile";result.profileTab=path.endsWith("/artwork")?"artwork":path.endsWith("/settings")?"settings":"profile"}else if(path.startsWith("/stable")){result.view="stable";result.stableTab=path.endsWith("/tack-room")?"tack":path.endsWith("/feed-room")?"feed":path.endsWith("/supply-room")?"supplies":"horses"}else if(/^\/horses\/[^/]+/.test(path)){result.view="horse";result.selected=path.split("/")[2]}else if(/^\/store\/horses\/[^/]+/.test(path)){result.view="storehorse";result.storeSelected=path.split("/")[3]}else if(path.startsWith("/store")){result.view="store";result.storeDepartment=path.endsWith("/feed")?"feed":path.endsWith("/tack")?"tack":path.endsWith("/supplies")?"supplies":"horses";result.storeBreed=query.get("breed")??""}else{const key=path.slice(1);result.view=path.startsWith("/admin")?"admin":path.startsWith("/community")?"community":path.startsWith("/professions")?"professions":key==="marketplace"?"market":(["home","bank","training","shows","community","professions","sanctuary","stalls"].includes(key)?key:"home")as MainView}return result};
function GlobalToast({message,dismiss}:{message:string;dismiss:()=>void}){const persistent=/error|failed|unable|couldn.?t|insufficient|not enough|required|unavailable|invalid|denied|choose|full|warning/i.test(message);useEffect(()=>{if(!message||persistent)return;const timer=setTimeout(dismiss,2800);return()=>clearTimeout(timer)},[message,persistent,dismiss]);if(!message)return null;return <div className={`globaltoast ${persistent?"error":"success"}`} role={persistent?"alert":"status"}><span>{message}</span><button aria-label="Dismiss notification" onClick={dismiss}>×</button></div>}
const money = (n: number) => new Intl.NumberFormat("en-US").format(n);
const STORE_TIERS=["Entry","Quality","Elite","Legendary"] as const;
const tackCategoryLabel=(slot:string|null)=>slot==="bridle"?"Bridles":slot==="saddle"?"Saddles":slot==="saddle_pad"?"Saddle Pads":slot==="leg_protection"?"Leg Protection":"Tack";
const productPlaceholder=(product:StoreProduct)=>product.department==="feed"?"FH":product.tack_slot==="bridle"?"BR":product.tack_slot==="saddle"?"SA":product.tack_slot==="saddle_pad"?"SP":"LP";
const compactNumber = (n: number) => {
  const units = [
    [1e18, "Qi"],
    [1e15, "Qa"],
    [1e12, "T"],
    [1e9, "B"],
    [1e6, "M"],
    [1e3, "K"],
  ] as const;
  const unit = units.find(([threshold]) => Math.abs(n) >= threshold);
  if (!unit) return money(n);
  return `${new Intl.NumberFormat("en-US", { maximumFractionDigits: 2 }).format(n / unit[0])}${unit[1]}`;
};
const handHeight = (value: number) => {
  const whole = Math.floor(value),
    inches = Math.round((value - whole) * 10),
    total = whole * 4 + inches,
    remainder = total % 4;
  return `${Math.floor(total / 4)}${remainder ? `.${remainder}` : ""}h`;
};
const overall = (h: Horse) =>
  GAME.stats.reduce(
    (n, k) => n + (h.stats[k] ?? 0) + (h.tack_bonuses[k] ?? 0),
    0,
  );
const age = (h: Horse) =>
  Math.max(
    0,
    (((Date.now() - new Date(h.birth_date).getTime()) / 86400000) *
      GAME.age.gameDaysPerRealDay) /
      365.25,
  );
const ageLabel = (h: Horse) => {
  const months = Math.floor(age(h) * 12);
  const years = Math.floor(months / 12);
  const remainder = months % 12;
  return `${years} ${years === 1 ? "year" : "years"}${remainder ? `, ${remainder} ${remainder === 1 ? "month" : "months"}` : ""}`;
};
const canTrain = (h: Horse) =>
  age(h) >= GAME.age.trainingMinimumYears &&
  (!h.last_trained_at ||
    Date.now() - new Date(h.last_trained_at).getTime() >=
      GAME.training.cooldownHours * 3600000);
const canBreed = (h: Horse) =>
  !h.retired &&
  age(h) >= GAME.age.breedingMinimumYears &&
  age(h) < GAME.age.breedingMaximumYears + 1 &&
  (h.sex === "Stallion" ||
    !h.last_bred_at ||
    Date.now() - new Date(h.last_bred_at).getTime() >=
      GAME.mareCooldownDays * 86400000);
async function uploadMedia(
  file: File,
  _category: "ranches" | "avatars" | "horses",
) {
  if (
    !["image/jpeg", "image/png", "image/webp"].includes(file.type)
  )
    throw new Error("Choose a JPG, PNG, or WebP image");
  if (file.size > 5 * 1024 * 1024)
    throw new Error("Images must be 5 MB or smaller");
  const { data } = await supabase.auth.getUser();
  if (!data.user) throw new Error("Sign in to upload images");
  const bitmap=await createImageBitmap(file),scale=Math.min(1,1200/bitmap.width,1200/bitmap.height),width=Math.round(bitmap.width*scale),height=Math.round(bitmap.height*scale),canvas=document.createElement("canvas");canvas.width=width;canvas.height=height;canvas.getContext("2d")!.drawImage(bitmap,0,0,width,height);bitmap.close();
  const processed=scale<1?await new Promise<Blob>((resolve,reject)=>canvas.toBlob(value=>value?resolve(value):reject(new Error("Image processing failed")),file.type,.9)):file;
  const ext=file.type==="image/jpeg"?"jpg":file.type.split("/")[1],{data:reservation,error:reserveError}=await supabase.rpc("reserve_artwork_album_upload",{p_mime:processed.type,p_byte_size:processed.size,p_extension:ext});if(reserveError)throw reserveError;
  const path=(reservation as {storage_path:string}).storage_path,item=(reservation as {id:string}).id;
  const { error } = await supabase.storage
    .from("legacy-equine-media")
    .upload(path, processed, { cacheControl: "3600" });
  if (error){await supabase.rpc("remove_artwork_album_item",{p_item:item});throw error;}
  const{error:finalizeError}=await supabase.rpc("finalize_artwork_album_upload",{p_item:item,p_width:width,p_height:height});if(finalizeError){await supabase.storage.from("legacy-equine-media").remove([path]);await supabase.rpc("remove_artwork_album_item",{p_item:item});throw finalizeError;}
  return supabase.storage.from("legacy-equine-media").getPublicUrl(path).data
    .publicUrl;
}

export default function Home() {
  const [user, setUser] = useState<User | null>(null),
    [stable, setStable] = useState<Stable | null>(null),
    [progression,setProgression]=useState<AccountProgression|null>(null),
    [capacity, setCapacity] = useState<StableCapacity | null>(null),
    [sanctuary, setSanctuary] = useState<SanctuaryHorse[]>([]),
    [competitionTiers,setCompetitionTiers]=useState<CompetitionTier[]>([]),
    [canHorseEdit,setCanHorseEdit]=useState(false),
    [horses, setHorses] = useState<Horse[]>([]),
    [inventory, setInventory] = useState<StoreHorse[]>([]),
    [shows, setShows] = useState<Show[]>([]),
    [market, setMarket] = useState<MarketHorse[]>([]),
    [posts, setPosts] = useState<ForumPost[]>([]),
    [loading, setLoading] = useState(true),
    [notice, setNotice] = useState(""),
    [view, setView] = useState<MainView>("home"),
    [selected, setSelected] = useState<string | null>(null),
    [storeSelected, setStoreSelected] = useState<string | null>(null),
    [horseQuery, setHorseQuery] = useState(""),
    [horseBreed, setHorseBreed] = useState("all"),
    [horseSex, setHorseSex] = useState("all"),
    [horseOrigin, setHorseOrigin] = useState("all"),
    [horseAge, setHorseAge] = useState("all"),
    [horseTier, setHorseTier] = useState("all"),
    [horseBreeding, setHorseBreeding] = useState("all"),
    [horseSort, setHorseSort] = useState("name"),
    [horseView, setHorseView] = useState<"cards" | "compact">("cards"),
    [mobileMenuOpen,setMobileMenuOpen]=useState(false),
    [showExactBalance,setShowExactBalance]=useState(false),
    [newsNew,setNewsNew]=useState(0);
  const [stableTab,setStableTab]=useState<StableTab>("horses"),[profileTab,setProfileTab]=useState<ProfileTab>("profile"),[purchaseDestination,setPurchaseDestination]=useState<{label:string;tab:"tack"|"feed"|"supplies"}|null>(null);
  const [publicStableId,setPublicStableId]=useState("");
  const [publicPlayerId,setPublicPlayerId]=useState("");
  const [storeDepartment,setStoreDepartment]=useState<StoreDepartment>("horses"),[storeBreed,setStoreBreed]=useState(""),[storeHorseQuery,setStoreHorseQuery]=useState(""),[storeProducts,setStoreProducts]=useState<StoreProduct[]>([]);
  const [productType,setProductType]=useState("all"),[productTier,setProductTier]=useState("all"),[productSort,setProductSort]=useState("tier-asc"),[productQuery,setProductQuery]=useState("");
  const artworkWorker = useRef<Promise<void> | null>(null);
  const applyLocation=useCallback(()=>{const state=locationState();setView(state.view);if(state.stableTab)setStableTab(state.stableTab);if(state.profileTab)setProfileTab(state.profileTab);if(state.publicStableId)setPublicStableId(state.publicStableId);if(state.publicPlayerId)setPublicPlayerId(state.publicPlayerId);if(state.storeDepartment)setStoreDepartment(state.storeDepartment);if(state.selected)setSelected(state.selected);if(state.storeSelected)setStoreSelected(state.storeSelected);if(state.storeBreed!==undefined)setStoreBreed(state.storeBreed)},[]);
  const navigate=useCallback((next:MainView,overrides?:{stableTab?:StableTab;profileTab?:ProfileTab;storeDepartment?:StoreDepartment;selected?:string|null;storeSelected?:string|null;storeBreed?:string;publicStableId?:string;publicPlayerId?:string})=>{const state={stableTab,profileTab,storeDepartment,selected,storeSelected,storeBreed,publicStableId,publicPlayerId,...overrides};history.pushState({le:true},"",routeFor(next,state));setView(next);if(overrides?.stableTab)setStableTab(overrides.stableTab);if(overrides?.profileTab)setProfileTab(overrides.profileTab);if(overrides?.publicStableId)setPublicStableId(overrides.publicStableId);if(overrides?.publicPlayerId)setPublicPlayerId(overrides.publicPlayerId);if(overrides?.storeDepartment)setStoreDepartment(overrides.storeDepartment);if(overrides?.selected!==undefined)setSelected(overrides.selected);if(overrides?.storeSelected!==undefined)setStoreSelected(overrides.storeSelected);if(overrides?.storeBreed!==undefined)setStoreBreed(overrides.storeBreed)},[stableTab,profileTab,storeDepartment,selected,storeSelected,storeBreed,publicStableId,publicPlayerId]);
  const openStoreDepartment=(department:StoreDepartment)=>{setProductType("all");setProductTier("all");setProductSort("tier-asc");setProductQuery("");navigate("store",{storeDepartment:department})};
  const mobileNavigate=useCallback((next:MainView,overrides?:Parameters<typeof navigate>[1])=>{setMobileMenuOpen(false);navigate(next,overrides)},[navigate]);
  const dismissNotice=useCallback(()=>setNotice(""),[]);
  useEffect(()=>{applyLocation();const back=()=>applyLocation();addEventListener("popstate",back);return()=>removeEventListener("popstate",back)},[applyLocation]);
  const load = useCallback(async (u: User | null) => {
    setUser(u);
    if (!u) {
      setStable(null);
      setHorses([]);
      setLoading(false);
      return;
    }
    const [{ data: s, error: stableError }, { data: h }, { data: c },{data:tierData},{data:horseEditorAccess},{data:progressData}] = await Promise.all([
        supabase
          .from("stables")
          .select(
            "id,account_number,name,username,bio,ranch_image_url,avatar_url,balance,foundation_purchases,created_at,is_admin,account_xp",
          )
          .eq("id", u.id)
          .maybeSingle(),
        supabase
          .from("horses")
          .select("*")
          .eq("owner_id", u.id)
          .order("created_at"),
        supabase.rpc("get_my_stable_capacity"),
        supabase.from("show_tiers").select("id,name,minimum_points,maximum_points,sort_order").eq("active",true).order("sort_order"),
        supabase.rpc("has_horse_editor_permission"),
        supabase.rpc("get_account_progression"),
      ]);
    if (stableError) setNotice(stableError.message);
    setStable(s);
    setHorses((h ?? []) as Horse[]);
    setCapacity((c ?? null) as StableCapacity | null);
    setCompetitionTiers((tierData??[])as CompetitionTier[]);
    setCanHorseEdit(Boolean(horseEditorAccess));
    setProgression((progressData??null) as AccountProgression|null);
    setLoading(false);
  }, []);
  useEffect(() => {
    void supabase.auth.getUser().then(({ data }) => load(data.user));
    const { data } = supabase.auth.onAuthStateChange((_e, s) => {
      setTimeout(() => {
        void load(s?.user ?? null);
      }, 0);
    });
    return () => data.subscription.unsubscribe();
  }, [load]);
  const action = async (
    fn: () => Promise<{ error: Error | null }>,
    success: string,
  ) => {
    setLoading(true);
    const { error } = await fn();
    setNotice(error?.message ?? success);
    await load(user);
    setLoading(false);
  };
  const horse = horses.find((h) => h.id === selected) || null;
  useEffect(()=>{if(view!=="horse"||!selected||horse)return;let active=true;void supabase.from("horses").select("*").eq("id",selected).maybeSingle().then(({data,error})=>{if(!active)return;if(error)setNotice(error.message);else if(data)setHorses(current=>current.some(candidate=>candidate.id===data.id)?current:[...current,data as Horse])});return()=>{active=false}},[view,selected,horse]);
  const visibleHorses = useMemo(() => {
    const tierName = (points: number) => competitionTier(points,competitionTiers)?.name??"Unassigned";
    const filtered = horses.filter((h) => {
      const years = age(h);
      const ageMatch = horseAge === "all" || (horseAge === "young" && years < 2) || (horseAge === "breeding" && years >= 2 && years < 26) || (horseAge === "senior" && years >= 26);
      return h.name.toLowerCase().includes(horseQuery.trim().toLowerCase()) && (horseBreed === "all" || h.breed === horseBreed) && (horseSex === "all" || h.sex === horseSex) && (horseOrigin === "all" || h.origin === horseOrigin) && ageMatch && (horseTier === "all" || tierName(h.career_points) === horseTier) && (horseBreeding === "all" || (horseBreeding === "eligible") === canBreed(h));
    });
    return filtered.sort((a, b) => horseSort === "name" ? a.name.localeCompare(b.name) : horseSort === "age" ? age(b) - age(a) : horseSort === "newest" ? new Date(b.birth_date).getTime() - new Date(a.birth_date).getTime() : horseSort === "career" ? b.career_points - a.career_points : GAME.stats.includes(horseSort as typeof GAME.stats[number]) ? (b.stats[horseSort] ?? 0) - (a.stats[horseSort] ?? 0) : 0);
  }, [horses, horseQuery, horseBreed, horseSex, horseOrigin, horseAge, horseTier, horseBreeding, horseSort,competitionTiers]);
  const feedQualityOrder=useMemo(()=>[...new Set(storeProducts.filter(product=>product.department==="feed"&&product.quality).sort((a,b)=>a.sort_order-b.sort_order).map(product=>product.quality!))],[storeProducts]);
  const visibleStoreHorses=useMemo(()=>{const query=storeHorseQuery.trim().toLowerCase();return inventory.filter(h=>(!storeBreed||h.breed===storeBreed)&&(!query||`${h.name} ${h.breed} ${h.sex} ${h.color}`.toLowerCase().includes(query)))},[inventory,storeBreed,storeHorseQuery]);
  const visibleStoreProducts=useMemo(()=>{const tierOrder=storeDepartment==="tack"?[...STORE_TIERS]:feedQualityOrder;return storeProducts.filter(product=>product.department===storeDepartment&&(productType==="all"||(storeDepartment==="tack"?product.tack_slot===productType:product.feed_type===productType))&&(productTier==="all"||product.quality===productTier)&&`${product.name} ${product.description}`.toLowerCase().includes(productQuery.trim().toLowerCase())).sort((a,b)=>productSort==="price-asc"?a.price-b.price:productSort==="price-desc"?b.price-a.price:(tierOrder.indexOf(a.quality??"")-tierOrder.indexOf(b.quality??""))*(productSort==="tier-desc"?-1:1)||a.sort_order-b.sort_order)},[storeProducts,storeDepartment,productType,productTier,productSort,productQuery,feedQualityOrder]);
  const open = (h: Horse) => {
    setSelected(h.id);
    navigate("horse",{selected:h.id});
  };
  const loadStore = useCallback(async () => {
    const [{data,error},{data:products},{data:feedCatalog,error:feedError}]=await Promise.all([supabase.rpc("get_store_inventory"),supabase.from("store_products").select("*").eq("active",true).neq("department","feed").order("sort_order"),supabase.rpc("get_store_feed_catalog")]);
    if (error) setNotice(error.message);
    else setInventory((data ?? []) as StoreHorse[]);
    if(feedError)setNotice(feedError.message);
    setStoreProducts([...(products??[]),...((feedCatalog??[])as StoreProduct[])]as StoreProduct[]);
  }, []);
  const generateStoreArtwork = useCallback(async () => {
    // Production per-horse AI generation is retired. Visuals are assigned
    // deterministically from approved library assets by the database.
    return artworkWorker.current ?? Promise.resolve();
  }, []);
  const openStore = () => navigate("store",{storeDepartment:"horses"});
  const loadSanctuary = useCallback(async()=>{const{data,error}=await supabase.rpc("get_sanctuary_horses",{search_text:"",breed_filter:"",sex_filter:"",retired_year:null});if(error)setNotice(error.message);else setSanctuary((data??[])as SanctuaryHorse[])},[]);
  useEffect(() => {
    if (!user) return;
    const timer = setTimeout(() => {
      void generateStoreArtwork();
    }, 0);
    return () => clearTimeout(timer);
  }, [user, generateStoreArtwork]);
  useEffect(() => {
    if (!user || view !== "store") return;
    const timer = setTimeout(() => {
      void loadStore().then(generateStoreArtwork);
    }, 0);
    return () => clearTimeout(timer);
  }, [user, view, loadStore, generateStoreArtwork]);
  const artworkPending = horses.some((candidate) => candidate.image_generation_status==="pending"||candidate.image_generation_status==="processing") || inventory.some((candidate) => !candidate.image_url);
  useEffect(() => {
    if (!user || !artworkPending) return;
    const timer = window.setInterval(() => void generateStoreArtwork(), 30_000);
    return () => window.clearInterval(timer);
  }, [user, artworkPending, generateStoreArtwork]);
  useEffect(()=>{if(view==="sanctuary")void loadSanctuary()},[view,loadSanctuary]);
  const storeHorse =
    inventory.find((h) => h.inventory_id === storeSelected) || null;
  const purchase = async (id: string) => {
    await action(async () => {
      const { error } = await supabase.rpc("purchase_store_horse", {
        target_inventory: id,
      });
      return { error };
    }, "Wonderful choice! Your new Foundation horse is waiting at your stable.");
    await loadStore();
    navigate("store",{storeDepartment:"horses"});
  };
  const loadShows = useCallback(async () => {
      const { data, error } = await supabase.rpc("get_open_shows");
      if (error) setNotice(error.message);
      else setShows((data ?? []) as Show[]);
    }, []),
    loadMarket = useCallback(async () => {
      const { data, error } = await supabase.rpc("get_marketplace");
      if (error) setNotice(error.message);
      else setMarket((data ?? []) as MarketHorse[]);
    }, []),
    loadPosts = useCallback(async () => {
      const { data, error } = await supabase.rpc("get_forum_posts");
      if (error) setNotice(error.message);
      else setPosts((data ?? []) as ForumPost[]);
    }, []);
  useEffect(() => {
    const timer = setTimeout(() => {
      if (view === "shows") void loadShows();
      if (view === "market") void loadMarket();
      if (view === "community") void loadPosts();
    }, 0);
    return () => clearTimeout(timer);
  }, [view, loadShows, loadMarket, loadPosts]);
  const uploadStableMedia = async (kind: "ranch" | "avatar", file: File) => {
    setLoading(true);
    try {
      const url = await uploadMedia(
        file,
        kind === "ranch" ? "ranches" : "avatars",
      );
      const { error } = await supabase.rpc("update_stable_images", {
        new_ranch_image_url:
          kind === "ranch" ? url : (stable?.ranch_image_url ?? ""),
        new_avatar_url: kind === "avatar" ? url : (stable?.avatar_url ?? ""),
      });
      setNotice(
        error?.message ??
          `${kind === "ranch" ? "Ranch image" : "Player avatar"} updated.`,
      );
    } catch (error) {
      setNotice(error instanceof Error ? error.message : "Image upload failed");
    }
    await load(user);
    setLoading(false);
  };
  const uploadHorseMedia = async (h: Horse, file: File) => {
    setLoading(true);
    try {
      const url = await uploadMedia(file, "horses");
      const { error } = await supabase.rpc("update_horse_profile", {
        target_horse: h.id,
        new_name: h.name,
        new_biography: h.biography,
        new_image_url: url,
      });
      if (error) throw error;
      setNotice(`${h.name}'s image was updated.`);
      await load(user);
      return url;
    } catch (error) {
      setNotice(error instanceof Error ? error.message : "Image upload failed");
      return null;
    } finally {
      setLoading(false);
    }
  };
  const breedWithWarning = async (stallionId: string, mareId: string) => {
    const { data: preview, error: previewError } = await supabase.rpc(
      "get_breeding_genetic_preview",
      { stallion_id: stallionId, mare_id: mareId },
    );
    if (previewError) {
      setNotice(previewError.message);
      return;
    }
    const total = Number(preview.total_lethal_percent ?? 0);
    if (total > 0) {
      const details = (preview.lethal_risks ?? [])
        .map(
          (r: { condition: string; chance_percent: number }) =>
            `${r.condition}: ${r.chance_percent}%`,
        )
        .join("\n");
      if (
        !window.confirm(
          `Genetic breeding warning\n\nThere is a ${total}% combined chance of a non-viable lethal genotype. If inherited, no foal will be created and no fee will be charged.\n\n${details}\n\nContinue with this pairing?`,
        )
      )
        return;
    }
    await action(async () => {
      const { error } = await supabase.rpc("breed_horses", {
        stallion_id: stallionId,
        mare_id: mareId,
      });
      return { error };
    }, `Your ${preview.result_breed} foal was born.`);
    void generateStoreArtwork();
  };
  if (loading && !user) return <div className="loading">LEGACY EQUINE</div>;
  if (!user||location.pathname==="/reset-password"||location.pathname==="/auth/confirm") return <PublicAuth />;
  if (!stable)
    return (
      <CreateStable
        loading={loading}
        message={notice}
        onCreate={async (name) =>
          action(async () => {
            const { error } = await supabase.rpc("initialize_stable", {
              stable_name: name,
            });
            return { error };
          }, "Your stable is ready.")
        }
      />
    );
  return (
    <div className="shell">
      <header className="mobile-header">
        <button className="mobile-brand" onClick={()=>mobileNavigate("home")}><span>LE</span><b>Legacy Equine™</b></button>
        <button className="mobile-balance" aria-expanded={showExactBalance} onClick={()=>setShowExactBalance(value=>!value)}><span>LE</span><b>{compactNumber(stable.balance)} LED</b></button>
        <button className="menu-toggle" aria-label="Open navigation menu" aria-expanded={mobileMenuOpen} onClick={()=>setMobileMenuOpen(true)}>☰</button>
        {showExactBalance&&<div className="exact-balance" role="status">{money(stable.balance)} LED</div>}
      </header>
      {mobileMenuOpen&&<div className="mobile-menu-backdrop" onClick={()=>setMobileMenuOpen(false)}>
        <aside className="mobile-menu" role="dialog" aria-modal="true" aria-label="Legacy Equine navigation" onClick={event=>event.stopPropagation()}>
          <div className="mobile-menu-title"><span>LE</span><b>Legacy Equine™</b><button aria-label="Close navigation menu" onClick={()=>setMobileMenuOpen(false)}>×</button></div>
          <p>GAME</p>
          <nav>{[
            ["home","bulletin",newsNew?`Home · ${newsNew} New`:"Home"],["stable","barn","My Stable"],["store","store","LE Store"],["training","round-pen","Training"],["shows","trophy","Shows"],["market","sale-tag","Marketplace"],["professions","toolbox","Professions"],["community","bulletin","Community"],["bank","coin","Bank"],["sanctuary","heart","Sanctuary"],
          ].map(([destination,icon,label])=><button key={destination} className={view===destination?"active":""} onClick={()=>mobileNavigate(destination as MainView,destination==="stable"?{stableTab:"horses"}:destination==="store"?{storeDepartment:"horses"}:undefined)}><NavIcon name={icon as Parameters<typeof NavIcon>[0]["name"]}/>{label}</button>)}</nav>
          <p>ACCOUNT</p>
          <nav><button className={view==="profile"?"active":""} onClick={()=>mobileNavigate("profile",{profileTab:"profile"})}>My Profile</button><button onClick={()=>mobileNavigate("profile",{profileTab:"settings"})}>Settings</button></nav>
          {stable.is_admin&&<><p>OWNER</p><nav><button className={view==="admin"?"active":""} onClick={()=>mobileNavigate("admin")}>Admin Control Center</button></nav></>}
          <button className="mobile-signout" onClick={async()=>{await supabase.auth.signOut();window.location.assign("/")}}>Sign Out</button>
        </aside>
      </div>}
      <aside className="game-sidebar">
        <button className="brand" onClick={() => navigate("home")}>
          <span className="mark">LE</span>
          <span>
            Legacy Equine™<small>Breed Your Legacy.</small>
          </span>
        </button>
        <nav className="game-nav" aria-label="Game areas">
          <button className={view === "home" ? "active" : ""} onClick={() => navigate("home")}><NavIcon name="bulletin"/>Home{newsNew>0?` · ${newsNew} New`:""}</button>
          <button
            className={view === "stable" ? "active" : ""}
            onClick={() => navigate("stable",{stableTab:"horses"})}
          >
            <NavIcon name="barn"/>My Stable
          </button>
          <button
            className={
              view === "store" || view === "storehorse" ? "active" : ""
            }
            onClick={openStore}
          >
            <NavIcon name="store"/>LE Store
          </button>
          <button
            className={view === "training" ? "active" : ""}
            onClick={() => navigate("training")}
          >
            <NavIcon name="round-pen"/>Training
          </button>
          <button
            className={view === "shows" ? "active" : ""}
            onClick={() => navigate("shows")}
          >
            <NavIcon name="trophy"/>Shows
          </button>
          <button
            className={view === "market" ? "active" : ""}
            onClick={() => navigate("market")}
          >
            <NavIcon name="sale-tag"/>Marketplace
          </button>
          <button
            className={view === "professions" ? "active" : ""}
            onClick={() => navigate("professions")}
          >
            <NavIcon name="toolbox"/>Professions
          </button>
          <button
            className={view === "community" ? "active" : ""}
            onClick={() => navigate("community")}
          >
            <NavIcon name="bulletin"/>Community
          </button>
          <button
            className={view === "bank" ? "active" : ""}
            onClick={() => navigate("bank")}
          >
            <NavIcon name="coin"/>Bank
          </button>
          <button className={view === "sanctuary" ? "active" : ""} onClick={() => navigate("sanctuary")}>
            <NavIcon name="heart"/>Sanctuary
          </button>
        </nav>
        <div className="sidebar-note">ALPHA 0.1</div>
      </aside>
      <div className="game-column">
        <header className="topbar">
          <button className="account-home" onClick={() => navigate("profile",{profileTab:"profile"})} aria-label="Open My Profile">
            {stable.avatar_url?<img src={stable.avatar_url} alt=""/>:<span>LE</span>}<i><small>LE ACCOUNT #{stable.account_number}</small><b>{stable.username?`@${stable.username}`:stable.name}</b></i>
          </button>
          <nav className="account-nav" aria-label="Account links">
            <button
              className={view === "profile" ? "active" : ""}
              onClick={() => navigate("profile",{profileTab:"profile"})}
            >
              My Profile
            </button>
            <button
              className={view === "stable" ? "active" : ""}
              onClick={() => navigate("stable",{stableTab:"horses"})}
            >
              My Stable
            </button>
            {stable.is_admin && (
              <button
                className={view === "admin" ? "active" : ""}
                onClick={() => navigate("admin")}
              >
                Admin
              </button>
            )}
          </nav>
          <div className="balance">
            <span className="coin">LE</span>
            <b>{money(stable.balance)}</b>
            <span>LE Dollars</span>
          </div>
          <button
            className="signout"
            onClick={async () => {
              await supabase.auth.signOut();
              window.location.assign("/");
            }}
          >
            Sign out
          </button>
        </header>
        <main>
          <GlobalToast message={notice} dismiss={dismissNotice}/>
          {purchaseDestination&&<div className="purchasearrival"><span>Purchase complete — find it in your {purchaseDestination.label}.</span><button onClick={()=>{navigate("stable",{stableTab:purchaseDestination.tab});setPurchaseDestination(null)}}>Go to {purchaseDestination.label} →</button></div>}
          {view === "publicstable" && publicStableId && <PublicStableProfile stableId={publicStableId} notify={setNotice}/>}
          {view === "publicplayer" && publicPlayerId && <PublicPlayerProfile stableId={publicPlayerId} notify={setNotice}/>}
          {view === "profile" && <>
            <nav className="sectiontabs profile-tabs" aria-label="My Profile sections"><button className={profileTab==="profile"?"active":""} onClick={()=>navigate("profile",{profileTab:"profile"})}>Profile</button><button className={profileTab==="artwork"?"active":""} onClick={()=>navigate("profile",{profileTab:"artwork"})}>Artwork Album</button><button className={profileTab==="settings"?"active":""} onClick={()=>navigate("profile",{profileTab:"settings"})}>Settings</button></nav>
            {profileTab==="profile"&&<><section className="hero playerprofilehero"><div><p className="eyebrow">LE ACCOUNT #{stable.account_number} · ESTABLISHED {new Date(stable.created_at).getFullYear()}</p><h1>{stable.username?`@${stable.username}`:stable.name}</h1>{progression&&<p className="herolevel">Level {progression.level}{progression.legacy_stable?" — Legacy Stable":""} · {progression.account_xp.toLocaleString()} XP</p>}<p>{stable.bio||"Tell the Legacy Equine community about yourself."}</p></div><div className="crest">{stable.avatar_url?<img src={stable.avatar_url} alt={`${stable.username??stable.name} avatar`}/>:<span>LE</span>}<small>{stable.username?`@${stable.username}`:`ACCOUNT #${stable.account_number}`}</small></div></section><button className="primary profilepubliclink" onClick={()=>navigate("publicstable",{publicStableId:stable.id})}>View Public Stable Profile</button><section className="stats"><div><small>PLAYER LEVEL</small><b>{progression?.level??1}</b></div><div><small>ACCOUNT XP</small><b>{(progression?.account_xp??0).toLocaleString()}</b></div><div><small>HORSES OWNED</small><b>{horses.length}</b></div></section></>}
            {profileTab==="artwork"&&<ArtworkAlbum upload={async file=>uploadMedia(file,"horses")} notify={setNotice}/>} 
            {profileTab==="settings"&&<SettingsView stable={stable} save={(name,username,bio)=>action(async()=>{const{error}=await supabase.rpc("update_stable_profile",{new_name:name,new_username:username,new_bio:bio});return{error}},"Account profile updated.")} uploadRanch={file=>uploadStableMedia("ranch",file)} uploadAvatar={file=>uploadStableMedia("avatar",file)}/>} 
          </>}
          {view === "stable" && (
            <>
              <section className="stablemanagementhead"><div><p className="eyebrow">MY STABLE</p><h1>{stable.name}</h1><p>{horses.length} horse{horses.length===1?"":"s"} · {capacity?.unlimited?"Unlimited stalls":`${capacity?.available??0} stalls available`}</p></div><div className="stableprofileactions"><button onClick={()=>navigate("publicstable",{publicStableId:stable.id})}>View Stable Profile</button>{(stable.account_number===1||progression?.custom_stable_layout)&&<button onClick={()=>window.location.assign(`/stables/${stable.id}/customize`)}>Customize Stable</button>}<button className="primary" onClick={()=>navigate("store",{storeDepartment:"horses"})}>Visit LE Store</button></div></section>
              <nav className="sectiontabs stable-desktop-tabs" aria-label="My Stable sections"><button className={stableTab==="horses"?"active":""} onClick={()=>navigate("stable",{stableTab:"horses"})}>My Horses</button><button className={stableTab==="tack"?"active":""} onClick={()=>navigate("stable",{stableTab:"tack"})}>Tack Room</button><button className={stableTab==="feed"?"active":""} onClick={()=>navigate("stable",{stableTab:"feed"})}>Feed Room</button><button className={stableTab==="supplies"?"active":""} onClick={()=>navigate("stable",{stableTab:"supplies"})}>Supply Room</button></nav>
              <label className="stable-mobile-select">Stable Area:<select value={stableTab} onChange={event=>navigate("stable",{stableTab:event.target.value as StableTab})}><option value="horses">My Horses</option><option value="tack">Tack Room</option><option value="feed">Feed Room</option><option value="supplies">Supply Room</option></select></label>
              {stableTab==="horses"&&<>
              <section className="stats stable-overview desktop-stable-overview">
                <div>
                  <small>STABLE CAPACITY</small>
                  <b>{capacity?.unlimited ? "Unlimited" : `${capacity?.occupied ?? horses.length} / ${capacity?.total_capacity ?? GAME.baseStableCapacity}`}</b>
                  <button className="textbutton" onClick={()=>navigate("stalls")}>+ Add Stalls</button>
                </div>
                <div>
                  <small>AVERAGE POINTS</small>
                  <b>
                    {horses.length
                      ? Math.round(
                          horses.reduce((n, h) => n + overall(h), 0) /
                            horses.length,
                        )
                      : 0}
                  </b>
                </div>
                <div>
                  <small>GENERATIONS BRED</small>
                  <b>{Math.max(0, ...horses.map((h) => h.generation))}</b>
                </div>
              </section>
              <Title
                title="Your Horses"
                sub="Your persistent Legacy Equine bloodline"
              />
              {horses.length ? (
                <>
                  <HorseListTools horses={horses} tiers={competitionTiers} query={horseQuery} setQuery={setHorseQuery} breed={horseBreed} setBreed={setHorseBreed} sex={horseSex} setSex={setHorseSex} origin={horseOrigin} setOrigin={setHorseOrigin} ageFilter={horseAge} setAge={setHorseAge} tier={horseTier} setTier={setHorseTier} breeding={horseBreeding} setBreeding={setHorseBreeding} sort={horseSort} setSort={setHorseSort} viewMode={horseView} setViewMode={setHorseView}/>
                  <p className="horsecount">Showing {visibleHorses.length} of {horses.length} horses</p>
                  <div className={`horsegrid ${horseView}`}>
                  {visibleHorses.map((h) => (
                    <Card key={h.id} h={h} tiers={competitionTiers} open={open} compact={horseView === "compact"} />
                  ))}
                  </div>
                  {!visibleHorses.length&&<p className="panel featurehint">No horses match these filters.</p>}
                </>
              ) : (
                <Empty go={() => navigate("store",{storeDepartment:"horses"})} />
              )}
              <section className="stats stable-overview mobile-stable-overview">
                <div><small>STABLE CAPACITY</small><b>{capacity?.unlimited ? "Unlimited" : `${capacity?.occupied ?? horses.length} / ${capacity?.total_capacity ?? GAME.baseStableCapacity}`}</b><button className="textbutton" onClick={()=>navigate("stalls")}>+ Add Stalls</button></div>
                <div><small>AVERAGE POINTS</small><b>{horses.length?Math.round(horses.reduce((n,h)=>n+overall(h),0)/horses.length):0}</b></div>
                <div><small>GENERATIONS BRED</small><b>{Math.max(0,...horses.map(h=>h.generation))}</b></div>
              </section>
              </>}
              {stableTab!=="horses"&&<StableInventory room={stableTab} horses={horses} notify={setNotice} refresh={()=>void load(user)}/>} 
            </>
          )}
          {view === "store" && (
            <>
              <Title
                title="The LE Store"
                sub="Browse the shared Foundation herd and find the horse that speaks to you"
              />
              <nav className="storedepartments" aria-label="LE Store departments"><button className={storeDepartment==="horses"?"active":""} onClick={()=>openStoreDepartment("horses")}>Foundation Horses</button><button className={storeDepartment==="feed"?"active":""} onClick={()=>openStoreDepartment("feed")}>Feed &amp; Hay</button><button className={storeDepartment==="tack"?"active":""} onClick={()=>openStoreDepartment("tack")}>Tack</button></nav>
              {storeDepartment==="horses"&&<><div className="productfilters horse-store-filters"><label className="productsearch">Search Horses<input type="search" aria-label="Search Horses" placeholder="Search Horses" value={storeHorseQuery} onChange={e=>setStoreHorseQuery(e.target.value)}/></label><label>Breed<select aria-label="Foundation horse breed" value={storeBreed} onChange={e=>navigate("store",{storeDepartment:"horses",storeBreed:e.target.value})}><option value="">All Breeds</option>{[...new Set(inventory.map(h=>h.breed))].sort().map(b=><option value={b} key={b}>{b} · {inventory.filter(h=>h.breed===b).length} available</option>)}</select></label></div><div className="storebar">
                <span>✦ {inventory.length} Foundation horses available</span>
                <span>
                  {inventory[0]
                    ? `Current herd arrived ${new Date(inventory[0].rotation_key).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })}`
                    : "Preparing the herd…"}
                </span>
                <button onClick={loadStore}>Refresh store</button>
              </div>
              <div className="inventorygrid storegrid">
                {visibleStoreHorses.map((h) => (
                  <StoreCard
                    key={h.inventory_id}
                    h={h}
                    view={() => {
                      navigate("storehorse",{storeSelected:h.inventory_id});
                    }}
                    purchase={() => purchase(h.inventory_id)}
                    disabled={
                      loading ||
                      (!capacity?.unlimited && (capacity?.available ?? 0) < 1) ||
                      stable.balance < h.price
                    }
                  />
                ))}{!visibleStoreHorses.length&&<p className="featurehint">No Foundation horses match these filters.</p>}
              </div>
              <p className="storelimit">Stable Capacity: {capacity?.unlimited ? "Unlimited" : `${capacity?.occupied ?? horses.length} / ${capacity?.total_capacity ?? GAME.baseStableCapacity}`}. Store purchases have no lifetime cap. {!capacity?.unlimited && (capacity?.available ?? 0)<1 && <><b> Your Stable Is Full.</b> <button onClick={()=>navigate("stalls")}>Add Stalls</button> or <button onClick={()=>navigate("sanctuary")}>Visit Sanctuary</button>.</>}</p></>}
              {storeDepartment!=="horses"&&<><div className="productfilters">
                <label>{storeDepartment==="tack"?"Category":"Type"}<select aria-label={storeDepartment==="tack"?"Tack category":"Feed and hay type"} value={productType} onChange={e=>setProductType(e.target.value)}><option value="all">{storeDepartment==="tack"?"All Tack":"All Feed & Hay"}</option>{storeDepartment==="tack"?<><option value="bridle">Bridles</option><option value="saddle">Saddles</option><option value="saddle_pad">Saddle Pads</option><option value="leg_protection">Leg Protection</option></>:<><option value="hay">Hay</option><option value="grain">Grain</option></>}</select></label>
                <label>{storeDepartment==="tack"?"Tier":"Tier / Quality"}<select aria-label={storeDepartment==="tack"?"Tack tier":"Feed tier or quality"} value={productTier} onChange={e=>setProductTier(e.target.value)}><option value="all">{storeDepartment==="tack"?"All Tiers":"All"}</option>{(storeDepartment==="tack"?STORE_TIERS:feedQualityOrder).map(tier=><option value={tier} key={tier}>{tier}</option>)}</select></label>
                <label>Sort<select aria-label={storeDepartment==="tack"?"Sort Tack":"Sort Feed and Hay"} value={productSort} onChange={e=>setProductSort(e.target.value)}><option value="tier-asc">{storeDepartment==="tack"?"Tier: Low → High":"Tier/Quality: Low → High"}</option><option value="tier-desc">{storeDepartment==="tack"?"Tier: High → Low":"Tier/Quality: High → Low"}</option><option value="price-asc">Price: Low → High</option><option value="price-desc">Price: High → Low</option></select></label>
                <label className="productsearch">Search<input type="search" aria-label={`Search ${storeDepartment==="tack"?"Tack":"Feed & Hay"}`} placeholder={`Search ${storeDepartment==="tack"?"Tack":"Feed & Hay"}`} value={productQuery} onChange={e=>setProductQuery(e.target.value)}/></label>
              </div><p className="productcount">{visibleStoreProducts.length} product{visibleStoreProducts.length===1?"":"s"}</p><div className="productresults"><div className="productgrid">{visibleStoreProducts.map(p=>{const destination=p.department==="feed"?{label:"Feed Room",tab:"feed" as const}:{label:"Tack Room",tab:"tack" as const},affordable=Math.floor(stable.balance/Math.max(1,p.price)),stock=p.remaining_stock??0,storage=p.storage_unlimited?stock:(p.storage_available??0),maxPurchase=p.department==="feed"?Math.max(0,Math.min(stock,storage,affordable)):null,limitReason=p.department!=="feed"?undefined:stock<=0?"Sold out until the next LE day.":storage<=0?"Feed storage is full. Use existing feed before purchasing more.":affordable<=0?"Insufficient LED for this product.":`Up to ${maxPurchase} available now based on stock, storage, and balance.`;return <article className="productcard" key={p.id}><div className="producticon" aria-hidden="true">{p.icon_url?<img src={p.icon_url} alt=""/>:<span>{productPlaceholder(p)}</span>}</div><div className="productdetails"><p className="eyebrow">{p.department==="feed"?`${p.feed_type?.toUpperCase()??"FEED"} · ${p.quality??"STANDARD"}`:`${p.quality} · ${tackCategoryLabel(p.tack_slot)}`}</p><h3>{p.name}</h3>{p.department==="feed"&&<><small>{Math.round((p.feed_success_probability??0)*100)}% development chance · +{p.development_min}–{p.development_max} potential · one {p.feed_type} per horse per LE day</small><small><b>{stock.toLocaleString()} / {(p.daily_starting_stock??500).toLocaleString()}</b> remaining today</small></>}{p.department==="tack"&&<div className="productbonus">{Object.entries(p.tack_bonuses).filter(([,n])=>n!==0).map(([stat,n])=><span key={stat}>+{n} {stat.slice(0,3).toUpperCase()}</span>)}</div>}</div><StoreBulkPurchase department={p.department==="feed"?"feed":"tack"} price={p.price} balance={stable.balance} maxPurchase={maxPurchase} limitReason={limitReason} disabled={loading||p.department==="feed"&&maxPurchase===0} onBuy={async(quantity,requestKey)=>{let succeeded=false;await action(async()=>{const{error}=await supabase.rpc("purchase_store_product_bulk",{p_product:p.id,p_quantity:quantity,p_request:requestKey});if(!error){succeeded=true;setPurchaseDestination(destination)}return{error}},`${p.name} × ${quantity} added to your ${destination.label}.`);if(succeeded)await loadStore();return succeeded}}/></article>})}</div>{!visibleStoreProducts.length&&<p className="featurehint">No products match these filters.</p>}</div></>}
            </>
          )}
          {storeHorse && view === "storehorse" && (
            <StorePreview
              h={storeHorse}
              back={() => history.back()}
              purchase={() => purchase(storeHorse.inventory_id)}
              disabled={
                loading ||
                (!capacity?.unlimited && (capacity?.available ?? 0) < 1) ||
                stable.balance < storeHorse.price
              }
            />
          )}
          {view === "home" && <HomeNews notify={setNotice} onNewCount={setNewsNew}/>}
          {view === "bank" && (
            <Bank balance={stable.balance} notify={setNotice} refreshAccount={()=>void load(user)} />
          )}
          {view === "stalls" && <StallExpansion capacity={capacity} notify={setNotice}/>} 
          {view === "sanctuary" && <SanctuaryView horses={sanctuary} owned={horses} retire={async(h,name)=>{await action(async()=>{const{error}=await supabase.rpc("send_horse_to_sanctuary",{target_horse:h.id,confirmation_name:name});return{error}},`${h.name} is now permanently retired at the LE Equine Sanctuary.`);await loadSanctuary()}}/>}
          {view === "professions" && (
            <ProfessionalCenter
              horses={horses}
              balance={stable.balance}
              notify={setNotice}
              refresh={() => void load(user)}
              onTackDelivered={() => navigate("stable",{stableTab:"tack"})}
            />
          )}
          {view === "training" && (
            <TrainingCenter
              horses={horses}
              open={open}
              train={async (h, s) =>
                action(async () => {
                  const { error } = await supabase.rpc("train_horse", {
                    target_horse: h.id,
                    stat_name: s,
                  });
                  return { error };
                }, `${h.name} gained +1 ${s}.`)
              }
            />
          )}
          {view === "shows" && (
            <PlayerShows
              horses={horses}
              balance={stable.balance}
              notify={setNotice}
              refreshAccount={() => void load(user)}
            />
          )}
          {view === "market" && (
            <MarketplaceView
              listings={market}
              horses={horses}
              balance={stable.balance}
              list={async (h, p) => {
                await action(async () => {
                  const { error } = await supabase.rpc("list_horse_for_sale", {
                    target_horse: h,
                    asking_price: p,
                  });
                  return { error };
                }, "Horse listed in the marketplace.");
                await loadMarket();
              }}
              buy={async (id) => {
                await action(async () => {
                  const { error } = await supabase.rpc(
                    "buy_marketplace_horse",
                    { target_listing: id },
                  );
                  return { error };
                }, "Marketplace purchase complete.");
                await loadMarket();
              }}
            />
          )}
          {view === "community" && (
            <CommunityHub
              username={stable.username}
              isAdmin={stable.is_admin}
              notify={setNotice}
            />
          )}{" "}
          {/* Community */}
          {view === "settings" && null}{" "}
          {/* Settings */}
          {view === "admin" && stable.is_admin && (
              <AdminConsole
                ownerAccount={stable.account_number === 1}
                currentUserId={user.id}
                changed={() => load(user)}
              />
          )}{" "}
          {/* Admin */}
          {horse && view === "horse" && (
            <>
              <HorsePage
                key={`${horse.id}:${horse.image_url}`}
                h={horse}
                horses={horses}
                tiers={competitionTiers}
                stableName={`${stable.name} · #${stable.account_number}`}
                canEdit={horse.owner_id === user.id}
                isOwned={horse.owner_id === user.id}
                isAdmin={stable.is_admin}
                canHorseEdit={canHorseEdit}
                onHorseEdited={()=>void load(user)}
                openHorse={(relative) => {
                  const profileHorse = relative as Horse;
                  setHorses((current) =>
                    current.some((candidate) => candidate.id === profileHorse.id)
                      ? current
                      : [...current, profileHorse],
                  );
                  open(profileHorse);
                }}
                openProfessions={() => navigate("professions")}
                openTackRoom={() => navigate("stable",{stableTab:"tack"})}
                backToMyStable={() => navigate("stable",{stableTab:"horses"})}
                visitOwnerStable={(ownerId) => navigate("publicstable",{publicStableId:ownerId})}
                reportImageFailure={(failedUrl) => {
                  void supabase.rpc("report_missing_horse_image", {
                    target_horse: horse.id,
                    failed_url: failedUrl,
                  });
                }}
                regenerateImage={() => {
                  void action(async () => {
                    const { error } = await supabase.rpc("admin_regenerate_horse_image", {
                      target_horse: horse.id,
                    });
                    if (!error) void generateStoreArtwork();
                    return { error };
                  }, "Fresh artwork has been queued for this horse.");
                }}
                save={(name, bio, img) =>
                  action(async () => {
                    const { error } = await supabase.rpc(
                      "update_horse_profile",
                      {
                        target_horse: horse.id,
                        new_name: name,
                        new_biography: bio,
                        new_image_url: img,
                      },
                    );
                    return { error };
                  }, "Horse profile saved.")
                }
                train={(stat) =>
                  action(async () => {
                    const { error } = await supabase.rpc("train_horse", {
                      target_horse: horse.id,
                      stat_name: stat,
                    });
                    return { error };
                  }, `${horse.name} gained +1 ${stat}.`)
                }
                breed={(mare) => breedWithWarning(horse.id, mare)}
              />
            </>
          )}{" "}
          {horse && view === "pedigree" && (
            <Pedigree h={horse} horses={horses} open={open} />
          )}{" "}
          {horse && view === "progeny" && (
            <>
              <Title
                title={`${horse.name} · Progeny`}
                sub="Permanent offspring record"
              />
              <div className="horsegrid">
                {horses
                  .filter(
                    (x) => x.sire_id === horse.id || x.dam_id === horse.id,
                  )
                  .map((x) => (
                    <Card key={x.id} h={x} tiers={competitionTiers} open={open} />
                  ))}
              </div>
            </>
          )}
        </main>
        <footer>
          LEGACY EQUINE · ALPHA 0.1{" "}
          <span>Original browser horse simulation</span>
        </footer>
      </div>
    </div>
  );
}

function Auth() {
  const [email, setEmail] = useState(""),
    [password, setPassword] = useState(""),
    [mode, setMode] = useState<"login" | "signup">("signup"),
    [message, setMessage] = useState("");
  const submit = async () => {
    const { error } =
      mode === "signup"
        ? await supabase.auth.signUp({ email, password })
        : await supabase.auth.signInWithPassword({ email, password });
    setMessage(
      error?.message ??
        (mode === "signup"
          ? "Account created. Check your email if confirmation is required."
          : "Signed in."),
    );
  };
  return (
    <div className="auth">
      <div className="authbrand">
        <img className="officiallogo" src="/legacy-equine-logo.png" alt="Legacy Equine™" />
        <h1>Legacy Equine™</h1>
        <p>Breed Your Legacy.</p>
      </div>
      <div className="authcard">
        <p className="eyebrow">
          {mode === "signup" ? "BEGIN YOUR LEGACY" : "WELCOME BACK"}
        </p>
        <h2>{mode === "signup" ? "Create your account" : "Sign in"}</h2>
        <label>
          Email
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </label>
        <label>
          Password
          <input
            type="password"
            minLength={8}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        </label>
        <button className="primary" onClick={submit}>
          {mode === "signup" ? "Create Account" : "Sign In"}
        </button>
        <p>{message}</p>
        <button
          className="textbtn"
          onClick={() => setMode(mode === "signup" ? "login" : "signup")}
        >
          {mode === "signup"
            ? "Already have an account? Sign in"
            : "New here? Create an account"}
        </button>
      </div>
    </div>
  );
}
function CreateStable({
  onCreate,
  loading,
  message,
}: {
  onCreate: (n: string) => Promise<void>;
  loading: boolean;
  message: string;
}) {
  const [n, setN] = useState("");
  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (n.trim().length >= 2 && !loading) await onCreate(n);
  };
  return (
    <div className="auth">
      <div className="authbrand">
        <span className="mark">LE</span>
        <h1>Name Your Stable</h1>
        <p>Choose the name players will know you by.</p>
      </div>
      <form className="authcard" onSubmit={submit}>
        <p className="eyebrow">ESTABLISH YOUR LEGACY</p>
        <h2>Create a stable</h2>
        <label>
          Stable name
          <input
            value={n}
            maxLength={60}
            autoFocus
            disabled={loading}
            onChange={(e) => setN(e.target.value)}
          />
        </label>
        <button
          type="submit"
          className="primary"
          disabled={loading || n.trim().length < 2}
        >
          {loading ? "Opening your stable…" : "Create Stable"}
        </button>
        {message !== "Welcome to Legacy Equine." && (
          <p className="formmessage" role="alert">
            {message}
          </p>
        )}
      </form>
    </div>
  );
}
function Title({ title, sub }: { title: string; sub: string }) {
  return (
    <div className="title">
      <p className="eyebrow">LEGACY EQUINE</p>
      <h2>{title}</h2>
      <p>{sub}</p>
    </div>
  );
}
function Empty({ go }: { go: () => void }) {
  return (
    <div className="empty">
      <div>♞</div>
      <h3>Your stalls are waiting</h3>
      <p>Visit the LE Store to choose your first foundation horse.</p>
      <button className="primary" onClick={go}>
        Find a Foundation Horse
      </button>
    </div>
  );
}
function HorseArtworkImage({url,alt}:{url:string;alt:string}) {
  return <ContainedHorseArtwork url={url} alt={alt}/>;
}
function HorseListTools({horses,tiers,query,setQuery,breed,setBreed,sex,setSex,origin,setOrigin,ageFilter,setAge,tier,setTier,breeding,setBreeding,sort,setSort,viewMode,setViewMode}:{horses:Horse[];tiers:CompetitionTier[];query:string;setQuery:(v:string)=>void;breed:string;setBreed:(v:string)=>void;sex:string;setSex:(v:string)=>void;origin:string;setOrigin:(v:string)=>void;ageFilter:string;setAge:(v:string)=>void;tier:string;setTier:(v:string)=>void;breeding:string;setBreeding:(v:string)=>void;sort:string;setSort:(v:string)=>void;viewMode:"cards"|"compact";setViewMode:(v:"cards"|"compact")=>void}){
 const breeds=[...new Set(horses.map(h=>h.breed))].sort(),origins=[...new Set(horses.map(h=>h.origin))].sort();
 return <section className="horsetools" aria-label="Search, filter, and sort horses"><div className="horseviewtoggle"><button className={viewMode==="cards"?"active":""} onClick={()=>setViewMode("cards")}>Cards</button><button className={viewMode==="compact"?"active":""} onClick={()=>setViewMode("compact")}>Compact</button></div><input aria-label="Search horses by name" placeholder="Search horse names…" value={query} onChange={e=>setQuery(e.target.value)}/><select aria-label="Filter by breed" value={breed} onChange={e=>setBreed(e.target.value)}><option value="all">All breeds</option>{breeds.map(x=><option key={x}>{x}</option>)}</select><select aria-label="Filter by sex" value={sex} onChange={e=>setSex(e.target.value)}><option value="all">All sexes</option><option>Mare</option><option>Stallion</option></select><select aria-label="Filter by age" value={ageFilter} onChange={e=>setAge(e.target.value)}><option value="all">All ages</option><option value="young">Under 3</option><option value="breeding">Age 3–25</option><option value="senior">Age 26+</option></select><select aria-label="Filter by origin" value={origin} onChange={e=>setOrigin(e.target.value)}><option value="all">All origins</option>{origins.map(x=><option key={x}>{x}</option>)}</select><select aria-label="Filter by show tier" value={tier} onChange={e=>setTier(e.target.value)}><option value="all">All show tiers</option>{tiers.map(x=><option key={x.id}>{x.name}</option>)}</select><select aria-label="Filter by breeding eligibility" value={breeding} onChange={e=>setBreeding(e.target.value)}><option value="all">Any breeding status</option><option value="eligible">Breeding eligible</option><option value="ineligible">Not eligible</option></select><select aria-label="Sort horses" value={sort} onChange={e=>setSort(e.target.value)}><option value="name">Sort: Name</option><option value="age">Sort: Age</option><option value="newest">Sort: Newest</option><option value="career">Sort: Career Points</option>{GAME.stats.map(x=><option value={x} key={x}>Sort: {x}</option>)}</select></section>
}
function Card({ h,tiers, open, compact=false }: { h: Horse;tiers:CompetitionTier[]; open: (h: Horse) => void;compact?:boolean }) {
  return (
    <article className={`horsecard ${compact?"compact":""}`} onClick={() => open(h)} onKeyDown={e=>{if(e.key==="Enter"||e.key===" ")open(h)}} role="button" tabIndex={0} aria-label={`View ${h.name}`}>
      <div className="horsepic">
        <HorseArtworkImage url={h.image_url} alt={h.name}/>
        <span>{h.origin}</span>
      </div>
      <div className="horsecardbody">
        <h3>{h.brand_code_at_assignment&&<span className="horsebrand">{h.brand_mark_at_assignment&&<img src={h.brand_mark_at_assignment} alt=""/>}{h.brand_code_at_assignment}</span>}{h.name}</h3>
        <p className="horseidentity">{h.breed} · {h.sex} · {ageLabel(h)} · {h.color} · {handHeight(h.mature_height_hands)}</p>
        <div className="cardfoot">
          <span><b>{h.career_points??0}</b> Career Points · {competitionTier(h.career_points??0,tiers)?.name??"Unassigned"}</span>
          <em>View horse →</em>
        </div>
      </div>
    </article>
  );
}
function storeAge(h: StoreHorse) {
  return Math.max(
    0,
    (((Date.now() - new Date(h.birth_date).getTime()) / 86400000) *
      GAME.age.gameDaysPerRealDay) /
      365.25,
  );
}
function storeAgeLabel(h: StoreHorse) {
  const months = Math.floor(storeAge(h) * 12), years = Math.floor(months / 12), remainder = months % 12;
  return `${years} ${years === 1 ? "year" : "years"}${remainder ? `, ${remainder} ${remainder === 1 ? "month" : "months"}` : ""}`;
}
function storeOverall(h: StoreHorse) {
  return GAME.stats.reduce((sum, key) => sum + (h.stats[key] ?? 0), 0);
}
function StoreCard({
  h,
  view,
  purchase,
  disabled,
}: {
  h: StoreHorse;
  view: () => void;
  purchase: () => void;
  disabled: boolean;
}) {
  return (
    <article className="storecard">
      <button className="storeimage" onClick={view}>
        <HorseArtworkImage url="" alt={h.name}/>
      </button>
      <div className="storecardbody">
        <h3>{h.name}</h3>
        <p className="storeidentity">
          {h.breed} · {h.sex} · {storeAgeLabel(h)} · {h.color} ·{" "}
          {handHeight(h.mature_height_hands)}
        </p>
        <div className="storeactions">
          <strong>
            {money(h.price)} <small>LE Dollars</small>
          </strong>
          <button onClick={view}>View Horse</button>
          <button className="primary" disabled={disabled} onClick={purchase}>
            Purchase
          </button>
        </div>
      </div>
    </article>
  );
}
function StorePreview({
  h,
  back,
  purchase,
  disabled,
}: {
  h: StoreHorse;
  back: () => void;
  purchase: () => void;
  disabled: boolean;
}) {
  return (
    <>
      <button className="back" onClick={back}>
        ← Back to all store horses
      </button>
      <section className="storepreview">
        <div className="previewart">
          <HorseArtworkImage url={h.image_url} alt={h.name}/>
          <span>FOUNDATION HORSE</span>
        </div>
        <div className="previewinfo">
          <p className="eyebrow">MEET YOUR NEXT LEGACY</p>
          <h1>{h.name}</h1>
          <p className="meta">
            {h.breed} <b>•</b> {h.sex} <b>•</b> {storeAgeLabel(h)}{" "}
            <b>•</b> {handHeight(h.mature_height_hands)} <b>•</b> {h.color}
          </p>
          <div className="previewtotal">
            <span>Overall foundation points</span>
            <b>{storeOverall(h)}</b>
          </div>
          <div className="previewstats">
            {GAME.stats.map((s) => (
              <div key={s}>
                <span>{s}</span>
                <b>{h.stats[s]}</b>
              </div>
            ))}
          </div>
          <div className="previewbuy">
            <strong>
              {money(h.price)} <small>LE Dollars</small>
            </strong>
            <button className="primary" disabled={disabled} onClick={purchase}>
              Bring {h.name} Home
            </button>
          </div>
        </div>
      </section>
    </>
  );
}
function TrainingCenter({
  horses,
  open,
  train,
}: {
  horses: Horse[];
  open: (h: Horse) => void;
  train: (h: Horse, s: string) => void;
}) {
  const [choices, setChoices] = useState<Record<string, string>>({});
  return (
    <>
      <Title
        title="Training Center"
        sub="Choose a horse and develop one stat per training session"
      />
      {horses.length ? (
        <div className="featuregrid">
          {horses.map((h) => (
            <article className="featurecard" key={h.id}>
              <HorseArtworkImage url={h.image_url} alt={h.name}/>
              <div>
                <p className="eyebrow">
                  {h.breed} · {h.sex}
                </p>
                <h3>{h.name}</h3>
                <p>
                  {canTrain(h) ? "Ready to train" : "Resting after training"}
                </p>
                <select
                  value={choices[h.id] ?? GAME.stats[0]}
                  onChange={(e) =>
                    setChoices({ ...choices, [h.id]: e.target.value })
                  }
                >
                  {GAME.stats.map((s) => (
                    <option key={s}>
                      {s} · {h.stats[s]}
                    </option>
                  ))}
                </select>
                <button
                  className="primary"
                  disabled={!canTrain(h)}
                  onClick={() =>
                    train(h, (choices[h.id] ?? GAME.stats[0]).split(" · ")[0])
                  }
                >
                  Train +1
                </button>
                <button className="textbtn" onClick={() => open(h)}>
                  View horse
                </button>
              </div>
            </article>
          ))}
        </div>
      ) : (
        <Empty go={() => {}} />
      )}
    </>
  );
}
function ShowsView({
  shows,
  horses,
  enter,
}: {
  shows: Show[];
  horses: Horse[];
  enter: (show: string, horse: string) => void;
}) {
  const [choice, setChoice] = useState<Record<string, string>>({});
  return (
    <>
      <Title
        title="Shows"
        sub="Enter your horses in automated Legacy Equine competitions"
      />
      <div className="featuregrid">
        {shows.map((s) => (
          <article className="featurecard showcard" key={s.id}>
            <div className="showmark">◇</div>
            <div>
              <p className="eyebrow">{s.discipline}</p>
              <h3>{s.class_name}</h3>
              <p>
                Runs {new Date(s.starts_at).toLocaleDateString()} ·{" "}
                {s.entry_count} entries
              </p>
              <select
                value={choice[s.id] ?? ""}
                onChange={(e) =>
                  setChoice({ ...choice, [s.id]: e.target.value })
                }
              >
                <option value="">Choose your horse…</option>
                {horses.map((h) => (
                  <option key={h.id} value={h.id}>
                    {h.name} · {overall(h)} pts
                  </option>
                ))}
              </select>
              <button
                className="primary"
                disabled={!choice[s.id]}
                onClick={() => enter(s.id, choice[s.id])}
              >
                Enter Show
              </button>
            </div>
          </article>
        ))}
      </div>
      {!horses.length && (
        <p className="featurehint">Purchase a horse before entering shows.</p>
      )}
    </>
  );
}
function MarketplaceView({
  listings,
  horses,
  balance,
  list,
  buy,
}: {
  listings: MarketHorse[];
  horses: Horse[];
  balance: number;
  list: (h: string, p: number) => void;
  buy: (id: string) => void;
}) {
  const [horse, setHorse] = useState(""),
    [price, setPrice] = useState(1000);
  return (
    <>
      <Title
        title="Horse Marketplace"
        sub="Buy and sell real player-owned Legacy Equine horses"
      />
      <section className="panel marketlist">
        <h2>List one of your horses</h2>
        <div className="inlineform">
          <select value={horse} onChange={(e) => setHorse(e.target.value)}>
            <option value="">Choose a horse…</option>
            {horses.map((h) => (
              <option key={h.id} value={h.id}>
                {h.name} · {h.breed}
              </option>
            ))}
          </select>
          <input
            type="number"
            min={1}
            max={1000000}
            value={price}
            onChange={(e) => setPrice(Number(e.target.value))}
          />
          <button
            className="primary"
            disabled={!horse || price < 1}
            onClick={() => list(horse, price)}
          >
            List for Sale
          </button>
        </div>
      </section>
      <div className="inventorygrid marketgrid">
        {listings.map((h) => (
          <article className="storecard" key={h.listing_id}>
            <div className="storeimage">
              <HorseArtworkImage url={h.image_url} alt={h.name}/>
              <span>{h.sex}</span>
            </div>
            <div className="storecardbody">
              <p className="eyebrow">{h.breed}</p>
              <h3>{h.brand_code_at_assignment&&<span className="horsebrand">{h.brand_mark_at_assignment&&<img src={h.brand_mark_at_assignment} alt=""/>}{h.brand_code_at_assignment}</span>}{h.name}</h3>
              <p>
                {h.color} · sold by{" "}
                <a href={`/stables/${h.seller_id}`}>{h.seller_username ? `@${h.seller_username}` : h.seller_name}</a>
              </p>
              <div className="storestats">
                {GAME.stats.slice(0, 4).map((s) => (
                  <span key={s}>
                    <small>{s}</small>
                    <b>{h.stats[s]}</b>
                  </span>
                ))}
              </div>
              <div className="storeactions">
                <strong>
                  {money(h.price)} <small>LE Dollars</small>
                </strong>
                <button
                  className="primary"
                  disabled={balance < h.price}
                  onClick={() => buy(h.listing_id)}
                >
                  Purchase Horse
                </button>
              </div>
            </div>
          </article>
        ))}
      </div>
      {!listings.length && (
        <p className="featurehint">
          No horses are listed yet. The first listing could be yours.
        </p>
      )}
    </>
  );
}
function CommunityView({
  posts,
  username,
  post,
  settings,
}: {
  posts: ForumPost[];
  username: string | null;
  post: (body: string, parent: string | null) => void;
  settings: () => void;
}) {
  const [body, setBody] = useState(""),
    [reply, setReply] = useState<string | null>(null);
  const submit = () => {
    post(body, reply);
    setBody("");
    setReply(null);
  };
  return (
    <>
      <Title
        title="Community"
        sub="Stable talk, breeding discoveries, show stories, and conversations"
      />
      {username ? (
        <section className="panel composer">
          <p className="eyebrow">POSTING AS @{username}</p>
          {reply && (
            <button className="replying" onClick={() => setReply(null)}>
              Replying to a conversation · cancel
            </button>
          )}
          <textarea
            value={body}
            maxLength={1000}
            placeholder="Share something with the Legacy Equine community…"
            onChange={(e) => setBody(e.target.value)}
          />
          <button className="primary" disabled={!body.trim()} onClick={submit}>
            Post Message
          </button>
        </section>
      ) : (
        <section className="panel featurehint">
          <h2>Create your community username</h2>
          <p>You need a unique username before joining conversations.</p>
          <button className="primary" onClick={settings}>
            Open Settings
          </button>
        </section>
      )}
      <section className="forumfeed">
        {posts.map((p) => (
          <article
            className={p.parent_id ? "forumpost replypost" : "forumpost"}
            key={p.id}
          >
            {p.avatar_url ? (
              <img className="forumavatar" src={p.avatar_url} alt="" />
            ) : (
              <span className="forumavatar">LE</span>
            )}
            <div>
              <b>@{p.username}</b>
              <span>
                {p.stable_name} · LE #{p.account_number}
              </span>
            </div>
            <p>{p.body}</p>
            <footer>
              <time>{new Date(p.created_at).toLocaleString()}</time>
              {username && (
                <button onClick={() => setReply(p.id)}>Reply</button>
              )}
            </footer>
          </article>
        ))}
      </section>
    </>
  );
}
function SettingsView({
  stable,
  save,
  uploadRanch,
  uploadAvatar,
}: {
  stable: Stable;
  save: (name: string, username: string, bio: string) => void;
  uploadRanch: (f: File) => void;
  uploadAvatar: (f: File) => void;
}) {
  const [name, setName] = useState(stable.name),
    [username, setUsername] = useState(stable.username ?? ""),
    [bio, setBio] = useState(stable.bio ?? "");
  return (
    <>
      <Title
        title="Account Settings"
        sub="Manage your separate stable, player, and horse identities"
      />
      <section className="panel settingsform">
        <label>
          Stable name
          <input
            value={name}
            maxLength={60}
            onChange={(e) => setName(e.target.value)}
          />
        </label>
        <label>
          Community username{" "}
          <small>
            Optional until you post · letters, numbers, and underscores · 3–24
            characters
          </small>
          <input
            value={username}
            maxLength={24}
            placeholder="TwistedTree"
            onChange={(e) =>
              setUsername(e.target.value.replace(/[^A-Za-z0-9_]/g, ""))
            }
          />
        </label>
        <label>
          Player bio
          <textarea
            value={bio}
            maxLength={500}
            placeholder="Tell the community about yourself…"
            onChange={(e) => setBio(e.target.value)}
          />
        </label>
        <button
          className="primary"
          disabled={
            name.trim().length < 2 ||
            (username.length > 0 && username.length < 3)
          }
          onClick={() => save(name, username, bio)}
        >
          Save Account Profile
        </button>
        <p>LE Account #{stable.account_number} remains permanent.</p>
      </section>
      <section className="panel">
        <h2>Profile Images</h2>
        <p className="panelsub">
          Each image is its own item. JPG, PNG, WebP, or GIF · maximum 5 MB.
        </p>
        <div className="mediaidentitygrid">
          <MediaUpload
            title="Ranch image"
            description="The wide image displayed only on your Public Stable Profile."
            image={stable.ranch_image_url}
            shape="wide"
            upload={uploadRanch}
          />
          <MediaUpload
            title="Player avatar"
            description="Your personal image beside your username and community identity."
            image={stable.avatar_url}
            shape="avatar"
            upload={uploadAvatar}
          />
        </div>
      </section>
      <StableBrandSettings notify={(message)=>window.alert(message)}/>
    </>
  );
}
function StallExpansion({capacity,notify:_notify}:{capacity:StableCapacity|null;notify:(value:string)=>void}){
 return <><Title title="Expand Your Stable" sub="Permanent room for the horses in your Legacy Equine story"/><section className="panel settingsform"><p className="eyebrow">STABLE CAPACITY</p><h2>{capacity?.unlimited?"Unlimited":`${capacity?.occupied??0} / ${capacity?.total_capacity??GAME.baseStableCapacity} stalls occupied`}</h2>{!capacity?.unlimited&&<div className="adminformgrid"><div><small>Base Capacity</small><h3>{capacity?.base_capacity??5}</h3></div><div><small>Purchased Capacity</small><h3>+{capacity?.purchased_capacity??0}</h3></div><div><small>Admin / Promotional</small><h3>+{capacity?.complimentary_capacity??0}</h3></div></div>}</section>{!capacity?.unlimited&&<section className="panel settingsform"><p className="eyebrow">COMMERCE READINESS</p><h2>Permanent Stall Expansions</h2><p className="panelsub">Purchases are not available yet. Existing permanent stall entitlements remain active; future checkout will use the server-authoritative Commerce catalog.</p><button className="primary" disabled>COMING SOON — NO PAYMENT COLLECTION</button></section>}</>;
}
function SanctuaryView({horses,owned,retire}:{horses:SanctuaryHorse[];owned:Horse[];retire:(horse:Horse,name:string)=>Promise<void>}){
 const [query,setQuery]=useState(""),[chosen,setChosen]=useState<Horse|null>(null),[archive,setArchive]=useState<SanctuaryHorse|null>(null),[confirmation,setConfirmation]=useState("");
 const visible=horses.filter(h=>`${h.name} ${h.breed} ${h.former_owner_name}`.toLowerCase().includes(query.toLowerCase()));
 return <><Title title="LE Equine Sanctuary" sub="The permanent historical home for horses retired from active gameplay"/><section className="panel settingsform"><p className="eyebrow">PERMANENT RETIREMENT</p><h2>Retire one of your horses</h2><p className="panelsub">A Sanctuary horse keeps its profile, pedigree, progeny, artwork, genetics, stats, and show history—but can never return to ownership, breeding, showing, sale, transfer, or service activity.</p><select value={chosen?.id??""} onChange={e=>{setChosen(owned.find(h=>h.id===e.target.value)??null);setConfirmation("")}}><option value="">Choose a horse…</option>{owned.map(h=><option key={h.id} value={h.id}>{h.name} · {h.breed}</option>)}</select>{chosen&&<><label>Type <b>{chosen.name}</b> to confirm<input value={confirmation} onChange={e=>setConfirmation(e.target.value)}/></label><button className="primary" disabled={confirmation!==chosen.name} onClick={async()=>{await retire(chosen,confirmation);setChosen(null);setConfirmation("")}}>Send to Sanctuary Permanently</button></>}</section><section className="panel"><p className="eyebrow">SANCTUARY DIRECTORY</p><h2>Legacy Equine history</h2><input placeholder="Search horse, breed, or former owner…" value={query} onChange={e=>setQuery(e.target.value)}/><div className="horsegrid compact">{visible.map(h=><article className="horsecard compact" role="button" tabIndex={0} onClick={()=>setArchive(h)} key={h.id}><div className="horsepic"><HorseArtworkImage url={h.image_url} alt={h.name}/><span>Sanctuary</span></div><div className="horsecardbody"><h3>{h.name}</h3><p>{h.breed} · {h.sex} · {h.color}</p><p><b>LE Equine Sanctuary</b><br/>Retired {new Date(h.sanctuary_retired_at).toLocaleDateString()}<br/>Formerly owned by {h.former_owner_name} #{h.former_owner_account}</p><small>{h.career_points} Career Points · View historical profile</small></div></article>)}</div>{!visible.length&&<p className="featurehint">No Sanctuary horses match this search.</p>}</section>{archive&&<div className="modalback" onClick={()=>setArchive(null)}><section className="modal" onClick={e=>e.stopPropagation()}><button className="close" onClick={()=>setArchive(null)}>×</button><HorseArtworkImage url={archive.image_url} alt={archive.name}/><p className="eyebrow">PERMANENTLY RETIRED</p><h2>{archive.name}</h2><p>{archive.breed} · {archive.sex} · {archive.color}</p><h3>LE Equine Sanctuary</h3><p>Retired {new Date(archive.sanctuary_retired_at).toLocaleDateString()}<br/>Formerly owned by {archive.former_owner_name} · LE Account #{archive.former_owner_account}</p><p>{archive.career_points} Career Points. Historical pedigree, progeny, and show records remain preserved in Legacy Equine.</p></section></div>}</>;
}
function AdminConsole({
  ownerAccount,
  currentUserId,
  changed,
}: {
  ownerAccount: boolean;
  currentUserId: string;
  changed: () => void;
}) {
  type AdminTopic="dashboard"|"horses"|"visuals"|"store"|"shows"|"news"|"professions"|"accounts"|"economy"|"commerce"|"brands"|"balance"|"system"|"audit";
  const initialAdminTopic=(typeof location!=="undefined"?location.pathname.split("/")[2]:"")as AdminTopic;
  const [topic,setTopic]=useState<AdminTopic>(initialAdminTopic||"dashboard"),[permissions,setPermissions]=useState<string[]>([]);
  const [permissionTarget,setPermissionTarget]=useState(currentUserId),[permissionDraft,setPermissionDraft]=useState<string[]>([]);
  const [accounts, setAccounts] = useState<AdminStable[]>([]),
    [message, setMessage] = useState(""),
    [target, setTarget] = useState(currentUserId),
    [amount, setAmount] = useState(10000),
    [stallGrant,setStallGrant]=useState(10),
    [stallReason,setStallReason]=useState("Admin benefit"),
    [name, setName] = useState("Admin Custom"),
    [species, setSpecies] = useState("Horse"),
    [breed, setBreed] = useState("Custom Breed"),
    [sex, setSex] = useState("Mare"),
    [years, setYears] = useState(2),
    [color, setColor] = useState("Bay"),
    [pattern, setPattern] = useState("Solid"),
    [image, setImage] = useState(""),
    [originBrand,setOriginBrand]=useState(true),
    [genes, setGenes] = useState("{}"),
    [markings, setMarkings] = useState<Record<string, string>>({
      face: "none",
      left_front: "none",
      right_front: "none",
      left_hind: "none",
      right_hind: "none",
    }),
    [stats, setStats] = useState<Record<string, number>>(
      Object.fromEntries(GAME.stats.map((s) => [s, 15])),
    );
  const refresh = useCallback(async () => {
    const { data, error } = await supabase.rpc("admin_list_stables");
    if (error) setMessage(error.message);
    else setAccounts((data ?? []) as AdminStable[]);
  }, []);
  useEffect(() => {
    const timer = setTimeout(() => {
      void refresh();
    }, 0);
    return () => clearTimeout(timer);
  }, [refresh]);
  useEffect(()=>{void supabase.rpc("admin_effective_permissions").then(({data})=>setPermissions((data??[]).map((x:{permission:string})=>x.permission)));},[]);
  useEffect(()=>{const restore=()=>setTopic((location.pathname.split("/")[2]as AdminTopic)||"dashboard");addEventListener("popstate",restore);return()=>removeEventListener("popstate",restore)},[]);
  const openTopic=(next:AdminTopic)=>{history.pushState({leAdmin:true},"",next==="dashboard"?"/admin":`/admin/${next}`);setTopic(next)};
  const can=(permission:string)=>ownerAccount||permissions.includes(permission);
  const topics:{id:AdminTopic;label:string;permission?:string}[]=[
    {id:"dashboard",label:"Dashboard"},{id:"horses",label:"Horses",permission:"admin.horses.view"},{id:"visuals",label:"Horse Visuals",permission:"admin.visuals.view"},
    {id:"store",label:"Store & Inventory",permission:"admin.store.view"},{id:"shows",label:"Shows",permission:"admin.shows.view"},{id:"news",label:"News",permission:"admin.news.view"},{id:"professions",label:"Professions",permission:"admin.professions.view"},
    {id:"accounts",label:"Accounts",permission:"admin.accounts.view"},{id:"economy",label:"Economy / Bank",permission:"admin.economy.view"},{id:"commerce",label:"Commerce",permission:"admin.commerce.view"},{id:"brands",label:"Stable Brands",permission:"admin.brands.view"},
    {id:"balance",label:"Game Balance",permission:"admin.balance.view"},{id:"system",label:"System / QA",permission:"admin.system.view"},{id:"audit",label:"Audit Log",permission:"admin.audit.view"}
  ];
  const visibleTopics=topics.filter(x=>!x.permission||can(x.permission));
  const allPermissions=topics.flatMap(x=>x.permission?[x.permission,x.permission.replace(".view",".edit")]:[]).concat(["admin.visuals.upload","admin.visuals.review","admin.visuals.approve","admin.visuals.production","admin.shows.bulk_enter_all","admin.shows.bulk_create","admin.shows.bulk_run","admin.shows.lock","admin.shows.run","admin.shows.cancel","admin.shows.preview","admin.shows.duplicate","admin.shows.qa","admin.shows.private","admin.shows.processing","admin.shows.audit","admin.professions.qa","professions.qa_progression_override","professions.qa_bypass_certification_cooldown","admin.audit.view"]).filter((x,i,a)=>a.indexOf(x)===i&&!x.endsWith("dashboard.edit"));
  const run = async (
    job: () => Promise<{ error: Error | null }>,
    success: string,
  ) => {
    const { error } = await job();
    setMessage(error?.message ?? success);
    if (!error) {
      await refresh();
      changed();
    }
    return !error;
  };
  const create = async () => {
    let genetics: Record<string, unknown>;
    try {
      genetics = JSON.parse(genes);
    } catch {
      setMessage("Advanced genetics must be valid JSON.");
      return;
    }
    let createdHorse:{id:string}|null=null;
    const created = await run(async () => {
      const { data,error } = await supabase.rpc("admin_create_visual_horse", {
        target_owner: target,
        horse_name: name,
        horse_species: species,
        horse_breed: breed,
        horse_sex: sex,
        horse_age_years: years,
        desired_color: color,
        desired_pattern: pattern,
        desired_markings: markings,
        horse_stats: stats,
        advanced_genetics: genetics,
        horse_image_url: image,
      });
      createdHorse=data as {id:string}|null;
      if(!error&&!originBrand&&target===accounts.find((a)=>a.account_number===1)?.id&&createdHorse?.id){const correction=await supabase.rpc("owner_correct_horse_brand",{p_horse:createdHorse.id,p_stable:null,p_reason:"Owner-created test/import horse without Origin Brand"});if(correction.error)return{error:correction.error}}
      return { error };
    }, `${name} was created with its permanent Legacy Equine visual identity.`);
    if (created && !image) {
      changed();
    }
    if(created)setOriginBrand(true);
  };
  const colors = [
      "Chestnut",
      "Sorrel",
      "Bay",
      "Black",
      "Palomino",
      "Buckskin",
      "Smoky Black",
      "Cremello",
      "Perlino",
      "Smoky Cream",
      "Bay Dun",
      "Red Dun",
      "Grullo",
      "Gray",
      "Blue Roan",
      "Bay Roan",
      "Red Roan",
      "Strawberry Roan",
    ],
    patterns = ["Solid", "Tobiano", "Frame Overo", "Sabino", "Splashed White"],
    faceMarkOptions = ["none","snip_01","faint_01","faint_star_01","star_01","half_star_01","strip_01","broken_strip_01","star_strip_01","blaze_01","blaze_snip_01","irregular_blaze_01","bald_face_01"],
    markOptions = ["none","coronet_01","white_heel_01","half_pastern_01","pastern_01","ankle_01","half_sock_01","full_sock_01","high_sock_01"];
  return (
    <div className="admincontrolcenter">
      <Title
        title="Admin Control Center"
        sub="Secure operations, review workspaces, and game oversight"
      />
      <nav className="admintopics" aria-label="Admin topics">{visibleTopics.map(x=><button key={x.id} className={topic===x.id?"active":""} onClick={()=>openTopic(x.id)}>{x.label}</button>)}</nav>
      <div className="admincrumbs"><button onClick={()=>openTopic("dashboard")}>Admin</button><span>›</span><b>{topics.find(x=>x.id===topic)?.label}</b></div>
      {message && <div className="notice">✦ {message}</div>}
      {topic==="dashboard"&&<section className="admindashboard"><article onClick={()=>openTopic("horses")}><span>HORSES</span><b>Horse Operations</b><small>Create, edit, and oversee horses</small></article><article onClick={()=>openTopic("visuals")}><span>HORSE VISUALS</span><b>Deterministic Library</b><small>Coverage, review, and production</small></article><article onClick={()=>openTopic("shows")}><span>SHOWS</span><b>Show Control</b><small>Open, scheduled, QA, and archive</small></article><article onClick={()=>openTopic("professions")}><span>PROFESSIONS</span><b>Career Operations</b><small>Providers, rates, and QA</small></article><article onClick={()=>openTopic("accounts")}><span>ACCOUNTS</span><b>{accounts.length} accounts</b><small>Roles, access, and capacity</small></article><article onClick={()=>openTopic("economy")}><span>ECONOMY</span><b>LED & Treasury</b><small>Ledgered controls and funds</small></article><article onClick={()=>openTopic("commerce")}><span>COMMERCE</span><b>Payment Readiness</b><small>Catalog, entitlements, subscriptions, audit</small></article><article onClick={()=>openTopic("system")}><span>SYSTEM</span><b>Production QA</b><small>Domain, database, schedulers</small></article></section>}
      {topic==="visuals"&&<><VisualAssetRequirements notify={setMessage}/><VisualAssetImporter notify={setMessage}/><details className="adminaccordion"><summary>Legacy template administration</summary><HorseImageTemplates notify={setMessage} changed={changed}/></details></>}
      {topic==="balance"&&<div className="adminaccordions"><details open><summary>Foundation Horse Generation & Genetics</summary><BreedGeneticsAdmin notify={setMessage}/></details><details><summary>Feed, Tack, Wellness & Aging</summary><StoreWellnessAdmin notify={setMessage}/></details><details><summary>Show Scoring & Account Progression</summary><p className="featurehint">Configuration remains server-authoritative. Dedicated controls will appear here as they are introduced.</p></details></div>}
      {topic==="store"&&<StoreWellnessAdmin notify={setMessage}/>} 
      {topic==="shows"&&<AdminShows notify={setMessage}/>} 
      {topic==="news"&&<AdminNews notify={setMessage}/>}
      {topic==="professions"&&<AdminProfessions notify={setMessage}/>} 
      {topic==="commerce"&&ownerAccount&&<AdminCommerce notify={setMessage}/>}
      {topic==="brands"&&<StableBrandsAdmin notify={setMessage}/>}
      {topic==="system"&&<section className="panel"><p className="eyebrow">PRODUCTION READINESS</p><h2>System / QA</h2><div className="systemstatus">{[["Production Domain","Healthy"],["Supabase","Healthy"],["Database Migrations","Healthy"],["Show Processor","Healthy"],["Weekly Allowance","Healthy"],["Visual Asset Coverage","Warning"],["SMS Verification","Not Configured"],["Vercel Deployment","Healthy"],["Game Version",process.env.NEXT_PUBLIC_VERCEL_GIT_COMMIT_SHA?.slice(0,7)||"Current"]].map(([k,v])=><div key={k}><b>{k}</b><span className={`health-${v.toLowerCase().replaceAll(" ","-")}`}>{v}</span></div>)}</div></section>}
      {topic==="audit"&&<AdminAuditLog/>}
      {topic==="economy"&&<><TreasuryDashboard />
      <section className="panel settingsform">
        <p className="eyebrow">LE ECONOMY</p>
        <h2>Adjust a stable balance</h2>
        <label>
          Stable
          <select value={target} onChange={(e) => setTarget(e.target.value)}>
            {accounts.map((a) => (
              <option key={a.id} value={a.id}>
                #{a.account_number} · {a.name} · {money(a.balance)} LE
              </option>
            ))}
          </select>
        </label>
        <label>
          Amount <small>Use a negative amount to remove LE Dollars.</small>
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(Number(e.target.value))}
          />
        </label>
        <button
          className="primary"
          disabled={!target || amount === 0}
          onClick={() =>
            run(
              async () => {
                const { error } = await supabase.rpc("admin_adjust_balance", {
                  target_stable: target,
                  adjustment: amount,
                  admin_reason: "Admin console LE adjustment",
                });
                return { error };
              },
              `${amount > 0 ? "Added" : "Removed"} ${money(Math.abs(amount))} LE.`,
            )
          }
        >
          Apply Ledgered Adjustment
        </button>
      </section></>}
      {topic==="horses"&&
      <section className="panel settingsform">
        <p className="eyebrow">CUSTOM ANIMAL CREATOR</p>
        <h2>Create a custom horse</h2>
        <p className="panelsub">
          Choose visible traits normally. Legacy Equine translates supported
          choices into a valid genotype and uses an approved anatomy template;
          otherwise the branded Visual Pending state is used without substituting incorrect horse artwork.
        </p>
        <div className="adminformgrid">
          <label>
            Owner
            <select value={target} onChange={(e) => setTarget(e.target.value)}>
              {accounts.map((a) => (
                <option key={a.id} value={a.id}>
                  #{a.account_number} · {a.name}
                </option>
              ))}
            </select>
          </label>
          <label>
            Name
            <input value={name} onChange={(e) => setName(e.target.value)} />
          </label>
          <label>
            Species / animal type
            <input
              value={species}
              onChange={(e) => setSpecies(e.target.value)}
            />
          </label>
          <label>
            Breed
            <input value={breed} onChange={(e) => setBreed(e.target.value)} />
          </label>
          <label>
            Sex
            <select value={sex} onChange={(e) => setSex(e.target.value)}>
              <option>Mare</option>
              <option>Stallion</option>
            </select>
          </label>
          <label>
            Age in game years
            <input
              type="number"
              min={0}
              max={100}
              step="0.1"
              value={years}
              onChange={(e) => setYears(Number(e.target.value))}
            />
          </label>
          <label>
            Genetic color
            <select value={color} onChange={(e) => setColor(e.target.value)}>
              {colors.map((x) => (
                <option key={x}>{x}</option>
              ))}
            </select>
          </label>
          <label>
            Genetic pattern
            <select
              value={pattern}
              onChange={(e) => setPattern(e.target.value)}
            >
              {patterns.map((x) => (
                <option key={x}>{x}</option>
              ))}
            </select>
          </label>
          <label>
            Face marking
            <select
              value={markings.face}
              onChange={(e) =>
                setMarkings({ ...markings, face: e.target.value })
              }
            >
              {faceMarkOptions.map(
                (x) => (
                  <option key={x}>{x}</option>
                ),
              )}
            </select>
          </label>
          {(
            ["left_front", "right_front", "left_hind", "right_hind"] as const
          ).map((key) => (
            <label key={key}>
              {key.replaceAll("_", " ")}
              <select
                value={markings[key]}
                onChange={(e) =>
                  setMarkings({ ...markings, [key]: e.target.value })
                }
              >
                {markOptions.map((x) => (
                  <option key={x}>{x}</option>
                ))}
              </select>
            </label>
          ))}
          <label>
            Existing image URL{" "}
            <small>Optional; leave blank for approved-template artwork or the safe fallback.</small>
            <input value={image} onChange={(e) => setImage(e.target.value)} />
          </label>
          {ownerAccount && target === accounts.find((a) => a.account_number === 1)?.id && (
            <label className="checklabel">
              <input
                type="checkbox"
                checked={originBrand}
                onChange={(e) => setOriginBrand(e.target.checked)}
              />
              Origin Brand: TFR
              <small>
                Enabled by default for normal Owner-origin horses. Turn this off only for an intentional test or imported horse.
              </small>
            </label>
          )}
        </div>
        <h3>Base stats</h3>
        <div className="adminstatgrid">
          {GAME.stats.map((s) => (
            <label key={s}>
              {s}
              <input
                type="number"
                min={0}
                max={1000000}
                value={stats[s]}
                onChange={(e) =>
                  setStats({ ...stats, [s]: Number(e.target.value) })
                }
              />
            </label>
          ))}
        </div>
        <label>
          Advanced Genetics JSON{" "}
          <small>
            Optional. Leave as {`{}`} to use the friendly color and pattern
            controls.
          </small>
          <textarea value={genes} onChange={(e) => setGenes(e.target.value)} />
        </label>
        <button
          className="primary"
          disabled={!target || !name.trim() || !breed.trim() || !species.trim()}
          onClick={create}
        >
          Create Custom Horse
        </button>
      </section>}
      {topic==="accounts"&&ownerAccount && (
        <><ArtworkStorageAdmin notify={setMessage}/><section className="panel settingsform">
          <p className="eyebrow">OWNER CAPACITY CONTROL</p><h2>Permanent stall benefits</h2><p className="panelsub">Grant auditable complimentary stalls or explicitly change unlimited capacity. Ordinary administrators cannot use these controls.</p>
          <label>Stable<select value={target} onChange={e=>setTarget(e.target.value)}>{accounts.map(a=><option key={a.id} value={a.id}>#{a.account_number} · {a.name} · {a.stable_occupied}/{a.unlimited_capacity?"Unlimited":a.stable_capacity}</option>)}</select></label>
          <label>Complimentary stalls<input type="number" min={1} value={stallGrant} onChange={e=>setStallGrant(Number(e.target.value))}/></label><label>Reason<input value={stallReason} onChange={e=>setStallReason(e.target.value)}/></label>
          <button className="primary" onClick={()=>run(async()=>{const{error}=await supabase.rpc("owner_grant_stalls",{target_stable:target,stall_count:stallGrant,grant_reason:stallReason});return{error}},`Granted ${stallGrant} permanent complimentary stalls.`)}>Grant Complimentary Stalls</button>
          <div className="buttonrow"><button onClick={()=>run(async()=>{const{error}=await supabase.rpc("owner_set_unlimited_capacity",{target_stable:target,make_unlimited:true,change_reason:stallReason});return{error}},"Unlimited capacity granted.")}>Grant Unlimited</button><button disabled={accounts.find(a=>a.id===target)?.account_number===1} onClick={()=>run(async()=>{const{error}=await supabase.rpc("owner_set_unlimited_capacity",{target_stable:target,make_unlimited:false,change_reason:stallReason});return{error}},"Unlimited capacity revoked.")}>Revoke Unlimited</button></div>
        </section><section className="panel">
          <p className="eyebrow">OWNER CONTROL</p>
          <h2>Designate administrators</h2>
          <p className="panelsub">
            Only LE Account #1 can grant or revoke administrator access. The
            owner account cannot be demoted.
          </p>
          <div className="adminaccounts">
            {accounts.map((a) => (
              <div key={a.id}>
                <span>
                  <b>
                    #{a.account_number} · {a.name}
                  </b>
                  <small>{a.is_admin ? "Administrator" : "Player"}</small>
                  <small>{a.can_edit_horses ? "Horse Editor permitted" : "No Horse Editor permission"}</small>
                </span>
                <button
                  disabled={a.account_number === 1}
                  onClick={() =>
                    run(
                      async () => {
                        const { error } = await supabase.rpc(
                          "owner_set_admin",
                          { target_stable: a.id, make_admin: !a.is_admin },
                        );
                        return { error };
                      },
                      `${a.name} is ${a.is_admin ? "no longer an administrator" : "now an administrator"}.`,
                    )
                  }
                >
                  {a.is_admin ? "Remove Admin" : "Make Admin"}
                </button>
                <button
                  disabled={a.account_number === 1}
                  onClick={() => run(async()=>{const{error}=await supabase.rpc("owner_set_horse_editor_permission",{target_stable:a.id,grant_permission:!a.can_edit_horses});return{error}},`${a.name} ${a.can_edit_horses?"no longer has":"now has"} Horse Editor permission.`)}
                >
                  {a.can_edit_horses ? "Remove Horse Editor" : "Grant Horse Editor"}
                </button>
              </div>
            ))}
          </div>
          <details className="adminpermissioneditor"><summary>Granular roles &amp; effective permissions</summary><p className="panelsub">Owner #1 always has every capability. Assign only the capabilities another administrator requires.</p><label>Administrator<select value={permissionTarget} onChange={e=>{setPermissionTarget(e.target.value);setPermissionDraft([])}}>{accounts.filter(a=>a.account_number!==1).map(a=><option value={a.id} key={a.id}>#{a.account_number} · {a.name}</option>)}</select></label><div className="permissiongrid">{allPermissions.map(p=><label key={p}><input type="checkbox" checked={permissionDraft.includes(p)} onChange={e=>setPermissionDraft(e.target.checked?[...permissionDraft,p]:permissionDraft.filter(x=>x!==p))}/>{p}</label>)}</div><button className="primary" disabled={!permissionTarget} onClick={()=>run(async()=>{const{error}=await supabase.rpc("owner_set_admin_permissions",{p_stable:permissionTarget,p_permissions:permissionDraft});return{error}},"Administrator permissions updated and audited.")}>Save Effective Permissions</button></details>
        </section></>
      )}
    </div>
  );
}

function AdminAuditLog(){const[rows,setRows]=useState<{id:number;actor:string;action_type:string;system:string;target_type:string;target_id:string;created_at:string}[]>([]),[query,setQuery]=useState("");useEffect(()=>{void supabase.rpc("admin_audit_feed",{p_limit:250}).then(({data})=>setRows((data??[]) as typeof rows))},[]);const shown=rows.filter(x=>`${x.actor} ${x.action_type} ${x.system} ${x.target_type} ${x.target_id}`.toLowerCase().includes(query.toLowerCase()));return <section className="panel"><p className="eyebrow">CENTRAL ADMIN HISTORY</p><h2>Audit Log</h2><input aria-label="Search audit log" placeholder="Filter admin, action, system, horse, account, or show…" value={query} onChange={e=>setQuery(e.target.value)}/><div className="adminscrolltable"><div className="adminrow adminrowhead"><b>Date</b><b>Admin</b><b>System</b><b>Action</b></div>{shown.map(x=><div className="adminrow" key={x.id}><time>{new Date(x.created_at).toLocaleString()}</time><span>{x.actor}</span><span>{x.system}</span><span>{x.action_type}</span></div>)}</div></section>}
function MediaUpload({
  title,
  description,
  image,
  shape,
  upload,
}: {
  title: string;
  description: string;
  image: string;
  shape: "wide" | "avatar" | "horse";
  upload: (f: File) => void;
}) {
  const inputId = `upload-${title.replace(/[^a-z0-9]/gi, "-").toLowerCase()}`;
  return (
    <article className={`mediaupload ${shape}`}>
      <div className="mediapreview">
        {image ? (
          shape === "horse" ? <ContainedHorseArtwork url={image} alt={title}/> : <img src={image} alt={title} />
        ) : (
          <span>
            {shape === "avatar" ? "☺" : shape === "horse" ? "♞" : "⌂"}
          </span>
        )}
      </div>
      <div>
        <h3>{title}</h3>
        <p>{description}</p>
        <label className="uploadbutton" htmlFor={inputId}>
          Choose Image
        </label>
        <input
          id={inputId}
          type="file"
          accept="image/jpeg,image/png,image/webp,image/gif"
          onChange={(e) => {
            const file = e.target.files?.[0];
            if (file) upload(file);
          }}
        />
      </div>
    </article>
  );
}
function LegacyHorsePage({
  h,
  horses,
  openView,
  save,
  train,
  breed,
}: {
  h: Horse;
  horses: Horse[];
  openView: (v: "pedigree" | "progeny") => void;
  save: (n: string, b: string, i: string) => void;
  train: (s: string) => void;
  breed: (m: string) => void;
}) {
  const [n, setN] = useState(h.name),
    [b, setB] = useState(h.biography),
    [i, setI] = useState(h.image_url),
    [mare, setMare] = useState("");
  const mares = horses.filter((x) => x.sex === "Mare" && canBreed(x));
  return (
    <>
      <section className="profile">
        <div className="portrait">
          {i ? <img src={i} alt={n} /> : <span>♞</span>}
          <label>
            Custom artwork URL
            <input value={i} onChange={(e) => setI(e.target.value)} />
          </label>
        </div>
        <div>
          <p className="eyebrow">
            {h.origin.toUpperCase()} · GENERATION {h.generation}
          </p>
          <input
            className="nameedit"
            value={n}
            onChange={(e) => setN(e.target.value)}
          />
          <p className="meta">
            {h.breed} <b>•</b> {h.sex} <b>•</b> {ageLabel(h)}{" "}
            <b>•</b> {h.color}
          </p>
          <p className="ownerline">Owned by your stable</p>
          <textarea
            value={b}
            placeholder="Write this horse's story…"
            onChange={(e) => setB(e.target.value)}
          />
          <button className="primary" onClick={() => save(n, b, i)}>
            Save Profile
          </button>
        </div>
        <div className="points">
          <b>{overall(h)}</b>
          <span>Overall Points</span>
          <small>
            {canBreed(h) ? "● Breeding eligible" : "○ Not eligible"}
          </small>
        </div>
      </section>
      <div className="profiletabs">
        <button className="active">Overview</button>
        <button>Stats</button>
        <button>Training</button>
        <button disabled>Shows · Soon</button>
        <button onClick={() => openView("pedigree")}>Pedigree</button>
        <button onClick={() => openView("progeny")}>Progeny</button>
        <button>Breeding</button>
      </div>
      <section className="panel">
        <h2>Stats & Training</h2>
        <p className="panelsub">
          Build your horse one thoughtful training session at a time.
        </p>
        <div className="statlist">
          {GAME.stats.map((s) => (
            <div key={s}>
              <span>
                {s}
              </span>
              <strong>{h.stats[s]}</strong>
              <em>+{h.tack_bonuses[s] ?? 0} tack</em>
              <b>{h.stats[s] + (h.tack_bonuses[s] ?? 0)}</b>
              <button disabled={!canTrain(h)} onClick={() => train(s)}>
                Train +1
              </button>
            </div>
          ))}
        </div>
      </section>
      {h.sex === "Stallion" && (
        <section className="panel breed">
          <p className="eyebrow">BREEDING BARN</p>
          <h2>Breed {h.name}</h2>
          <p>
            Choose an eligible mare and welcome a new foal to your legacy
            instantly.
          </p>
          <select value={mare} onChange={(e) => setMare(e.target.value)}>
            <option value="">Select an eligible mare…</option>
            {mares.map((m) => (
              <option key={m.id} value={m.id}>
                {m.name} · {m.breed}
              </option>
            ))}
          </select>
          <button
            className="primary"
            disabled={!mare || !canBreed(h)}
            onClick={() => breed(mare)}
          >
            Confirm Breeding · ${h.stud_fee} LE
          </button>
        </section>
      )}
      {h.sex === "Mare" && h.last_bred_at && (
        <section className="panel cooldown">
          <h2>🌙 Resting after breeding</h2>
          <p>
            Ready to breed again on{" "}
            {new Date(
              new Date(h.last_bred_at).getTime() +
                GAME.mareCooldownDays * 86400000,
            ).toLocaleDateString()}
            .
          </p>
        </section>
      )}
    </>
  );
}
function GeneticsPanel({ h, horses }: { h: Horse; horses: Horse[] }) {
  const [mare, setMare] = useState(""),
    [preview, setPreview] = useState<{
      result_breed: string;
      total_lethal_percent: number;
      survival_percent: number;
      lethal_risks: { condition: string; chance_percent: number }[];
      variant_chances: Record<string, number>;
    } | null>(null),
    [error, setError] = useState("");
  const mares = horses.filter((x) => x.sex === "Mare" && x.id !== h.id);
  const inspect = async () => {
    setError("");
    const { data, error } = await supabase.rpc("get_breeding_genetic_preview", {
      stallion_id: h.id,
      mare_id: mare,
    });
    if (error) setError(error.message);
    else setPreview(data);
  };
  return (
    <details className="panel genetics-disclosure">
      <summary>Genetics & Color · {h.color}</summary>
      <div className="genetics-content">
        <p className="eyebrow">AUTHORITATIVE GENETICS</p>
        <h2>Genotype & inheritance</h2>
        <p className="panelsub">
          Each foal randomly inherits one allele at every locus from each
          parent. Phenotypes are calculated from the inherited pair; hidden
          carriers remain visible here.
        </p>
        <div className="storestats">
          {Object.entries(h.genetics ?? {})
            .sort(([a], [b]) => a.localeCompare(b))
            .map(([locus, alleles]) => (
              <span key={locus}>
                <b>{locus}</b> {alleles.join("/")}
              </span>
            ))}
        </div>
        <p>
          <b>Breed composition:</b>{" "}
          {Object.entries(h.breed_composition ?? {})
            .map(([breed, share]) => `${breed} ${Math.round(share * 100)}%`)
            .join(" · ") || h.breed}
        </p>
        {h.sex === "Stallion" && (
          <div className="breed">
            <h3>Genetic cross preview</h3>
            <select
              value={mare}
              onChange={(e) => {
                setMare(e.target.value);
                setPreview(null);
              }}
            >
              <option value="">Choose a mare…</option>
              {mares.map((m) => (
                <option value={m.id} key={m.id}>
                  {m.name} · {m.breed}
                </option>
              ))}
            </select>
            <button className="primary" disabled={!mare} onClick={inspect}>
              Calculate exact chances
            </button>
            {error && <p>{error}</p>}
            {preview && (
              <div className="featurehint">
                <h3>{preview.result_breed}</h3>
                <p>
                  <b>Viable foal chance:</b> {preview.survival_percent}%
                </p>
                {preview.total_lethal_percent > 0 && (
                  <p>
                    <b>Lethal genotype chance:</b>{" "}
                    {preview.total_lethal_percent}% — a non-viable foal is not
                    created and no fee is charged.
                  </p>
                )}
                {preview.lethal_risks.map((r) => (
                  <p key={r.condition}>
                    {r.condition}: {r.chance_percent}%
                  </p>
                ))}
                <p>
                  <b>Color and pattern inheritance:</b>{" "}
                  {Object.entries(preview.variant_chances)
                    .map(([name, chance]) => `${name} ${chance}%`)
                    .join(" · ") || "No tested variant alleles in this pairing"}
                </p>
              </div>
            )}
          </div>
        )}
      </div>
    </details>
  );
}
function Pedigree({
  h,
  horses,
  open,
}: {
  h: Horse;
  horses: Horse[];
  open: (h: Horse) => void;
}) {
  const find = (id: string | null) => horses.find((x) => x.id === id);
  const sire = find(h.sire_id),
    dam = find(h.dam_id);
  const P = ({ x, label }: { x: Horse | undefined; label: string }) => (
    <div className="ped">
      <small>{label}</small>
      {x ? (
        <button onClick={() => open(x)}>
          <b>{x.name}</b>
          <span>{x.breed}</span>
        </button>
      ) : (
        <i>Unknown foundation line</i>
      )}
    </div>
  );
  return (
    <>
      <Title
        title={`${h.name} · Pedigree`}
        sub="Three generations of permanent ancestry"
      />
      <div className="pedigree">
        <div>
          <P x={h} label="SUBJECT" />
        </div>
        <div>
          <P x={sire} label="SIRE" />
          <P x={dam} label="DAM" />
        </div>
        <div>
          <P x={find(sire?.sire_id ?? null)} label="PATERNAL GRANDSIRE" />
          <P x={find(sire?.dam_id ?? null)} label="PATERNAL GRANDDAM" />
          <P x={find(dam?.sire_id ?? null)} label="MATERNAL GRANDSIRE" />
          <P x={find(dam?.dam_id ?? null)} label="MATERNAL GRANDDAM" />
        </div>
      </div>
    </>
  );
}
