-- Show-earned Allocatable Points (AP). AP is deliberately separate from Career Points.

alter table public.horses add column if not exists allocatable_points integer not null default 0 check(allocatable_points>=0);
alter table public.horses add column if not exists lifetime_ap_earned integer not null default 0 check(lifetime_ap_earned>=0);
alter table public.horses add column if not exists lifetime_ap_allocated integer not null default 0 check(lifetime_ap_allocated>=0);

create table if not exists public.show_ap_config(
 id boolean primary key default true check(id),
 first_place integer not null default 3 check(first_place>=0),
 second_place integer not null default 2 check(second_place>=0),
 third_place integer not null default 1 check(third_place>=0),
 updated_by uuid references public.stables(id),updated_at timestamptz not null default now()
);
insert into public.show_ap_config(id)values(true)on conflict(id)do nothing;
alter table public.show_ap_config enable row level security;
drop policy if exists "AP config readable" on public.show_ap_config;
create policy "AP config readable" on public.show_ap_config for select using(true);

create table if not exists public.horse_ap_awards(
 id uuid primary key default gen_random_uuid(),horse_id uuid not null references public.horses(id),
 show_id uuid not null references public.player_shows(id),show_result_id uuid not null unique references public.player_show_results(id),
 placement integer not null check(placement between 1 and 3),points integer not null check(points>0),awarded_at timestamptz not null default now()
);
create index if not exists horse_ap_awards_horse_idx on public.horse_ap_awards(horse_id,awarded_at desc);
alter table public.horse_ap_awards enable row level security;
drop policy if exists "horse AP awards readable" on public.horse_ap_awards;
create policy "horse AP awards readable" on public.horse_ap_awards for select using(true);

create table if not exists public.horse_ap_allocations(
 id uuid primary key default gen_random_uuid(),horse_id uuid not null references public.horses(id),owner_id uuid not null references public.stables(id),
 points_spent integer not null check(points_spent>0),allocations jsonb not null,before_stats jsonb not null,after_stats jsonb not null,allocated_at timestamptz not null default now()
);
create index if not exists horse_ap_allocations_horse_idx on public.horse_ap_allocations(horse_id,allocated_at desc);
alter table public.horse_ap_allocations enable row level security;
drop policy if exists "owners read horse AP allocations" on public.horse_ap_allocations;
create policy "owners read horse AP allocations" on public.horse_ap_allocations for select using(owner_id=auth.uid()or exists(select 1 from public.stables s where s.id=auth.uid()and s.account_number=1));

create or replace function public.award_show_allocatable_points()returns trigger language plpgsql security definer set search_path=public as $$
declare cfg show_ap_config;award integer;
begin
 if new.placement>3 then return new;end if;
 select * into cfg from show_ap_config where id=true;
 award:=case new.placement when 1 then cfg.first_place when 2 then cfg.second_place when 3 then cfg.third_place else 0 end;
 if award<=0 then return new;end if;
 insert into horse_ap_awards(horse_id,show_id,show_result_id,placement,points)
 values(new.horse_id,new.show_id,new.id,new.placement,award)on conflict(show_result_id)do nothing;
 if found then update horses set allocatable_points=allocatable_points+award,lifetime_ap_earned=lifetime_ap_earned+award where id=new.horse_id;end if;
 return new;
end$$;
drop trigger if exists award_ap_from_show_result on public.player_show_results;
create trigger award_ap_from_show_result after insert on public.player_show_results for each row execute function public.award_show_allocatable_points();

create or replace function public.get_horse_ap_summary(p_horse uuid)returns jsonb language plpgsql stable security definer set search_path=public as $$
declare h horses;
begin
 select * into h from horses where id=p_horse;if not found then raise exception'Horse not found';end if;
 return jsonb_build_object('available',h.allocatable_points,'lifetime_earned',h.lifetime_ap_earned,'lifetime_allocated',h.lifetime_ap_allocated,
  'earned',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'points',a.points,'placement',a.placement,'show_name',sh.name,'awarded_at',a.awarded_at)order by a.awarded_at desc)from horse_ap_awards a join player_shows sh on sh.id=a.show_id where a.horse_id=h.id),'[]'::jsonb),
  'allocated',case when h.owner_id=auth.uid()or exists(select 1 from stables s where s.id=auth.uid()and s.account_number=1)then coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'points',x.points_spent,'allocations',x.allocations,'allocated_at',x.allocated_at)order by x.allocated_at desc)from horse_ap_allocations x where x.horse_id=h.id),'[]'::jsonb)else'[]'::jsonb end);
end$$;

create or replace function public.allocate_horse_ap(p_horse uuid,p_allocations jsonb)returns jsonb language plpgsql security definer set search_path=public as $$
declare h horses;entry record;requested integer:=0;before_stats jsonb;after_stats jsonb;allowed text[]:=array['Agility','Speed','Endurance','Temperament','Strength','Intelligence','Conformation'];
begin
 select * into h from horses where id=p_horse for update;if not found then raise exception'Horse not found';end if;
 if h.owner_id<>auth.uid()then raise exception'Only the current horse owner may allocate AP';end if;
 if p_allocations is null or jsonb_typeof(p_allocations)<>'object'then raise exception'Choose at least one stat';end if;
 before_stats:=h.stats;after_stats:=h.stats;
 for entry in select key,value from jsonb_each_text(p_allocations)loop
  if not(entry.key=any(allowed))then raise exception'Invalid horse stat: %',entry.key;end if;
  if entry.value!~'^[0-9]+$'or entry.value::integer<0 then raise exception'AP allocations must be whole non-negative values';end if;
  requested:=requested+entry.value::integer;
  if entry.value::integer>0 then after_stats:=jsonb_set(after_stats,array[entry.key],to_jsonb(coalesce((after_stats->>entry.key)::integer,0)+entry.value::integer),true);end if;
 end loop;
 if requested<1 then raise exception'Choose at least one AP to allocate';end if;
 if requested>h.allocatable_points then raise exception'You only have % Allocatable Points available',h.allocatable_points;end if;
 update horses set stats=after_stats,allocatable_points=allocatable_points-requested,lifetime_ap_allocated=lifetime_ap_allocated+requested where id=h.id;
 insert into horse_ap_allocations(horse_id,owner_id,points_spent,allocations,before_stats,after_stats)values(h.id,auth.uid(),requested,p_allocations,before_stats,after_stats);
 return jsonb_build_object('horse_id',h.id,'spent',requested,'available',h.allocatable_points-requested,'before',before_stats,'after',after_stats);
end$$;

create or replace function public.owner_correct_horse_ap(p_horse uuid,p_available integer,p_lifetime_earned integer,p_lifetime_allocated integer,p_stat_changes jsonb,p_reason text)returns jsonb language plpgsql security definer set search_path=public as $$
declare actor stables;h horses;entry record;before_value jsonb;after_value jsonb;
begin
 select * into actor from stables where id=auth.uid();if actor.account_number<>1 then raise exception'Owner Account #1 required';end if;
 if length(trim(coalesce(p_reason,'')))<5 then raise exception'A correction reason is required';end if;
 select * into h from horses where id=p_horse for update;if not found then raise exception'Horse not found';end if;
 if least(p_available,p_lifetime_earned,p_lifetime_allocated)<0 or p_lifetime_allocated>p_lifetime_earned or p_available>p_lifetime_earned-p_lifetime_allocated then raise exception'Invalid AP correction totals';end if;
 before_value:=jsonb_build_object('available',h.allocatable_points,'lifetime_earned',h.lifetime_ap_earned,'lifetime_allocated',h.lifetime_ap_allocated,'stats',h.stats);after_value:=h.stats;
 for entry in select key,value from jsonb_each_text(coalesce(p_stat_changes,'{}'::jsonb))loop
  if not(entry.key=any(array['Agility','Speed','Endurance','Temperament','Strength','Intelligence','Conformation']))or entry.value!~'^[0-9]+$'then raise exception'Invalid stat correction';end if;
  after_value:=jsonb_set(after_value,array[entry.key],to_jsonb(entry.value::integer),true);
 end loop;
 update horses set allocatable_points=p_available,lifetime_ap_earned=p_lifetime_earned,lifetime_ap_allocated=p_lifetime_allocated,stats=after_value where id=h.id;
 insert into admin_audit_log(actor_id,action_type,system,target_type,target_id,details)values(auth.uid(),'horse.ap_correction','shows','horse',h.id::text,jsonb_build_object('reason',left(p_reason,1000),'before',before_value,'after',jsonb_build_object('available',p_available,'lifetime_earned',p_lifetime_earned,'lifetime_allocated',p_lifetime_allocated,'stats',after_value)));
 return jsonb_build_object('horse_id',h.id,'available',p_available,'lifetime_earned',p_lifetime_earned,'lifetime_allocated',p_lifetime_allocated,'stats',after_value);
end$$;

create or replace function public.admin_update_show_ap_config(p_first integer,p_second integer,p_third integer)returns void language plpgsql security definer set search_path=public as $$
begin perform require_super_admin();if least(p_first,p_second,p_third)<0 then raise exception'AP awards cannot be negative';end if;update show_ap_config set first_place=p_first,second_place=p_second,third_place=p_third,updated_by=auth.uid(),updated_at=now()where id=true;insert into admin_audit_log(actor_id,action_type,system,details)values(auth.uid(),'shows.ap_config_updated','shows',jsonb_build_object('first',p_first,'second',p_second,'third',p_third));end$$;

create or replace function public.get_show_results(target_show uuid)returns jsonb language sql security definer set search_path=public stable as $$
select jsonb_build_object('show',jsonb_build_object('id',sh.id,'name',sh.name,'discipline',d.name,'tier',t.name,'run_at',sh.run_at,'host_name',s.name,'host_account',s.account_number,'entries',(select count(*)from player_show_entries where show_id=sh.id),'purse',sh.entry_fee_purse+sh.show_fund_allocation+sh.treasury_allocation),'results',coalesce((select jsonb_agg(jsonb_build_object('result_id',r.id,'horse_id',r.horse_id,'horse_name',r.horse_name_snapshot,'owner_name',r.owner_name_snapshot,'owner_account',r.owner_account_snapshot,'placement',r.placement,'score',r.competition_score,'prize',r.led_winnings,'career_points',r.career_points_awarded,'ap_earned',coalesce(a.points,0),'breakdown',r.score_breakdown)order by r.placement)from player_show_results r left join horse_ap_awards a on a.show_result_id=r.id where r.show_id=sh.id),'[]'::jsonb))from player_shows sh join show_disciplines d on d.id=sh.discipline_id join show_tiers t on t.id=sh.tier_id join stables s on s.id=sh.creator_id where sh.id=target_show and sh.status='complete'$$;

revoke all on function public.get_horse_ap_summary(uuid),public.allocate_horse_ap(uuid,jsonb),public.owner_correct_horse_ap(uuid,integer,integer,integer,jsonb,text),public.admin_update_show_ap_config(integer,integer,integer)from public;
grant execute on function public.get_horse_ap_summary(uuid),public.allocate_horse_ap(uuid,jsonb)to authenticated;
grant execute on function public.owner_correct_horse_ap(uuid,integer,integer,integer,jsonb,text),public.admin_update_show_ap_config(integer,integer,integer)to authenticated;
