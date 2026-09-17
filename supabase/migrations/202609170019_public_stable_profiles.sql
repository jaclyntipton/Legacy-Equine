-- Public Stable profiles and safe Level 20 block layouts.
create table if not exists public.stable_public_profiles(
 stable_id uuid primary key references public.stables(id) on delete cascade,
 stable_news text not null default '',
 about_text text not null default '',
 blocks jsonb not null default '[{"id":"banner","type":"banner","visible":true},{"id":"news","type":"news","visible":true},{"id":"about","type":"about","visible":true},{"id":"featured","type":"featured","visible":true},{"id":"stallions","type":"stallions","visible":true},{"id":"broodmares","type":"broodmares","visible":true},{"id":"winners","type":"winners","visible":true},{"id":"services","type":"services","visible":true},{"id":"custom","type":"custom","visible":true,"content":""}]'::jsonb,
 featured_horses uuid[] not null default '{}',
 updated_at timestamptz not null default now()
);
alter table public.stable_public_profiles enable row level security;
drop policy if exists "public stable layouts readable" on public.stable_public_profiles;
create policy "public stable layouts readable" on public.stable_public_profiles for select using(true);

create table if not exists public.stable_layout_capability_grants(
 stable_id uuid primary key references public.stables(id) on delete cascade,
 source text not null check(source in('subscription','gift','promotion')),
 active boolean not null default true,
 expires_at timestamptz,
 created_at timestamptz not null default now()
);
alter table public.stable_layout_capability_grants enable row level security;
drop policy if exists "own stable layout grant readable" on public.stable_layout_capability_grants;
create policy "own stable layout grant readable" on public.stable_layout_capability_grants for select using(stable_id=auth.uid());

create or replace function public.stable_safe_rich_text(p_text text,p_limit integer default 10000) returns text
language sql immutable set search_path=public as $$
 select left(trim(regexp_replace(regexp_replace(regexp_replace(coalesce(p_text,''),'<[^>]*>','','gim'),'(javascript|vbscript|data)\s*:','', 'gim'),'[\u0000-\u0008\u000B\u000C\u000E-\u001F]','','g')),least(greatest(p_limit,0),10000))
$$;

create or replace function public.has_custom_stable_layout(p_stable uuid default auth.uid()) returns boolean
language sql stable security definer set search_path=public as $$
 select public.is_owner_account(p_stable)
 or exists(select 1 from public.stables s join public.account_level_config c on c.level=public.account_level_for_xp(s.account_xp) where s.id=p_stable and c.custom_stable_layout)
 or exists(select 1 from public.stable_layout_capability_grants g where g.stable_id=p_stable and g.active and(g.expires_at is null or g.expires_at>now()))
$$;

create or replace function public.get_public_stable_profile(p_stable uuid) returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare s stables;p stable_public_profiles;b stable_brands;result jsonb;begin
 select * into s from stables where id=p_stable;if not found then raise exception 'Stable not found';end if;
 select * into p from stable_public_profiles where stable_id=p_stable;
 select * into b from stable_brands where stable_id=p_stable and(active or reserved);
 result:=jsonb_build_object(
  'id',s.id,'name',s.name,'username',s.username,'account_number',s.account_number,'ranch_image_url',s.ranch_image_url,'created_at',s.created_at,
  'brand',case when b.id is null then null else jsonb_build_object('code',b.code,'mark_url',b.mark_url,'active',b.active)end,
  'stable_news',coalesce(p.stable_news,''),'about',coalesce(nullif(p.about_text,''),s.bio,''),
  'blocks',coalesce(p.blocks,'[{"id":"banner","type":"banner","visible":true},{"id":"news","type":"news","visible":true},{"id":"about","type":"about","visible":true},{"id":"featured","type":"featured","visible":true},{"id":"stallions","type":"stallions","visible":true},{"id":"broodmares","type":"broodmares","visible":true},{"id":"winners","type":"winners","visible":true},{"id":"services","type":"services","visible":true},{"id":"custom","type":"custom","visible":true,"content":""}]'::jsonb),
  'featured_horses',coalesce(p.featured_horses,'{}'::uuid[]),'owner',auth.uid()=p_stable,'can_customize',public.has_custom_stable_layout(p_stable),
  'horses',coalesce((select jsonb_agg(jsonb_build_object('id',h.id,'name',h.name,'breed',h.breed,'sex',h.sex,'color',h.color,'image_url',h.image_url,'career_points',h.career_points)order by h.name)from horses h where h.owner_id=p_stable and not h.retired),'[]'::jsonb),
  'services',coalesce((select jsonb_agg(jsonb_build_object('name',sc.name,'price',o.price,'profession',pr.name,'certification',cl.name)order by pr.name,sc.name)from player_service_offerings o join service_catalog sc on sc.id=o.service_id join professions pr on pr.id=sc.profession_id join player_professions pp on pp.stable_id=o.stable_id and pp.profession_id=pr.id join certification_levels cl on cl.level=pp.certification_level where o.stable_id=p_stable and o.enabled and pp.available and sc.active and pp.certification_level>=sc.minimum_level),'[]'::jsonb)
 );return result;
end$$;

create or replace function public.save_public_stable_content(p_news text,p_about text,p_featured uuid[]) returns void
language plpgsql security definer set search_path=public as $$
declare clean_featured uuid[];begin
 select coalesce(array_agg(id order by id),'{}')into clean_featured from(select distinct h.id from unnest(coalesce(p_featured,'{}'))wanted(id)join horses h on h.id=wanted.id and h.owner_id=auth.uid() and not h.retired limit 12)x;
 insert into stable_public_profiles(stable_id,stable_news,about_text,featured_horses)values(auth.uid(),stable_safe_rich_text(p_news),stable_safe_rich_text(p_about),clean_featured)
 on conflict(stable_id)do update set stable_news=excluded.stable_news,about_text=excluded.about_text,featured_horses=excluded.featured_horses,updated_at=now();
end$$;

create or replace function public.save_public_stable_layout(p_blocks jsonb) returns void
language plpgsql security definer set search_path=public as $$
declare allowed text[]:=array['banner','news','about','featured','stallions','broodmares','winners','services','custom'];clean jsonb;begin
 if not has_custom_stable_layout(auth.uid())then raise exception 'Custom Stable Layouts unlock at Account Level 20';end if;
 if jsonb_typeof(p_blocks)<>'array'or jsonb_array_length(p_blocks)>20 then raise exception 'Invalid Stable layout';end if;
 if exists(select 1 from jsonb_array_elements(p_blocks)x where not(x->>'type'=any(allowed))or coalesce(x->>'id','')!~'^[a-z0-9_-]{1,40}$')then raise exception 'Unsupported Stable layout block';end if;
 select jsonb_agg(jsonb_build_object('id',x->>'id','type',x->>'type','visible',coalesce((x->>'visible')::boolean,true))||case when x->>'type'='custom'then jsonb_build_object('content',stable_safe_rich_text(x->>'content'))else'{}'::jsonb end)into clean from jsonb_array_elements(p_blocks)x;
 insert into stable_public_profiles(stable_id,blocks)values(auth.uid(),clean)on conflict(stable_id)do update set blocks=excluded.blocks,updated_at=now();
end$$;

create or replace function public.reset_public_stable_layout() returns void language plpgsql security definer set search_path=public as $$begin
 update stable_public_profiles set blocks='[{"id":"banner","type":"banner","visible":true},{"id":"news","type":"news","visible":true},{"id":"about","type":"about","visible":true},{"id":"featured","type":"featured","visible":true},{"id":"stallions","type":"stallions","visible":true},{"id":"broodmares","type":"broodmares","visible":true},{"id":"winners","type":"winners","visible":true},{"id":"services","type":"services","visible":true},{"id":"custom","type":"custom","visible":true,"content":""}]'::jsonb,updated_at=now()where stable_id=auth.uid();
end$$;

revoke all on function public.get_public_stable_profile(uuid),public.save_public_stable_content(text,text,uuid[]),public.save_public_stable_layout(jsonb),public.reset_public_stable_layout() from public;
grant execute on function public.get_public_stable_profile(uuid),public.save_public_stable_content(text,text,uuid[]),public.save_public_stable_layout(jsonb),public.reset_public_stable_layout() to authenticated;
