alter table public.stables add column username text;
alter table public.stables add constraint stables_username_format check(username is null or username ~ '^[A-Za-z0-9_]{3,24}$');
create unique index stables_username_unique on public.stables(lower(username)) where username is not null;

create or replace function public.update_stable_profile(new_name text,new_username text,new_bio text)
returns public.stables language plpgsql security definer set search_path=public as $$
declare result stables;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if length(trim(new_name)) not between 2 and 60 then raise exception 'Stable name must be 2–60 characters'; end if;
  if trim(new_username) !~ '^[A-Za-z0-9_]{3,24}$' then raise exception 'Username must be 3–24 letters, numbers, or underscores'; end if;
  update stables set name=trim(new_name),username=trim(new_username),bio=left(trim(coalesce(new_bio,'')),500) where id=auth.uid() returning * into result;
  if not found then raise exception 'Stable not found'; end if; return result;
exception when unique_violation then raise exception 'That username is already taken';
end $$;

alter table public.competitions add column slug text;
create unique index competitions_slug_unique on public.competitions(slug) where slug is not null;
alter table public.competition_entries add column stable_id uuid references public.stables(id);
alter table public.competition_entries add column entered_at timestamptz not null default now();
create unique index competition_entries_horse_show_unique on public.competition_entries(competition_id,horse_id);
alter table public.competitions enable row level security;
alter table public.competition_entries enable row level security;
create policy "public shows" on public.competitions for select using(true);
create policy "public show results" on public.competition_entries for select using(true);

create or replace function public.ensure_open_shows()
returns void language plpgsql security definer set search_path=public as $$
begin
  if not exists(select 1 from competitions where discipline='Racing' and starts_at>now()) then insert into competitions(discipline,class_name,eligibility,starts_at,slug) values('Racing','Foundation Sprint','{"minimum_age":3}',now()+interval '2 days','racing-'||to_char(now(),'IYYY-IW')); end if;
  if not exists(select 1 from competitions where discipline='Dressage' and starts_at>now()) then insert into competitions(discipline,class_name,eligibility,starts_at,slug) values('Dressage','Legacy Intro','{"minimum_age":3}',now()+interval '3 days','dressage-'||to_char(now(),'IYYY-IW')); end if;
  if not exists(select 1 from competitions where discipline='Endurance' and starts_at>now()) then insert into competitions(discipline,class_name,eligibility,starts_at,slug) values('Endurance','Silver Trail','{"minimum_age":3}',now()+interval '4 days','endurance-'||to_char(now(),'IYYY-IW')); end if;
exception when unique_violation then null;
end $$;

create or replace function public.get_open_shows()
returns table(id uuid,discipline text,class_name text,starts_at timestamptz,entry_count bigint)
language plpgsql security definer set search_path=public as $$
begin perform ensure_open_shows(); return query select c.id,c.discipline,c.class_name,c.starts_at,count(e.id) from competitions c left join competition_entries e on e.competition_id=c.id where c.starts_at>now() group by c.id order by c.starts_at; end $$;

create or replace function public.enter_show(target_competition uuid,target_horse uuid)
returns public.competition_entries language plpgsql security definer set search_path=public as $$
declare h horses; c competitions; result competition_entries; score integer;
begin
  select * into h from horses where id=target_horse for update;
  if not found or h.owner_id<>auth.uid() then raise exception 'Choose a horse owned by your stable'; end if;
  select * into c from competitions where id=target_competition and starts_at>now(); if not found then raise exception 'That show is no longer open'; end if;
  score:=case c.discipline when 'Racing' then (h.stats->>'Speed')::int+(h.stats->>'Endurance')::int when 'Dressage' then (h.stats->>'Agility')::int+(h.stats->>'Temperament')::int when 'Endurance' then (h.stats->>'Endurance')::int+(h.stats->>'Strength')::int else 0 end+floor(random()*11)::int;
  insert into competition_entries(competition_id,horse_id,stable_id,result,points_awarded) values(c.id,h.id,auth.uid(),jsonb_build_object('score',score,'status','entered'),score) returning * into result;
  return result;
exception when unique_violation then raise exception 'This horse is already entered in that show';
end $$;

create type public.marketplace_status as enum('active','sold','cancelled');
create table public.marketplace_listings(
  id uuid primary key default gen_random_uuid(),horse_id uuid not null references public.horses(id) on delete restrict,seller_id uuid not null references public.stables(id),buyer_id uuid references public.stables(id),price integer not null check(price between 1 and 1000000),status marketplace_status not null default 'active',created_at timestamptz not null default now(),closed_at timestamptz
);
create unique index marketplace_one_active_listing on public.marketplace_listings(horse_id) where status='active';
alter table public.marketplace_listings enable row level security;
create policy "public active marketplace" on public.marketplace_listings for select using(status='active' or auth.uid()=seller_id or auth.uid()=buyer_id);

create or replace function public.list_horse_for_sale(target_horse uuid,asking_price integer)
returns public.marketplace_listings language plpgsql security definer set search_path=public as $$
declare h horses; result marketplace_listings;
begin
  if asking_price not between 1 and 1000000 then raise exception 'Price must be between 1 and 1,000,000 LE Dollars'; end if;
  select * into h from horses where id=target_horse for update; if not found or h.owner_id<>auth.uid() then raise exception 'Horse not found or not owned'; end if;
  insert into marketplace_listings(horse_id,seller_id,price) values(h.id,auth.uid(),asking_price) returning * into result; return result;
exception when unique_violation then raise exception 'That horse is already listed';
end $$;

create or replace function public.cancel_horse_listing(target_listing uuid)
returns void language plpgsql security definer set search_path=public as $$
begin update marketplace_listings set status='cancelled',closed_at=now() where id=target_listing and seller_id=auth.uid() and status='active'; if not found then raise exception 'Active listing not found'; end if; end $$;

create or replace function public.buy_marketplace_horse(target_listing uuid)
returns public.horses language plpgsql security definer set search_path=public as $$
declare item marketplace_listings; buyer stables; seller stables; h horses;
begin
  select * into item from marketplace_listings where id=target_listing for update; if not found or item.status<>'active' then raise exception 'That horse is no longer available'; end if;
  if item.seller_id=auth.uid() then raise exception 'You already own this horse'; end if;
  select * into buyer from stables where id=auth.uid() for update; select * into seller from stables where id=item.seller_id for update;
  if buyer.balance<item.price then raise exception 'Insufficient funds'; end if;
  update horses set owner_id=auth.uid() where id=item.horse_id and owner_id=item.seller_id returning * into h; if not found then raise exception 'That horse is no longer available'; end if;
  update stables set balance=balance-item.price where id=buyer.id; update stables set balance=balance+item.price where id=seller.id;
  update marketplace_listings set status='sold',buyer_id=buyer.id,closed_at=now() where id=item.id;
  insert into currency_ledger(stable_id,amount,reason,horse_id) values(buyer.id,-item.price,'Marketplace purchase: '||h.name,h.id),(seller.id,item.price,'Marketplace sale: '||h.name,h.id); return h;
end $$;

create or replace function public.get_marketplace()
returns table(listing_id uuid,horse_id uuid,name text,breed text,sex horse_sex,color text,birth_date timestamptz,stats jsonb,image_url text,price integer,seller_name text,seller_username text,created_at timestamptz)
language sql security definer set search_path=public as $$ select l.id,h.id,h.name,h.breed,h.sex,h.color,h.birth_date,h.stats,h.image_url,l.price,s.name,s.username,l.created_at from marketplace_listings l join horses h on h.id=l.horse_id join stables s on s.id=l.seller_id where l.status='active' order by l.created_at desc $$;

create table public.forum_posts(
  id uuid primary key default gen_random_uuid(),stable_id uuid not null references public.stables(id),parent_id uuid references public.forum_posts(id) on delete cascade,body text not null check(length(body) between 1 and 1000),created_at timestamptz not null default now()
);
alter table public.forum_posts enable row level security;
create policy "public forum reading" on public.forum_posts for select using(true);
create or replace function public.create_forum_post(post_body text,reply_to uuid default null)
returns public.forum_posts language plpgsql security definer set search_path=public as $$
declare s stables; result forum_posts;
begin select * into s from stables where id=auth.uid(); if s.username is null then raise exception 'Create a username in Settings before posting'; end if; if length(trim(post_body)) not between 1 and 1000 then raise exception 'Post must be 1–1,000 characters'; end if; insert into forum_posts(stable_id,parent_id,body) values(auth.uid(),reply_to,trim(post_body)) returning * into result; return result; end $$;
create or replace function public.get_forum_posts()
returns table(id uuid,parent_id uuid,body text,created_at timestamptz,stable_name text,username text,account_number bigint)
language sql security definer set search_path=public as $$ select p.id,p.parent_id,p.body,p.created_at,s.name,s.username,s.account_number from forum_posts p join stables s on s.id=p.stable_id order by p.created_at desc limit 100 $$;

revoke all on function public.update_stable_profile(text,text,text),public.ensure_open_shows(),public.get_open_shows(),public.enter_show(uuid,uuid),public.list_horse_for_sale(uuid,integer),public.cancel_horse_listing(uuid),public.buy_marketplace_horse(uuid),public.get_marketplace(),public.create_forum_post(text,uuid),public.get_forum_posts() from public;
grant execute on function public.update_stable_profile(text,text,text),public.get_open_shows(),public.enter_show(uuid,uuid),public.list_horse_for_sale(uuid,integer),public.cancel_horse_listing(uuid),public.buy_marketplace_horse(uuid),public.get_marketplace(),public.create_forum_post(text,uuid),public.get_forum_posts() to authenticated;
