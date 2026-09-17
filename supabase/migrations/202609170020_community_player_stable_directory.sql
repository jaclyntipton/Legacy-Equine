-- Visitor-safe Community player/Stable discovery.
create or replace function public.get_community_directory(
 p_search text default '',p_level integer default null,p_profession text default null,p_sort text default 'account_asc',p_offset integer default 0,p_limit integer default 100
)returns table(stable_id uuid,username text,account_number bigint,stable_name text,brand_code text,brand_mark_url text,account_level integer,established_at timestamptz,avatar_url text,ranch_image_url text,horse_count bigint,professions text[])
language sql stable security definer set search_path=public as $$
 with visible as(
  select s.id,s.username,s.account_number,s.name,s.created_at,s.avatar_url,s.ranch_image_url,public.account_level_for_xp(s.account_xp)level,b.code brand_code,b.mark_url,
   (select count(*)from horses h where h.owner_id=s.id and not h.retired)horse_count,
   coalesce((select array_agg(distinct pr.name order by pr.name)from player_professions pp join professions pr on pr.id=pp.profession_id where pp.stable_id=s.id and pp.certification_level>0),'{}')professions
  from stables s left join stable_brands b on b.stable_id=s.id and(b.active or b.reserved)
  where s.account_status='active'
 )select v.id,v.username,v.account_number,v.name,v.brand_code,v.mark_url,v.level,v.created_at,v.avatar_url,v.ranch_image_url,v.horse_count,v.professions
 from visible v where
  (trim(coalesce(p_search,''))=''or coalesce(v.username,'')ilike'%'||trim(p_search)||'%'or v.name ilike'%'||trim(p_search)||'%'or coalesce(v.brand_code,'')ilike'%'||trim(p_search)||'%'or v.account_number::text=regexp_replace(trim(p_search),'^#',''))
  and(p_level is null or v.level=p_level)
  and(p_profession is null or p_profession=''or p_profession=any(v.professions))
 order by
  case when p_sort='account_asc'then v.account_number end asc,
  case when p_sort='account_desc'then v.account_number end desc,
  case when p_sort='stable'then lower(v.name)end asc,
  case when p_sort='player'then lower(coalesce(v.username,v.name))end asc,
  case when p_sort='level'then v.level end desc,
  v.account_number asc
 offset greatest(p_offset,0)limit least(greatest(p_limit,1),100)
$$;

create or replace function public.get_public_player_profile(p_stable uuid)returns jsonb
language plpgsql stable security definer set search_path=public as $$declare s stables;b stable_brands;begin
 select * into s from stables where id=p_stable and account_status='active';if not found then raise exception 'Player profile not found';end if;
 select * into b from stable_brands where stable_id=s.id and(active or reserved);
 return jsonb_build_object('id',s.id,'username',s.username,'account_number',s.account_number,'avatar_url',s.avatar_url,'bio',s.bio,'established_at',s.created_at,'account_level',account_level_for_xp(s.account_xp),'stable_name',s.name,'brand',case when b.id is null then null else jsonb_build_object('code',b.code,'mark_url',b.mark_url)end,'horse_count',(select count(*)from horses h where h.owner_id=s.id and not h.retired),'owner',auth.uid()=s.id);
end$$;

drop function if exists public.get_marketplace();
create function public.get_marketplace()
returns table(listing_id uuid,horse_id uuid,name text,breed text,sex horse_sex,color text,birth_date timestamptz,stats jsonb,image_url text,price integer,seller_id uuid,seller_name text,seller_username text,created_at timestamptz,brand_code_at_assignment text,brand_mark_at_assignment text,brand_origin text)
language sql security definer set search_path=public stable as $$
 select l.id,h.id,h.name,h.breed,h.sex,h.color,h.birth_date,h.stats,h.image_url,l.price,l.seller_id,s.name,s.username,l.created_at,h.brand_code_at_assignment,h.brand_mark_at_assignment,h.brand_origin
 from marketplace_listings l join horses h on h.id=l.horse_id join stables s on s.id=l.seller_id where l.status='active'and s.account_status='active'order by l.created_at desc
$$;

revoke all on function public.get_community_directory(text,integer,text,text,integer,integer),public.get_public_player_profile(uuid)from public;
grant execute on function public.get_community_directory(text,integer,text,text,integer,integer),public.get_public_player_profile(uuid),public.get_marketplace()to authenticated;
