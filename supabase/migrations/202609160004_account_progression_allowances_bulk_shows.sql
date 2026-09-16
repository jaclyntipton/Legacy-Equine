-- Account progression, Friday-week allowances, hosting quotas, and bulk show tools.
-- Horse Career Points remain completely separate in horses.career_points.

alter table public.stables add column if not exists account_xp bigint not null default 0 check(account_xp>=0);
alter table public.stables add column if not exists phone_e164 text;
alter table public.stables add column if not exists phone_verified_at timestamptz;
alter table public.stables add column if not exists account_status text not null default 'active'
  check(account_status in ('unverified','active','suspended','archived','cleanup_eligible'));
create unique index if not exists one_verified_phone_per_account on public.stables(phone_e164) where phone_verified_at is not null;

create table if not exists public.account_level_config(
 level integer primary key check(level between 1 and 50), cumulative_xp bigint not null unique,
 weekly_allowance integer not null, weekly_show_limit integer not null,
 bulk_show_creation boolean not null default false, custom_stable_layout boolean not null default false,
 advanced_bulk_entry boolean not null default false, legacy_status boolean not null default false
);
insert into public.account_level_config(level,cumulative_xp,weekly_allowance,weekly_show_limit,bulk_show_creation,custom_stable_layout,advanced_bulk_entry,legacy_status) values
 (1,0,500,5,false,false,false,false),(2,25,500,5,false,false,false,false),(3,60,500,5,false,false,false,false),(4,105,500,5,false,false,false,false),
 (5,160,600,5,false,false,false,false),(6,225,600,5,false,false,false,false),(7,300,600,5,false,false,false,false),(8,385,600,5,false,false,false,false),(9,480,600,5,false,false,false,false),
 (10,585,700,5,false,false,false,false),(11,700,700,5,false,false,false,false),(12,825,700,5,false,false,false,false),(13,960,700,5,false,false,false,false),(14,1105,700,5,false,false,false,false),
 (15,1260,800,10,true,false,false,false),(16,1430,800,10,true,false,false,false),(17,1615,800,10,true,false,false,false),(18,1815,800,10,true,false,false,false),(19,2030,800,10,true,false,false,false),
 (20,2260,900,10,true,true,false,false),(21,2505,900,10,true,true,false,false),(22,2765,900,10,true,true,false,false),(23,3040,900,10,true,true,false,false),(24,3330,900,10,true,true,false,false),
 (25,3635,1000,10,true,true,false,false),(26,3955,1000,10,true,true,false,false),(27,4290,1000,10,true,true,false,false),(28,4640,1000,10,true,true,false,false),(29,5005,1000,10,true,true,false,false),
 (30,5385,1100,15,true,true,true,false),(31,5785,1100,15,true,true,true,false),(32,6205,1100,15,true,true,true,false),(33,6645,1100,15,true,true,true,false),(34,7105,1100,15,true,true,true,false),
 (35,7585,1200,15,true,true,true,false),(36,8090,1200,15,true,true,true,false),(37,8620,1200,15,true,true,true,false),(38,9175,1200,15,true,true,true,false),(39,9755,1200,15,true,true,true,false),
 (40,10360,1300,15,true,true,true,false),(41,10995,1300,15,true,true,true,false),(42,11660,1300,15,true,true,true,false),(43,12355,1300,15,true,true,true,false),(44,13080,1300,15,true,true,true,false),
 (45,13835,1400,20,true,true,true,false),(46,14625,1400,20,true,true,true,false),(47,15450,1400,20,true,true,true,false),(48,16310,1400,20,true,true,true,false),(49,17205,1400,20,true,true,true,false),
 (50,18135,1500,25,true,true,true,true)
on conflict(level) do update set cumulative_xp=excluded.cumulative_xp,weekly_allowance=excluded.weekly_allowance,weekly_show_limit=excluded.weekly_show_limit,
 bulk_show_creation=excluded.bulk_show_creation,custom_stable_layout=excluded.custom_stable_layout,advanced_bulk_entry=excluded.advanced_bulk_entry,legacy_status=excluded.legacy_status;

create table if not exists public.progression_config(
 id boolean primary key default true check(id), xp_entry integer not null default 1, xp_first integer not null default 10,
 xp_second integer not null default 6, xp_third integer not null default 3, xp_host_complete integer not null default 5,
 xp_host_5_accounts integer not null default 3, xp_host_10_accounts integer not null default 5,
 xp_host_20_accounts integer not null default 10, subscriber_allowance_bonus integer not null default 100,
 subscriber_preserved_weeks integer not null default 6, full_economy_level integer not null default 5,
 bulk_create_level integer not null default 15, custom_layout_level integer not null default 20,
 bulk_entry_level integer not null default 30, unverified_cleanup_days integer not null default 7,
 verified_unused_cleanup_days integer not null default 90, minimum_legitimate_show_entries integer not null default 2
);
insert into public.progression_config(id) values(true) on conflict(id) do nothing;

create table if not exists public.account_xp_events(
 id uuid primary key default gen_random_uuid(),stable_id uuid not null references public.stables(id),amount integer not null check(amount>0),
 source_type text not null,source_id uuid,event_key text not null,description text not null,created_at timestamptz not null default now(),
 unique(stable_id,source_type,source_id,event_key)
);
create table if not exists public.stable_subscriptions(
 id uuid primary key default gen_random_uuid(),stable_id uuid not null references public.stables(id),starts_at timestamptz not null,
 ends_at timestamptz,status text not null default 'active' check(status in('active','expired','cancelled')),provider_reference text unique,created_at timestamptz not null default now()
);
create index if not exists stable_subscription_window on public.stable_subscriptions(stable_id,starts_at,ends_at);

create table if not exists public.weekly_allowance_entitlements(
 id uuid primary key default gen_random_uuid(),stable_id uuid not null references public.stables(id),week_start date not null,
 level_snapshot integer not null,base_amount integer not null,subscriber_bonus integer not null default 0,total_amount integer generated always as(base_amount+subscriber_bonus) stored,
 protected_by_subscription boolean not null default false,status text not null default 'available' check(status in('available','collected','forfeited')),
 available_at timestamptz not null,expires_at timestamptz,collected_at timestamptz,created_at timestamptz not null default now(),unique(stable_id,week_start)
);
create table if not exists public.show_templates(
 id uuid primary key default gen_random_uuid(),stable_id uuid not null references public.stables(id),name text not null,
 discipline_ids text[] not null default '{}',tier_ids text[] not null default '{}',entry_fee integer not null default 0,max_entries integer,
 description text not null default '',created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(stable_id,name)
);
create table if not exists public.stable_layouts(
 id uuid primary key default gen_random_uuid(),stable_id uuid not null references public.stables(id),name text not null,
 layout jsonb not null default '{"version":1,"blocks":[]}',active boolean not null default false,created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
alter table public.player_show_entries add column if not exists is_admin_qa boolean not null default false;
alter table public.player_show_entries add column if not exists xp_eligible boolean not null default true;
alter table public.player_show_entries add column if not exists career_points_eligible boolean not null default true;
alter table public.player_show_entries add column if not exists payout_eligible boolean not null default true;

alter table public.account_level_config enable row level security;alter table public.account_xp_events enable row level security;
alter table public.stable_subscriptions enable row level security;alter table public.weekly_allowance_entitlements enable row level security;
alter table public.show_templates enable row level security;alter table public.stable_layouts enable row level security;
drop policy if exists "level config readable" on public.account_level_config;create policy "level config readable" on public.account_level_config for select using(true);
drop policy if exists "own xp readable" on public.account_xp_events;create policy "own xp readable" on public.account_xp_events for select using(stable_id=auth.uid());
drop policy if exists "own subscriptions readable" on public.stable_subscriptions;create policy "own subscriptions readable" on public.stable_subscriptions for select using(stable_id=auth.uid());
drop policy if exists "own allowances readable" on public.weekly_allowance_entitlements;create policy "own allowances readable" on public.weekly_allowance_entitlements for select using(stable_id=auth.uid());
drop policy if exists "own templates" on public.show_templates;create policy "own templates" on public.show_templates for select using(stable_id=auth.uid());
drop policy if exists "public active layouts" on public.stable_layouts;create policy "public active layouts" on public.stable_layouts for select using(active or stable_id=auth.uid());

create or replace function public.account_level_for_xp(p_xp bigint) returns integer language sql immutable as $$
 select coalesce(max(level),1) from public.account_level_config where cumulative_xp<=greatest(p_xp,0)
$$;
create or replace function public.le_week_start(p_at timestamptz default now()) returns date language sql stable as $$
 select ((p_at at time zone 'America/New_York')::date - ((extract(dow from p_at at time zone 'America/New_York')::integer+2)%7))::date
$$;
create or replace function public.is_active_subscriber(p_stable uuid,p_at timestamptz default now()) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from stable_subscriptions ss where ss.stable_id=p_stable and ss.status='active' and ss.starts_at<=p_at and (ss.ends_at is null or ss.ends_at>p_at))
$$;
create or replace function public.is_owner_account(p_stable uuid) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from stables s where s.id=p_stable and (s.account_number=1 or s.is_admin))
$$;

create or replace function public.award_account_xp(p_stable uuid,p_amount integer,p_source_type text,p_source_id uuid,p_event_key text,p_description text)
returns boolean language plpgsql security definer set search_path=public as $$declare inserted integer;begin
 if p_amount<=0 then return false;end if;
 insert into account_xp_events(stable_id,amount,source_type,source_id,event_key,description)
 values(p_stable,p_amount,p_source_type,p_source_id,p_event_key,left(p_description,200)) on conflict do nothing;
 get diagnostics inserted=row_count;if inserted=1 then update stables set account_xp=account_xp+p_amount where id=p_stable;return true;end if;return false;
end$$;

create or replace function public.get_account_progression() returns jsonb language plpgsql stable security definer set search_path=public as $$
declare s stables;cfg account_level_config;nxt account_level_config;week_start date;used integer;subscriber boolean;begin
 select * into s from stables where id=auth.uid();if not found then return null;end if;
 select * into cfg from account_level_config where level=account_level_for_xp(s.account_xp);
 select * into nxt from account_level_config where level=least(cfg.level+1,50);
 week_start:=le_week_start();select count(*) into used from player_shows ps where ps.creator_id=s.id and ps.created_at>=week_start::timestamp at time zone 'America/New_York' and ps.created_at<(week_start+7)::timestamp at time zone 'America/New_York' and ps.status<>'cancelled';
 subscriber:=is_active_subscriber(s.id);
 return jsonb_build_object('account_xp',s.account_xp,'level',cfg.level,'legacy_stable',cfg.legacy_status,'next_level_xp',case when cfg.level=50 then null else nxt.cumulative_xp end,
 'weekly_allowance',cfg.weekly_allowance,'shows_hosted_this_week',used,'weekly_show_limit',cfg.weekly_show_limit,
 'bulk_show_creation',is_owner_account(s.id) or cfg.bulk_show_creation or subscriber,'custom_stable_layout',is_owner_account(s.id) or cfg.custom_stable_layout,
 'advanced_bulk_entry',is_owner_account(s.id) or cfg.advanced_bulk_entry or subscriber,'full_economy',is_owner_account(s.id) or cfg.level>=(select full_economy_level from progression_config where id=true),
 'subscriber',subscriber,'owner',is_owner_account(s.id),'week_start',week_start);
end$$;

create or replace function public.ensure_weekly_allowances(p_stable uuid default auth.uid()) returns void language plpgsql security definer set search_path=public as $$
declare s stables;wk date;lvl account_level_config;sub boolean;bonus integer;protected boolean;i integer;cfg progression_config;begin
 if p_stable<>auth.uid() and not is_owner_account(auth.uid()) then raise exception 'Not authorized';end if;
 select * into s from stables where id=p_stable;select * into cfg from progression_config where id=true;
 for i in 0..greatest(cfg.subscriber_preserved_weeks-1,0) loop
  wk:=le_week_start()-i*7;sub:=exists(select 1 from stable_subscriptions ss where ss.stable_id=s.id and ss.status in('active','expired','cancelled') and ss.starts_at<((wk+7)::timestamp at time zone 'America/New_York') and (ss.ends_at is null or ss.ends_at>(wk::timestamp at time zone 'America/New_York')));
  if i=0 or sub then
   select * into lvl from account_level_config where level=account_level_for_xp(s.account_xp);bonus:=case when sub then cfg.subscriber_allowance_bonus else 0 end;protected:=sub;
   insert into weekly_allowance_entitlements(stable_id,week_start,level_snapshot,base_amount,subscriber_bonus,protected_by_subscription,available_at,expires_at)
   values(s.id,wk,lvl.level,lvl.weekly_allowance,bonus,protected,wk::timestamp at time zone 'America/New_York',case when protected then null else (wk+7)::timestamp at time zone 'America/New_York' end) on conflict(stable_id,week_start) do nothing;
  end if;
 end loop;
 update weekly_allowance_entitlements set status='forfeited' where stable_id=s.id and status='available' and not protected_by_subscription and expires_at<=now();
end$$;
create or replace function public.get_weekly_allowances() returns table(id uuid,week_start date,level_snapshot integer,base_amount integer,subscriber_bonus integer,total_amount integer,protected boolean,status text,expires_at timestamptz,collected_at timestamptz)
language plpgsql security definer set search_path=public as $$begin perform ensure_weekly_allowances();return query select w.id,w.week_start,w.level_snapshot,w.base_amount,w.subscriber_bonus,w.total_amount,w.protected_by_subscription,w.status,w.expires_at,w.collected_at from weekly_allowance_entitlements w where w.stable_id=auth.uid() order by w.week_start desc limit 12;end$$;
create or replace function public.collect_weekly_allowances(p_ids uuid[] default null) returns jsonb language plpgsql security definer set search_path=public as $$
declare row weekly_allowance_entitlements;total integer:=0;counted integer:=0;new_balance integer;begin
 perform ensure_weekly_allowances();
 for row in select * from weekly_allowance_entitlements w where w.stable_id=auth.uid() and w.status='available' and (w.expires_at is null or w.expires_at>now()) and (p_ids is null or w.id=any(p_ids)) order by w.week_start for update loop
  update weekly_allowance_entitlements w set status='collected',collected_at=now() where w.id=row.id;
  insert into currency_ledger(stable_id,amount,reason) values(auth.uid(),row.total_amount,'Weekly Stable Allowance — week of '||row.week_start);
  total:=total+row.total_amount;counted:=counted+1;
 end loop;
 if counted=0 then raise exception 'No available weekly allowance to collect';end if;
 update stables set balance=balance+total where id=auth.uid() returning balance into new_balance;
 return jsonb_build_object('collected',counted,'amount',total,'balance',new_balance);
end$$;

create or replace function public.record_show_progression() returns trigger language plpgsql security definer set search_path=public as $$declare cfg progression_config;eligible boolean;begin
 select coalesce(e.xp_eligible,true) and not coalesce(e.is_admin_qa,false) into eligible from player_show_entries e where e.id=new.entry_id;
 if not eligible then return new;end if;select * into cfg from progression_config where id=true;
 perform award_account_xp(new.owner_id,cfg.xp_entry,'show_result',new.id,'entry','Legitimate show entry');
 if new.placement=1 then perform award_account_xp(new.owner_id,cfg.xp_first,'show_result',new.id,'place_1','First-place finish');
 elsif new.placement=2 then perform award_account_xp(new.owner_id,cfg.xp_second,'show_result',new.id,'place_2','Second-place finish');
 elsif new.placement=3 then perform award_account_xp(new.owner_id,cfg.xp_third,'show_result',new.id,'place_3','Third-place finish');end if;return new;
end$$;
drop trigger if exists account_xp_from_show_result on public.player_show_results;create trigger account_xp_from_show_result after insert on public.player_show_results for each row execute function public.record_show_progression();
create or replace function public.record_host_progression() returns trigger language plpgsql security definer set search_path=public as $$declare cfg progression_config;accounts integer;entries integer;begin
 if old.status='complete' or new.status<>'complete' then return new;end if;select * into cfg from progression_config where id=true;
 select count(*),count(distinct owner_id) into entries,accounts from player_show_entries e where e.show_id=new.id and e.xp_eligible and not e.is_admin_qa;
 if entries<cfg.minimum_legitimate_show_entries then return new;end if;
 perform award_account_xp(new.creator_id,cfg.xp_host_complete,'show_host',new.id,'complete','Hosted a completed legitimate show');
 if accounts>=5 then perform award_account_xp(new.creator_id,cfg.xp_host_5_accounts,'show_host',new.id,'accounts_5','Hosted 5 unique stables');end if;
 if accounts>=10 then perform award_account_xp(new.creator_id,cfg.xp_host_10_accounts,'show_host',new.id,'accounts_10','Hosted 10 unique stables');end if;
 if accounts>=20 then perform award_account_xp(new.creator_id,cfg.xp_host_20_accounts,'show_host',new.id,'accounts_20','Hosted 20 unique stables');end if;return new;
end$$;
drop trigger if exists account_xp_from_hosting on public.player_shows;create trigger account_xp_from_hosting after update of status on public.player_shows for each row execute function public.record_host_progression();

create or replace function public.assert_show_host_quota(p_stable uuid,p_additional integer,p_run_dates date[]) returns void language plpgsql security definer set search_path=public as $$
declare lvl account_level_config;wk date;requested integer;used integer;begin
 if is_owner_account(p_stable) then return;end if;select c.* into lvl from stables s join account_level_config c on c.level=account_level_for_xp(s.account_xp) where s.id=p_stable;
 for wk in select distinct le_week_start(d::timestamp at time zone 'America/New_York') from unnest(p_run_dates) d loop
  select count(*) into requested from unnest(p_run_dates) d where le_week_start(d::timestamp at time zone 'America/New_York')=wk;
  select count(*) into used from player_shows ps where ps.creator_id=p_stable and ps.status<>'cancelled' and le_week_start(ps.run_at)=wk;
  if used+requested>lvl.weekly_show_limit then raise exception 'Weekly show-hosting limit exceeded (% of % already scheduled)',used,lvl.weekly_show_limit;end if;
 end loop;
end$$;

create or replace function public.create_player_show(show_name text,target_discipline text,target_tier text,target_run_date date,new_entry_fee bigint default 0,new_max_entries integer default null,new_description text default '') returns public.player_shows language plpgsql security definer set search_path=public as $$
declare result player_shows;s stables;cfg economy_config;scheduled timestamptz;begin
 select * into s from stables where id=auth.uid() for update;select * into cfg from economy_config where id=true;
 if length(trim(show_name)) not between 3 and 80 then raise exception 'Show name must be 3–80 characters';end if;
 if not exists(select 1 from show_disciplines where id=target_discipline and active) or not exists(select 1 from show_tiers where id=target_tier and active) then raise exception 'Choose an active discipline and tier';end if;
 if new_entry_fee<0 or new_entry_fee>cfg.show_entry_fee_max then raise exception 'Entry fee is outside the permitted range';end if;if new_max_entries is not null and new_max_entries not between 2 and 1000 then raise exception 'Maximum entries must be 2–1,000';end if;
 scheduled:=target_run_date::timestamp at time zone 'America/New_York';if scheduled<=now() then raise exception 'Run date must be in the future';end if;perform assert_show_host_quota(s.id,1,array[target_run_date]);
 if s.balance<cfg.show_hosting_fee then raise exception 'Insufficient LED for hosting fee';end if;if cfg.show_hosting_fee>0 then update stables set balance=balance-cfg.show_hosting_fee where id=s.id;insert into currency_ledger(stable_id,amount,reason) values(s.id,-cfg.show_hosting_fee,'Show hosting fee');end if;
 insert into player_shows(creator_id,name,discipline_id,tier_id,run_date,run_at,entry_fee,max_entries,description,maximum_per_owner) values(s.id,trim(show_name),target_discipline,target_tier,target_run_date,scheduled,new_entry_fee,new_max_entries,left(coalesce(new_description,''),1000),1000) returning * into result;return result;
end$$;

create or replace function public.bulk_create_player_shows(p_name_prefix text,p_discipline_ids text[],p_tier_ids text[],p_run_dates date[],p_entry_fee integer default 0,p_max_entries integer default null,p_description text default '') returns jsonb language plpgsql security definer set search_path=public as $$
declare s stables;progress jsonb;d text;t text;rd date;created uuid[]:='{}';one player_shows;total integer;cfg economy_config;begin
 select * into s from stables where id=auth.uid() for update;progress:=get_account_progression();if not (progress->>'bulk_show_creation')::boolean then raise exception 'Bulk show creation unlocks at Account Level 15';end if;
 total:=cardinality(p_discipline_ids)*cardinality(p_tier_ids)*cardinality(p_run_dates);if total<1 then raise exception 'Choose at least one discipline, tier, and date';end if;if total>100 and not is_owner_account(s.id) then raise exception 'A bulk set may contain at most 100 shows';end if;
 perform assert_show_host_quota(s.id,total,(select array_agg(d) from unnest(p_run_dates) d cross join generate_series(1,cardinality(p_discipline_ids)*cardinality(p_tier_ids))));
 select * into cfg from economy_config where id=true;if s.balance<cfg.show_hosting_fee*total then raise exception 'Insufficient LED for all hosting fees';end if;
 foreach rd in array p_run_dates loop foreach d in array p_discipline_ids loop foreach t in array p_tier_ids loop
  if not exists(select 1 from show_disciplines where id=d and active) or not exists(select 1 from show_tiers where id=t and active) then raise exception 'A selected discipline or tier is unavailable';end if;
 end loop;end loop;end loop;
 if cfg.show_hosting_fee*total>0 then update stables set balance=balance-cfg.show_hosting_fee*total where id=s.id;insert into currency_ledger(stable_id,amount,reason) values(s.id,-cfg.show_hosting_fee*total,'Bulk show hosting fees');end if;
 foreach rd in array p_run_dates loop foreach d in array p_discipline_ids loop foreach t in array p_tier_ids loop
  insert into player_shows(creator_id,name,discipline_id,tier_id,run_date,run_at,entry_fee,max_entries,description,maximum_per_owner) values(s.id,left(trim(p_name_prefix)||' — '||(select name from show_disciplines where id=d)||' '||(select name from show_tiers where id=t),80),d,t,rd,rd::timestamp at time zone 'America/New_York',p_entry_fee,p_max_entries,left(coalesce(p_description,''),1000),1000) returning * into one;created:=array_append(created,one.id);
 end loop;end loop;end loop;return jsonb_build_object('shows_created',total,'show_ids',created,'hosting_fees',cfg.show_hosting_fee*total);
end$$;

create or replace function public.save_show_template(p_name text,p_discipline_ids text[],p_tier_ids text[],p_entry_fee integer,p_max_entries integer,p_description text) returns uuid language plpgsql security definer set search_path=public as $$declare result uuid;begin
 insert into show_templates(stable_id,name,discipline_ids,tier_ids,entry_fee,max_entries,description) values(auth.uid(),trim(p_name),p_discipline_ids,p_tier_ids,p_entry_fee,p_max_entries,left(coalesce(p_description,''),1000)) on conflict(stable_id,name) do update set discipline_ids=excluded.discipline_ids,tier_ids=excluded.tier_ids,entry_fee=excluded.entry_fee,max_entries=excluded.max_entries,description=excluded.description,updated_at=now() returning id into result;return result;end$$;

create or replace function public.preview_bulk_show_entries(p_pairs jsonb) returns jsonb language plpgsql stable security definer set search_path=public as $$declare progress jsonb;item jsonb;sh player_shows;h horses;eligible jsonb:='[]';skipped jsonb:='[]';fee bigint:=0;begin
 progress:=get_account_progression();if not (progress->>'advanced_bulk_entry')::boolean then raise exception 'Advanced bulk entry unlocks at Account Level 30';end if;
 for item in select * from jsonb_array_elements(coalesce(p_pairs,'[]')) loop
  select * into sh from player_shows where id=(item->>'show_id')::uuid;select * into h from horses where id=(item->>'horse_id')::uuid and owner_id=auth.uid();
  if sh.id is null or h.id is null then skipped:=skipped||jsonb_build_array(item||jsonb_build_object('reason','Horse or show unavailable'));
  elsif sh.status<>'open' or sh.run_at<=now() then skipped:=skipped||jsonb_build_array(item||jsonb_build_object('reason','Show closed'));
  elsif exists(select 1 from player_show_entries e where e.show_id=sh.id and e.horse_id=h.id) then skipped:=skipped||jsonb_build_array(item||jsonb_build_object('reason','Already entered'));
  elsif get_horse_competition_tier(h.career_points)<>sh.tier_id then skipped:=skipped||jsonb_build_array(item||jsonb_build_object('reason','Incorrect Career Point tier'));
  else eligible:=eligible||jsonb_build_array(item||jsonb_build_object('horse_name',h.name,'show_name',sh.name,'fee',sh.entry_fee));fee:=fee+sh.entry_fee;end if;
 end loop;return jsonb_build_object('eligible',eligible,'skipped',skipped,'total_fee',fee,'balance',(select balance from stables where id=auth.uid()));end$$;
create or replace function public.execute_bulk_show_entries(p_pairs jsonb) returns jsonb language plpgsql security definer set search_path=public as $$declare preview jsonb;item jsonb;created integer:=0;seen text[]:='{}';key text;begin
 preview:=preview_bulk_show_entries(p_pairs);if jsonb_array_length(preview->'eligible')=0 then raise exception 'No eligible show entries selected';end if;
 for item in select * from jsonb_array_elements(preview->'eligible') loop key:=(item->>'show_id')||':'||(item->>'horse_id');if key=any(seen) then raise exception 'Duplicate horse/show pair selected';end if;seen:=array_append(seen,key);perform enter_player_show((item->>'show_id')::uuid,(item->>'horse_id')::uuid);created:=created+1;end loop;
 return preview||jsonb_build_object('entries_created',created);
end$$;

revoke all on function public.award_account_xp(uuid,integer,text,uuid,text,text),public.assert_show_host_quota(uuid,integer,date[]) from public;
grant execute on function public.get_account_progression(),public.get_weekly_allowances(),public.collect_weekly_allowances(uuid[]),public.ensure_weekly_allowances(uuid),public.bulk_create_player_shows(text,text[],text[],date[],integer,integer,text),public.save_show_template(text,text[],text[],integer,integer,text),public.preview_bulk_show_entries(jsonb),public.execute_bulk_show_entries(jsonb) to authenticated;
grant execute on function public.award_account_xp(uuid,integer,text,uuid,text,text) to service_role;
