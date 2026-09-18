-- Owner-controlled show-calendar seeding over the existing player_shows engine.
alter table public.player_shows add column if not exists source text not null default 'player' check(source in('player','admin','auto_host'));
alter table public.player_shows add column if not exists auto_host_run_id uuid;

create table public.show_auto_host_config(
 id boolean primary key default true check(id),enabled boolean not null default false,
 selection_mode text not null default 'full' check(selection_mode in('full','custom')),
 quantity_mode text not null default 'maintain' check(quantity_mode in('maintain','create_new')),
 daily_enabled boolean not null default true,default_quantity integer not null default 10 check(default_quantity between 0 and 100),
 run_delay_days integer not null default 1 check(run_delay_days between 1 and 30),
 use_show_defaults boolean not null default true,timezone text not null default 'America/New_York',creation_time time not null default '00:05',
 updated_by uuid references public.stables(id),updated_at timestamptz not null default now()
);
insert into public.show_auto_host_config(id)values(true);
create table public.show_auto_host_combinations(
 discipline_id text not null references public.show_disciplines(id),tier_id text not null references public.show_tiers(id),
 enabled boolean not null default true,quantity integer not null default 10 check(quantity between 0 and 100),entry_fee bigint not null default 0 check(entry_fee>=0),
 base_purse bigint not null default 0 check(base_purse>=0),updated_at timestamptz not null default now(),primary key(discipline_id,tier_id)
);
insert into public.show_auto_host_combinations(discipline_id,tier_id)
select d.id,t.id from show_disciplines d cross join show_tiers t where d.active and t.active on conflict do nothing;
create table public.show_auto_host_name_pools(
 discipline_id text primary key references public.show_disciplines(id),names text[] not null check(cardinality(names)>0),updated_at timestamptz not null default now()
);
insert into public.show_auto_host_name_pools(discipline_id,names)
select id,array['Legacy '||name||' Classic','Midnight '||name||' Series','LE '||name||' Showcase']from show_disciplines on conflict do nothing;
create table public.show_auto_host_runs(
 id uuid primary key default gen_random_uuid(),cycle_key text not null unique,trigger text not null check(trigger in('scheduled','manual')),
 actor_id uuid references public.stables(id),scheduled_for timestamptz not null,shows_evaluated integer not null default 0,shows_created integer not null default 0,
 shows_skipped integer not null default 0,error_count integer not null default 0,result jsonb not null default '{}',created_at timestamptz not null default now(),completed_at timestamptz
);
alter table public.player_shows add constraint player_shows_auto_host_run_fk foreign key(auto_host_run_id)references public.show_auto_host_runs(id);
create index player_shows_auto_host_availability on public.player_shows(discipline_id,tier_id,run_at)where status='open';

alter table public.show_auto_host_config enable row level security;alter table public.show_auto_host_combinations enable row level security;
alter table public.show_auto_host_name_pools enable row level security;alter table public.show_auto_host_runs enable row level security;
create policy "auto host managers read config" on public.show_auto_host_config for select using(has_show_capability('shows.admin.auto_host'));
create policy "auto host managers read combinations" on public.show_auto_host_combinations for select using(has_show_capability('shows.admin.auto_host'));
create policy "auto host managers read names" on public.show_auto_host_name_pools for select using(has_show_capability('shows.admin.auto_host'));
create policy "auto host managers read runs" on public.show_auto_host_runs for select using(has_show_capability('shows.admin.auto_host'));

create or replace function public.has_show_capability(p_capability text,p_user uuid default auth.uid())returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from stables where id=p_user and account_number=1)or has_admin_permission(case p_capability
  when'shows.bulk_enter_all'then'admin.shows.bulk_enter_all'when'shows.bulk_create'then'admin.shows.bulk_create'when'shows.admin.bulk_run'then'admin.shows.bulk_run'
  when'shows.admin.auto_host'then'admin.shows.auto_host'when'shows.admin.edit'then'admin.shows.edit'when'shows.admin.lock'then'admin.shows.lock'
  when'shows.admin.run_now'then'admin.shows.run'when'shows.admin.cancel'then'admin.shows.cancel'when'shows.admin.preview'then'admin.shows.preview'
  when'shows.admin.duplicate'then'admin.shows.duplicate'when'shows.admin.qa'then'admin.shows.qa'when'shows.admin.private'then'admin.shows.private'
  when'shows.admin.processing'then'admin.shows.processing'when'shows.admin.audit'then'admin.shows.audit'else'__unknown_show_capability__'end,p_user)
$$;
create or replace function public.get_show_capabilities()returns jsonb language sql stable security definer set search_path=public as $$
 select jsonb_object_agg(capability,has_show_capability(capability))from unnest(array['shows.bulk_enter_all','shows.bulk_create','shows.admin.bulk_run','shows.admin.auto_host','shows.admin.edit','shows.admin.lock','shows.admin.run_now','shows.admin.cancel','shows.admin.preview','shows.admin.duplicate','shows.admin.qa','shows.admin.private','shows.admin.processing','shows.admin.audit'])capability
$$;

create or replace function public.auto_host_next_run()returns timestamptz language sql stable set search_path=public as $$
 select case when not c.daily_enabled then null when(now()at time zone c.timezone)::time<c.creation_time then((now()at time zone c.timezone)::date+c.creation_time)at time zone c.timezone else(((now()at time zone c.timezone)::date+1)+c.creation_time)at time zone c.timezone end from show_auto_host_config c where id=true
$$;
create or replace function public.show_auto_host_plan()returns jsonb language plpgsql stable security definer set search_path=public as $$
declare c show_auto_host_config;row record;items jsonb:='[]';current_count integer;wanted integer;create_count integer;total_current integer:=0;total_target integer:=0;total_create integer:=0;combo_count integer:=0;
begin if auth.role()<>'service_role'and not has_show_capability('shows.admin.auto_host')then raise exception'Auto Host permission required';end if;select * into c from show_auto_host_config where id=true;
 for row in select x.*,d.name discipline,t.name tier from show_auto_host_combinations x join show_disciplines d on d.id=x.discipline_id join show_tiers t on t.id=x.tier_id where d.active and t.active and(case when c.selection_mode='full'then true else x.enabled end)order by d.name,t.sort_order loop
  wanted:=case when c.selection_mode='full'then c.default_quantity else row.quantity end;
  select count(*)into current_count from player_shows s where s.discipline_id=row.discipline_id and s.tier_id=row.tier_id and s.status='open'and not s.is_private and s.run_at>now();
  create_count:=case when c.quantity_mode='maintain'then greatest(wanted-current_count,0)else wanted end;combo_count:=combo_count+1;total_current:=total_current+current_count;total_target:=total_target+wanted;total_create:=total_create+create_count;
  items:=items||jsonb_build_array(jsonb_build_object('discipline_id',row.discipline_id,'discipline',row.discipline,'tier_id',row.tier_id,'tier',row.tier,'enabled',row.enabled,'quantity',wanted,'entry_fee',row.entry_fee,'base_purse',row.base_purse,'current',current_count,'would_create',create_count));
 end loop;
 return jsonb_build_object('enabled',c.enabled,'selection_mode',c.selection_mode,'quantity_mode',c.quantity_mode,'daily_enabled',c.daily_enabled,'default_quantity',c.default_quantity,'run_delay_days',c.run_delay_days,'use_show_defaults',c.use_show_defaults,'timezone',c.timezone,'creation_time',c.creation_time,'next_run',auto_host_next_run(),'combination_count',combo_count,'current_qualifying',total_current,'target_total',total_target,'would_create',total_create,'items',items);
end$$;

create or replace function public.admin_preview_show_auto_host(p_config jsonb,p_combinations jsonb)returns jsonb language plpgsql stable security definer set search_path=public as $$
declare item jsonb;discipline_name text;tier_name text;current_count integer;wanted integer;create_count integer;items jsonb:='[]';total_current integer:=0;total_target integer:=0;total_create integer:=0;combo_count integer:=0;selection_mode text:=coalesce(p_config->>'selection_mode','full');quantity_mode text:=coalesce(p_config->>'quantity_mode','maintain');default_quantity integer:=coalesce((p_config->>'default_quantity')::integer,10);
begin if not has_show_capability('shows.admin.auto_host')then raise exception'Auto Host permission required';end if;
 for item in select * from jsonb_array_elements(coalesce(p_combinations,'[]'))loop
  if selection_mode='custom'and not coalesce((item->>'enabled')::boolean,false)then continue;end if;select name into discipline_name from show_disciplines where id=item->>'discipline_id'and active;select name into tier_name from show_tiers where id=item->>'tier_id'and active;if discipline_name is null or tier_name is null then continue;end if;
  wanted:=case when selection_mode='full'then default_quantity else coalesce((item->>'quantity')::integer,0)end;select count(*)into current_count from player_shows s where s.discipline_id=item->>'discipline_id'and s.tier_id=item->>'tier_id'and s.status='open'and not s.is_private and s.run_at>now();create_count:=case when quantity_mode='maintain'then greatest(wanted-current_count,0)else wanted end;
  combo_count:=combo_count+1;total_current:=total_current+current_count;total_target:=total_target+wanted;total_create:=total_create+create_count;items:=items||jsonb_build_array(jsonb_build_object('discipline_id',item->>'discipline_id','discipline',discipline_name,'tier_id',item->>'tier_id','tier',tier_name,'current',current_count,'target',wanted,'would_create',create_count));
 end loop;return jsonb_build_object('combination_count',combo_count,'current_qualifying',total_current,'target_total',total_target,'would_create',total_create,'items',items,'side_effects',false);
end$$;

create or replace function public.run_show_auto_host(p_cycle_key text,p_trigger text,p_actor uuid default null)returns jsonb language plpgsql security definer set search_path=public as $$
declare c show_auto_host_config;run_id uuid;prior jsonb;owner_id uuid;plan jsonb;item jsonb;i integer;wanted integer;created integer:=0;skipped integer:=0;errors integer:=0;evaluated integer:=0;created_ids uuid[]:='{}';show_id uuid;show_name text;names text[];run_day date;run_at_time timestamptz;fee bigint;purse bigint;fund system_funds;result jsonb;
begin
 if p_trigger not in('scheduled','manual')then raise exception'Invalid Auto Host trigger';end if;if p_trigger='manual'and not has_show_capability('shows.admin.auto_host',coalesce(p_actor,auth.uid()))then raise exception'Auto Host permission required';end if;
 select * into c from show_auto_host_config where id=true for update;if p_trigger='scheduled'and(not c.enabled or not c.daily_enabled)then return jsonb_build_object('status','off','created',0);end if;
 select r.result into prior from show_auto_host_runs r where r.cycle_key=p_cycle_key and r.completed_at is not null;if prior is not null then return prior||jsonb_build_object('idempotent',true);end if;
 select id into owner_id from stables where account_number=1;if owner_id is null then raise exception'Owner Account #1 not found';end if;
 insert into show_auto_host_runs(cycle_key,trigger,actor_id,scheduled_for)values(p_cycle_key,p_trigger,coalesce(p_actor,owner_id),now())on conflict(cycle_key)do nothing returning id into run_id;
 if run_id is null then return jsonb_build_object('status','processing_or_complete','idempotent',true,'created',0);end if;
 plan:=show_auto_host_plan();run_day:=(now()at time zone c.timezone)::date+c.run_delay_days;run_at_time:=(run_day::timestamp at time zone c.timezone);
 for item in select * from jsonb_array_elements(plan->'items')loop wanted:=(item->>'would_create')::integer;evaluated:=evaluated+1;if wanted=0 then skipped:=skipped+1;continue;end if;
  for i in 1..wanted loop begin
   fee:=case when c.use_show_defaults then 0 else(item->>'entry_fee')::bigint end;purse:=case when c.use_show_defaults then 0 else(item->>'base_purse')::bigint end;
   select p.names into names from show_auto_host_name_pools p where p.discipline_id=item->>'discipline_id';show_name:=coalesce(names[1+mod(created+i-1,greatest(cardinality(names),1))],'Legacy '||(item->>'discipline')||' Classic');
   if exists(select 1 from player_shows s where s.name=show_name and s.run_date=run_day)then show_name:=left(show_name||' '||(select count(*)+1 from player_shows s where s.name like show_name||'%'and s.run_date=run_day),80);end if;
   if purse>0 then select * into fund from system_funds where id='show_fund'for update;if fund.balance<purse then raise exception'Show Fund balance is insufficient for configured purse';end if;update system_funds set balance=balance-purse,lifetime_outflow=lifetime_outflow+purse where id='show_fund';end if;
   insert into player_shows(creator_id,name,discipline_id,tier_id,run_date,run_at,entry_fee,max_entries,maximum_per_owner,description,show_fund_allocation,source,auto_host_run_id)
   values(owner_id,show_name,item->>'discipline_id',item->>'tier_id',run_day,run_at_time,fee,null,2147483647,'Hosted by Legacy Equine · Source: Auto Host',purse,'auto_host',run_id)returning id into show_id;
   if purse>0 then insert into system_fund_ledger(fund_id,amount,transaction_type,source,destination,initiated_by,reason,related_id)values('show_fund',-purse,'show_funding','LE Show Fund',show_name,owner_id,'Auto Host configured base purse',show_id);end if;
   created:=created+1;created_ids:=array_append(created_ids,show_id);
  exception when others then errors:=errors+1;end;end loop;
 end loop;
 result:=jsonb_build_object('run_id',run_id,'cycle_key',p_cycle_key,'trigger',p_trigger,'evaluated',evaluated,'created',created,'skipped',skipped,'errors',errors,'show_ids',created_ids,'run_at',run_at_time,'idempotent',false);
 update show_auto_host_runs set shows_evaluated=evaluated,shows_created=created,shows_skipped=skipped,error_count=errors,result=result,completed_at=now()where id=run_id;
 insert into show_admin_audit(actor_id,action,details)values(coalesce(p_actor,owner_id),'auto_host_'||p_trigger,result-'show_ids');return result;
end$$;

create or replace function public.admin_save_show_auto_host(p_config jsonb,p_combinations jsonb)returns jsonb language plpgsql security definer set search_path=public as $$
declare item jsonb;begin if not has_show_capability('shows.admin.auto_host')then raise exception'Auto Host permission required';end if;
 update show_auto_host_config set enabled=coalesce((p_config->>'enabled')::boolean,enabled),selection_mode=coalesce(p_config->>'selection_mode',selection_mode),quantity_mode=coalesce(p_config->>'quantity_mode',quantity_mode),daily_enabled=coalesce((p_config->>'daily_enabled')::boolean,daily_enabled),default_quantity=coalesce((p_config->>'default_quantity')::integer,default_quantity),run_delay_days=coalesce((p_config->>'run_delay_days')::integer,run_delay_days),use_show_defaults=coalesce((p_config->>'use_show_defaults')::boolean,use_show_defaults),updated_by=auth.uid(),updated_at=now()where id=true;
 for item in select * from jsonb_array_elements(coalesce(p_combinations,'[]'))loop insert into show_auto_host_combinations(discipline_id,tier_id,enabled,quantity,entry_fee,base_purse)values(item->>'discipline_id',item->>'tier_id',coalesce((item->>'enabled')::boolean,false),coalesce((item->>'quantity')::integer,0),coalesce((item->>'entry_fee')::bigint,0),coalesce((item->>'base_purse')::bigint,0))on conflict(discipline_id,tier_id)do update set enabled=excluded.enabled,quantity=excluded.quantity,entry_fee=excluded.entry_fee,base_purse=excluded.base_purse,updated_at=now();end loop;
 insert into show_admin_audit(actor_id,action,details)values(auth.uid(),'auto_host_config_saved',p_config);return show_auto_host_plan();
end$$;
create or replace function public.admin_run_show_auto_host(p_request uuid)returns jsonb language plpgsql security definer set search_path=public as $$begin return run_show_auto_host('manual-'||p_request::text,'manual',auth.uid());end$$;
create or replace function public.get_show_auto_host_workspace()returns jsonb language plpgsql stable security definer set search_path=public as $$
begin if not has_show_capability('shows.admin.auto_host')then raise exception'Auto Host permission required';end if;return jsonb_build_object('plan',show_auto_host_plan(),'disciplines',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)order by name)from show_disciplines where active),'[]'::jsonb),'tiers',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'sort_order',sort_order)order by sort_order)from show_tiers where active),'[]'::jsonb),'combinations',coalesce((select jsonb_agg(to_jsonb(x)order by x.discipline_id,x.tier_id)from show_auto_host_combinations x),'[]'::jsonb),'history',coalesce((select jsonb_agg(to_jsonb(r)order by r.created_at desc)from(select * from show_auto_host_runs order by created_at desc limit 50)r),'[]'::jsonb));end$$;
create or replace function public.process_show_auto_host_schedule()returns jsonb language plpgsql security definer set search_path=public as $$
declare c show_auto_host_config;local_now timestamp;cycle text;begin select * into c from show_auto_host_config where id=true;local_now:=now()at time zone c.timezone;if not c.enabled or not c.daily_enabled or local_now::time<c.creation_time or local_now::time>=c.creation_time+interval'15 minutes'then return jsonb_build_object('status','outside_window_or_off');end if;cycle:=to_char(local_now::date,'YYYY-MM-DD')||'-daily';return run_show_auto_host(cycle,'scheduled',null);end$$;

revoke all on function public.show_auto_host_plan(),public.admin_preview_show_auto_host(jsonb,jsonb),public.admin_save_show_auto_host(jsonb,jsonb),public.admin_run_show_auto_host(uuid),public.get_show_auto_host_workspace(),public.run_show_auto_host(text,text,uuid),public.process_show_auto_host_schedule()from public;
grant execute on function public.show_auto_host_plan(),public.admin_preview_show_auto_host(jsonb,jsonb),public.admin_save_show_auto_host(jsonb,jsonb),public.admin_run_show_auto_host(uuid),public.get_show_auto_host_workspace()to authenticated;
grant execute on function public.process_show_auto_host_schedule()to service_role;
select cron.schedule('le-auto-host-shows','*/5 * * * *','select public.process_show_auto_host_schedule();');
