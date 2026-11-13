-- Legacy Finds: server-authoritative surprise items and small LED discoveries.

insert into public.store_products(id,department,name,description,price,active,quality,sort_order,icon_url)
values
 ('find_worn_glove','stable_supplies','Worn Riding Glove','A well-used riding glove found during your travels around Legacy Equine.',0,true,'Keepsake',900,null),
 ('find_lucky_horseshoe','stable_supplies','Lucky Horseshoe','A weathered horseshoe that might still hold a little luck.',0,true,'Keepsake',901,null),
 ('find_braided_crop','stable_supplies','Braided Riding Crop','A tidy braided crop discovered near the schooling ring.',0,true,'Keepsake',902,null),
 ('find_boot_polish','stable_supplies','Tin of Boot Polish','A small tin with just enough polish left for show day.',0,true,'Stable Supply',903,null),
 ('find_peppermint','stable_supplies','Peppermint Treat','A wrapped peppermint treat for your Stable collection.',0,true,'Treat',904,null),
 ('find_vet_wrap','stable_supplies','Roll of Vet Wrap','A useful unopened roll of colorful vet wrap.',0,true,'Stable Supply',905,null)
on conflict(id)do update set name=excluded.name,description=excluded.description,department=excluded.department,active=true,quality=excluded.quality,icon_url=excluded.icon_url;

create table public.legacy_find_config(
 id boolean primary key default true check(id),
 enabled boolean not null default true,
 discovery_chance numeric not null default .18 check(discovery_chance between 0 and 1),
 cooldown_minutes integer not null default 12 check(cooldown_minutes between 1 and 1440),
 daily_award_limit integer not null default 4 check(daily_award_limit between 1 and 50),
 updated_at timestamptz not null default now(),
 updated_by uuid references public.stables(id)
);
insert into public.legacy_find_config(id)values(true)on conflict(id)do nothing;

create table public.legacy_find_rewards(
 id text primary key,
 name text not null,
 description text not null,
 reward_type text not null check(reward_type in('item','led')),
 product_id text references public.store_products(id),
 led_min integer,
 led_max integer,
 weight integer not null check(weight>0),
 rarity text not null check(rarity in('common','uncommon','rare')),
 icon text not null default '✦',
 destination text check(destination in('supplies','feed','tack','bank')),
 active boolean not null default true,
 sort_order integer not null default 0,
 check((reward_type='item'and product_id is not null and led_min is null and led_max is null)or(reward_type='led'and product_id is null and led_min>0 and led_max>=led_min))
);
insert into public.legacy_find_rewards(id,name,description,reward_type,product_id,led_min,led_max,weight,rarity,icon,destination,sort_order)values
 ('worn_glove','Worn Riding Glove','It has seen plenty of barn chores, but it still makes a charming keepsake.','item','find_worn_glove',null,null,24,'common','🧤','supplies',1),
 ('lucky_horseshoe','Lucky Horseshoe','A weathered horseshoe to add to your Stable collection.','item','find_lucky_horseshoe',null,null,18,'common','🧲','supplies',2),
 ('boot_polish','Tin of Boot Polish','A small show-day Stable supply.','item','find_boot_polish',null,null,15,'common','🥾','supplies',3),
 ('peppermint','Peppermint Treat','A sweet little find for your Stable collection.','item','find_peppermint',null,null,14,'common','🍬','supplies',4),
 ('vet_wrap','Roll of Vet Wrap','An unopened roll of useful Stable wrap.','item','find_vet_wrap',null,null,10,'uncommon','🩹','supplies',5),
 ('braided_crop','Braided Riding Crop','A polished riding crop discovered near the ring.','item','find_braided_crop',null,null,7,'rare','🏇','supplies',6),
 ('hay_sample','Grass Hay Sample','A complimentary unit of Grass Hay.','item','basic_hay',null,null,10,'uncommon','🌾','feed',7),
 ('leg_boots','Quality Leg Boots','A rare pair of protective boots for your Tack Room.','item','legs_quality_boots',null,null,2,'rare','🐴','tack',8),
 ('led_small','A Few LED','A few LE Dollars were tucked away here.','led',null,5,25,24,'common','LE','bank',9),
 ('led_medium','LED Pouch','A small pouch of LE Dollars!','led',null,50,100,7,'uncommon','LE','bank',10),
 ('led_rare','Lucky LED Find','An unusually valuable Legacy Find!','led',null,250,500,1,'rare','LE','bank',11)
on conflict(id)do update set name=excluded.name,description=excluded.description,reward_type=excluded.reward_type,product_id=excluded.product_id,led_min=excluded.led_min,led_max=excluded.led_max,weight=excluded.weight,rarity=excluded.rarity,icon=excluded.icon,destination=excluded.destination,active=true,sort_order=excluded.sort_order;

create table public.legacy_find_attempts(
 id uuid primary key default gen_random_uuid(),
 request_id uuid not null unique,
 stable_id uuid not null references public.stables(id)on delete cascade,
 location text not null,
 context_id uuid,
 status text not null check(status in('not_found','awarded','cooldown','daily_limit','disabled')),
 reward_id text references public.legacy_find_rewards(id),
 led_amount integer,
 item_id uuid references public.player_store_items(id),
 response jsonb not null,
 created_at timestamptz not null default now()
);
create index legacy_find_attempts_stable_time on public.legacy_find_attempts(stable_id,created_at desc);

alter table public.legacy_find_config enable row level security;
alter table public.legacy_find_rewards enable row level security;
alter table public.legacy_find_attempts enable row level security;
create policy "own Legacy Find history" on public.legacy_find_attempts for select to authenticated using(stable_id=auth.uid());
revoke all on public.legacy_find_config,public.legacy_find_rewards,public.legacy_find_attempts from anon,authenticated;
grant select on public.legacy_find_attempts to authenticated;

create or replace function public.try_legacy_find(p_location text,p_context_id uuid,p_request uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
 cfg legacy_find_config;reward legacy_find_rewards;prior jsonb;answer jsonb;item uuid;amount integer;today_start timestamptz;
 allowed constant text[]:=array['news','my_stable','horse','public_stable','public_player','store','marketplace','shows','training','professions','community','bank','sanctuary'];
begin
 if auth.uid()is null then raise exception 'Sign in required';end if;
 if p_request is null then raise exception 'Request ID required';end if;
 if not(p_location=any(allowed))then raise exception 'This location does not support Legacy Finds';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,4319));
 select a.response into prior from legacy_find_attempts a where a.request_id=p_request and a.stable_id=auth.uid();
 if prior is not null then return prior;end if;
 select*into cfg from legacy_find_config where id=true;
 if not found or not cfg.enabled then
  answer:=jsonb_build_object('status','disabled');
  insert into legacy_find_attempts(request_id,stable_id,location,context_id,status,response)values(p_request,auth.uid(),p_location,p_context_id,'disabled',answer);
  return answer;
 end if;
 if exists(select 1 from legacy_find_attempts a where a.stable_id=auth.uid()and a.created_at>now()-make_interval(mins=>cfg.cooldown_minutes)and a.status in('not_found','awarded'))then
  answer:=jsonb_build_object('status','cooldown');
  insert into legacy_find_attempts(request_id,stable_id,location,context_id,status,response)values(p_request,auth.uid(),p_location,p_context_id,'cooldown',answer);
  return answer;
 end if;
 today_start:=date_trunc('day',now()at time zone'America/New_York')at time zone'America/New_York';
 if(select count(*)from legacy_find_attempts a where a.stable_id=auth.uid()and a.status='awarded'and a.created_at>=today_start)>=cfg.daily_award_limit then
  answer:=jsonb_build_object('status','daily_limit');
  insert into legacy_find_attempts(request_id,stable_id,location,context_id,status,response)values(p_request,auth.uid(),p_location,p_context_id,'daily_limit',answer);
  return answer;
 end if;
 if random()>cfg.discovery_chance then
  answer:=jsonb_build_object('status','not_found');
  insert into legacy_find_attempts(request_id,stable_id,location,context_id,status,response)values(p_request,auth.uid(),p_location,p_context_id,'not_found',answer);
  return answer;
 end if;
 select r.*into reward from legacy_find_rewards r where r.active order by-ln(greatest(random(),.0000001))/r.weight limit 1;
 if reward.reward_type='led'then
  amount:=reward.led_min+floor(random()*(reward.led_max-reward.led_min+1))::integer;
  update stables set balance=balance+amount where id=auth.uid();
  insert into currency_ledger(stable_id,amount,reason)values(auth.uid(),amount,'Legacy Find — '||reward.name);
 else
  insert into player_store_items(stable_id,product_id,purchased_price)values(auth.uid(),reward.product_id,0)returning id into item;
 end if;
 answer:=jsonb_build_object('status','awarded','reward_id',reward.id,'reward_type',reward.reward_type,'name',reward.name,'description',reward.description,'rarity',reward.rarity,'icon',reward.icon,'destination',reward.destination,'led_amount',amount,'item_id',item,'location',p_location);
 insert into legacy_find_attempts(request_id,stable_id,location,context_id,status,reward_id,led_amount,item_id,response)values(p_request,auth.uid(),p_location,p_context_id,'awarded',reward.id,amount,item,answer);
 return answer;
end$$;

revoke all on function public.try_legacy_find(text,uuid,uuid)from public,anon;
grant execute on function public.try_legacy_find(text,uuid,uuid)to authenticated;
comment on function public.try_legacy_find(text,uuid,uuid)is'Server-authoritative, rate-limited and idempotent Legacy Find award path.';

create or replace function public.admin_legacy_find_workspace()returns jsonb language plpgsql stable security definer set search_path=public as $$
begin
 perform require_super_admin();
 return jsonb_build_object(
  'config',(select to_jsonb(c)from legacy_find_config c where c.id=true),
  'rewards',coalesce((select jsonb_agg(to_jsonb(r)order by r.sort_order,r.name)from legacy_find_rewards r),'[]'::jsonb),
  'awards_today',(select count(*)from legacy_find_attempts a where a.status='awarded'and a.created_at>=date_trunc('day',now()at time zone'America/New_York')at time zone'America/New_York'),
  'led_today',coalesce((select sum(a.led_amount)from legacy_find_attempts a where a.status='awarded'and a.led_amount is not null and a.created_at>=date_trunc('day',now()at time zone'America/New_York')at time zone'America/New_York'),0)
 );
end$$;

create or replace function public.admin_update_legacy_find_config(p_enabled boolean,p_chance numeric,p_cooldown integer,p_daily_limit integer)returns void language plpgsql security definer set search_path=public as $$
begin
 perform require_super_admin();
 if p_chance not between 0 and 1 then raise exception'Discovery chance must be between 0 and 1';end if;
 if p_cooldown not between 1 and 1440 then raise exception'Cooldown must be between 1 and 1,440 minutes';end if;
 if p_daily_limit not between 1 and 50 then raise exception'Daily limit must be between 1 and 50';end if;
 update legacy_find_config set enabled=p_enabled,discovery_chance=p_chance,cooldown_minutes=p_cooldown,daily_award_limit=p_daily_limit,updated_at=now(),updated_by=auth.uid()where id=true;
 insert into admin_audit_log(actor_id,action_type,system,details)values(auth.uid(),'legacy_finds.config_updated','legacy_finds',jsonb_build_object('enabled',p_enabled,'chance',p_chance,'cooldown_minutes',p_cooldown,'daily_limit',p_daily_limit));
end$$;

create or replace function public.admin_update_legacy_find_reward(p_reward text,p_active boolean,p_weight integer)returns void language plpgsql security definer set search_path=public as $$
begin
 perform require_super_admin();
 if p_weight not between 1 and 10000 then raise exception'Reward weight must be between 1 and 10,000';end if;
 update legacy_find_rewards set active=p_active,weight=p_weight where id=p_reward;
 if not found then raise exception'Legacy Find reward not found';end if;
 insert into admin_audit_log(actor_id,action_type,system,target_type,target_id,details)values(auth.uid(),'legacy_finds.reward_updated','legacy_finds','reward',p_reward,jsonb_build_object('active',p_active,'weight',p_weight));
end$$;

revoke all on function public.admin_legacy_find_workspace(),public.admin_update_legacy_find_config(boolean,numeric,integer,integer),public.admin_update_legacy_find_reward(text,boolean,integer)from public,anon;
grant execute on function public.admin_legacy_find_workspace(),public.admin_update_legacy_find_config(boolean,numeric,integer,integer),public.admin_update_legacy_find_reward(text,boolean,integer)to authenticated;

insert into public.handbook_articles(slug,category_id,title,summary,body,keywords,sort_order,featured,status,published_at)
values('legacy-finds','world-economy','Legacy Finds','Discover collectible items, useful Stable supplies, Feed, Tack, and small LED rewards while exploring Legacy Equine.',E'# Legacy Finds\n\nLegacy Finds are occasional surprise discoveries that may appear while you explore horse profiles, public Stables, Shows, the Marketplace, Community, Professions, the Store, and other player areas.\n\n## What can be found?\n\nFinds include collectible barn objects, treats and Stable supplies, occasional Feed or Tack, and small amounts of LED. Item finds are delivered automatically to the appropriate Supply, Feed, or Tack Room. LED is deposited into your personal account and recorded in your Bank ledger.\n\n## Fair play and limits\n\nEvery discovery is selected and awarded by the Legacy Equine server. Cooldowns and daily limits keep Finds fun and prevent refreshing or repeated visits from farming rewards. A reward is committed exactly once before the pop-up appears. Items and odds may change for events or game balancing.',array['legacy finds','random gifts','collectibles','items','led','rewards','supply room'],30,true,'published',now())
on conflict(slug)do update set title=excluded.title,summary=excluded.summary,body=excluded.body,keywords=excluded.keywords,status='published',updated_at=now();

insert into public.news_posts(title,summary,body,category,author_source,destination_url,pinned,status,publish_at,published_at,source_type,source_key)
values('Introducing Legacy Finds','Explore Legacy Equine for surprise collectibles, useful Stable items, and small LED discoveries.','Legacy Finds are now appearing throughout Legacy Equine. While visiting horses, public Stables, Shows, the Marketplace, Community, Professions, the Store and other game areas, you may discover a surprise item or a small amount of LED. Items are delivered automatically to the appropriate inventory room, and LED finds are deposited into your personal Bank balance with a ledger record. Server-controlled cooldowns and daily limits keep discoveries fair. Visit the Player Handbook to learn more.','updates','Legacy Equine','/how-to-play/legacy-finds',false,'published',now(),now(),'system','legacy-finds-launch-2026')
on conflict(source_type,source_key)do update set title=excluded.title,summary=excluded.summary,body=excluded.body,destination_url=excluded.destination_url,status='published',updated_at=now();
