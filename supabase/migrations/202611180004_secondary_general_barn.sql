-- Private General Barn organization under the existing Stable. Placement never
-- changes ownership, total Stable capacity, or gameplay eligibility.
alter table public.horses add column if not exists stable_barn text not null default 'training';
alter table public.horses drop constraint if exists horses_stable_barn_check;
alter table public.horses add constraint horses_stable_barn_check check(stable_barn in('training','general'));
create index if not exists horses_owner_stable_barn_idx on public.horses(owner_id,stable_barn)where owner_id is not null and not retired;

drop policy if exists "public horses" on public.horses;
create policy "training barn horses are public" on public.horses for select using(
 owner_id is null or owner_id=auth.uid() or stable_barn='training' or public.is_owner_account()
);

create or replace function public.move_owned_horse_to_barn(p_horse uuid,p_barn text)
returns public.horses language plpgsql security definer set search_path=public as $$
declare result public.horses;begin
 if p_barn not in('training','general')then raise exception'Choose the Training Barn or General Barn';end if;
 update horses set stable_barn=p_barn where id=p_horse and owner_id=auth.uid()and not retired returning*into result;
 if result.id is null then raise exception'Choose an active horse you own';end if;
 return result;
end$$;
revoke all on function public.move_owned_horse_to_barn(uuid,text)from public,anon;
grant execute on function public.move_owned_horse_to_barn(uuid,text)to authenticated;

create or replace function public.get_public_stable_profile(p_stable uuid)returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare s stables;p stable_public_profiles;b stable_brands;result jsonb;begin
 select*into s from stables where id=p_stable and(account_status='active'or id=auth.uid());if not found then raise exception'Stable not found';end if;
 select*into p from stable_public_profiles where stable_id=p_stable;
 select*into b from stable_brands where stable_id=p_stable and(active or reserved);
 result:=jsonb_build_object(
  'id',s.id,'name',s.name,'username',s.username,'account_number',s.account_number,'ranch_image_url',s.ranch_image_url,'created_at',s.created_at,
  'brand',case when b.id is null then null else jsonb_build_object('code',b.code,'mark_url',b.mark_url,'active',b.active)end,
  'stable_news',coalesce(p.stable_news,''),'about',coalesce(nullif(p.about_text,''),s.bio,''),
  'blocks',coalesce(p.blocks,'[{"id":"banner","type":"banner","visible":true},{"id":"news","type":"news","visible":true},{"id":"about","type":"about","visible":true},{"id":"featured","type":"featured","visible":true},{"id":"stallions","type":"stallions","visible":true},{"id":"broodmares","type":"broodmares","visible":true},{"id":"winners","type":"winners","visible":true},{"id":"services","type":"services","visible":true},{"id":"roster","type":"roster","visible":true},{"id":"custom","type":"custom","visible":true,"content":""}]'::jsonb),
  'featured_horses',coalesce(p.featured_horses,'{}'::uuid[]),'layout_mode',coalesce(p.layout_mode,'standard'),'layout_image_url',coalesce(p.layout_image_url,''),
  'owner',auth.uid()=p_stable,'can_customize',has_custom_stable_layout(p_stable),
  'horses',coalesce((select jsonb_agg(jsonb_build_object('id',h.id,'name',h.name,'breed',h.breed,'sex',h.sex,'color',h.color,'image_url',h.image_url,'career_points',h.career_points)order by h.name)from horses h where h.owner_id=p_stable and not h.retired and h.stable_barn='training'),'[]'::jsonb),
  'services',get_public_professional_services(p_stable));return result;
end$$;

create or replace function public.get_public_player_profile(p_stable uuid)returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare s stables;b stable_brands;can_view_activity boolean;begin
 select*into s from stables where id=p_stable and account_status='active';if not found then raise exception'Player profile not found';end if;
 select*into b from stable_brands where stable_id=s.id and(active or reserved);
 can_view_activity:=auth.uid()=s.id or exists(select 1 from stables v where v.id=auth.uid()and(v.is_admin or v.account_number=1 or v.community_role in('moderator','admin','owner')));
 return jsonb_build_object('id',s.id,'username',s.username,'account_number',s.account_number,'avatar_url',s.avatar_url,'bio',s.bio,'established_at',s.created_at,'account_level',account_level_for_xp(s.account_xp),'stable_name',s.name,'brand',case when b.id is null then null else jsonb_build_object('code',b.code,'mark_url',b.mark_url)end,'horse_count',(select count(*)from horses h where h.owner_id=s.id and not h.retired and h.stable_barn='training'),'owner',auth.uid()=s.id,'last_active_at',case when can_view_activity then s.last_active_at else null end,'services',get_public_professional_services(s.id));
end$$;

create or replace function public.get_community_directory(p_search text default'',p_level integer default null,p_profession text default null,p_sort text default'account_asc',p_offset integer default 0,p_limit integer default 100)
returns table(stable_id uuid,username text,account_number bigint,stable_name text,brand_code text,brand_mark_url text,account_level integer,established_at timestamptz,avatar_url text,ranch_image_url text,horse_count bigint,professions text[])
language sql stable security definer set search_path=public as $$with visible as(select s.id,s.username,s.account_number,s.name,s.created_at,s.avatar_url,s.ranch_image_url,account_level_for_xp(s.account_xp)level,b.code brand_code,b.mark_url,(select count(*)from horses h where h.owner_id=s.id and not h.retired and h.stable_barn='training')horse_count,coalesce((select array_agg(distinct pr.name order by pr.name)from player_professions pp join professions pr on pr.id=pp.profession_id where pp.stable_id=s.id and pp.certification_level>0),'{}')professions from stables s left join stable_brands b on b.stable_id=s.id and(b.active or b.reserved)where s.account_status='active')select v.id,v.username,v.account_number,v.name,v.brand_code,v.mark_url,v.level,v.created_at,v.avatar_url,v.ranch_image_url,v.horse_count,v.professions from visible v where(trim(coalesce(p_search,''))=''or coalesce(v.username,'')ilike'%'||trim(p_search)||'%'or v.name ilike'%'||trim(p_search)||'%'or coalesce(v.brand_code,'')ilike'%'||trim(p_search)||'%'or v.account_number::text=regexp_replace(trim(p_search),'^#',''))and(p_level is null or v.level=p_level)and(p_profession is null or p_profession=''or p_profession=any(v.professions))order by case when p_sort='account_asc'then v.account_number end,case when p_sort='account_desc'then v.account_number end desc,case when p_sort='stable'then lower(v.name)end,case when p_sort='player'then lower(coalesce(v.username,v.name))end,case when p_sort='level'then v.level end desc,v.account_number offset greatest(p_offset,0)limit least(greatest(p_limit,1),100)$$;

create or replace function public.save_public_stable_content(p_news text,p_about text,p_featured uuid[])returns void
language plpgsql security definer set search_path=public as $$declare clean_featured uuid[];begin
 perform require_safe_player_content(concat_ws(' ',p_news,p_about));
 select coalesce(array_agg(id order by id),'{}')into clean_featured from(select distinct h.id from unnest(coalesce(p_featured,'{}'))wanted(id)join horses h on h.id=wanted.id and h.owner_id=auth.uid()and not h.retired and h.stable_barn='training' limit 12)x;
 insert into stable_public_profiles(stable_id,stable_news,about_text,featured_horses)values(auth.uid(),stable_safe_rich_text(p_news),stable_safe_rich_text(p_about),clean_featured)on conflict(stable_id)do update set stable_news=excluded.stable_news,about_text=excluded.about_text,featured_horses=excluded.featured_horses,updated_at=now();
end$$;
