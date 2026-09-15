-- Legacy Equine provisional discipline mappings. Database records remain the
-- configurable source of truth; no discipline formula is embedded in clients.
insert into public.show_disciplines(id,name,stat_weights,active) values
('hunters','Hunters','{"Agility":1,"Temperament":1,"Conformation":1,"Intelligence":1}',true),
('jumpers','Jumpers','{"Agility":1,"Strength":1,"Speed":1,"Intelligence":1}',true),
('dressage','Dressage','{"Agility":1,"Temperament":1,"Intelligence":1,"Conformation":1}',true),
('halter','Halter','{"Conformation":1,"Temperament":1,"Strength":1}',true),
('reining','Reining','{"Agility":1,"Temperament":1,"Intelligence":1,"Strength":1}',true),
('western_pleasure','Western Pleasure','{"Temperament":1,"Conformation":1,"Intelligence":1,"Agility":1}',true),
('trail','Trail','{"Temperament":1,"Intelligence":1,"Agility":1,"Endurance":1}',true),
('driving','Driving','{"Strength":1,"Temperament":1,"Endurance":1,"Intelligence":1}',true),
('steeplechase','Steeplechase','{"Speed":1,"Endurance":1,"Agility":1,"Strength":1}',true),
('fox_hunting','Fox Hunting','{"Endurance":1,"Agility":1,"Temperament":1,"Intelligence":1}',true),
('racing','Racing','{"Speed":1,"Endurance":1,"Strength":1}',true),
('cross_country','Cross Country','{"Endurance":1,"Agility":1,"Strength":1,"Temperament":1}',true)
on conflict(id) do update set name=excluded.name,stat_weights=excluded.stat_weights,active=true;
update public.show_disciplines set active=false where id in('horsemanship','draghunting');

alter table public.player_show_entries add column if not exists horse_name_snapshot text;
alter table public.player_show_entries add column if not exists owner_name_snapshot text;
alter table public.player_show_entries add column if not exists owner_account_snapshot bigint;
alter table public.player_show_entries add column if not exists eligibility_snapshot jsonb not null default '{}';
alter table public.player_show_results add column if not exists horse_name_snapshot text;
alter table public.player_show_results add column if not exists owner_name_snapshot text;
alter table public.player_show_results add column if not exists owner_account_snapshot bigint;
alter table public.player_show_results add column if not exists score_breakdown jsonb not null default '{}';
update public.player_show_entries e set horse_name_snapshot=h.name,owner_name_snapshot=s.name,owner_account_snapshot=s.account_number from horses h,stables s where h.id=e.horse_id and s.id=e.owner_id and (e.horse_name_snapshot is null or e.owner_name_snapshot is null);
update public.player_show_results r set horse_name_snapshot=coalesce(e.horse_name_snapshot,h.name),owner_name_snapshot=coalesce(e.owner_name_snapshot,s.name),owner_account_snapshot=coalesce(e.owner_account_snapshot,s.account_number) from player_show_entries e,horses h,stables s where e.id=r.entry_id and h.id=r.horse_id and s.id=r.owner_id and (r.horse_name_snapshot is null or r.owner_name_snapshot is null);

create or replace function public.show_score_breakdown(target_horse uuid,weights jsonb,score_time timestamptz)
returns jsonb language sql stable security definer set search_path=public as $$
select coalesce(jsonb_object_agg(w.key,jsonb_build_object(
 'base',greatest(0,coalesce((h.stats->>w.key)::numeric,0)-coalesce(tr.gain,0)),
 'training',coalesce(tr.gain,0),
 'tack',coalesce((h.tack_bonuses->>w.key)::numeric,0),
 'farrier',coalesce(sv.farrier,0),
 'massage',coalesce(sv.massage,0),
 'service',coalesce(sv.total,0),
 'effective',coalesce((h.stats->>w.key)::numeric,0)+coalesce((h.tack_bonuses->>w.key)::numeric,0)+coalesce(sv.total,0)
)),'{}'::jsonb)
from horses h cross join lateral jsonb_each(weights) w
left join lateral(select sum(gain)::numeric gain from training_log where horse_id=h.id and stat_key=w.key) tr on true
left join lateral(select sum(coalesce((effect->>w.key)::numeric,0)) total,sum(coalesce((effect->>w.key)::numeric,0)) filter(where profession_id='farrier') farrier,sum(coalesce((effect->>w.key)::numeric,0)) filter(where profession_id='massage') massage from horse_service_records where horse_id=h.id and status='completed' and(effect_expires_at is null or effect_expires_at>score_time)) sv on true
where h.id=target_horse group by h.id
$$;

drop function if exists public.enter_player_show(uuid,uuid);
create function public.enter_player_show(target_show uuid,target_horse uuid) returns public.player_show_entries language plpgsql security definer set search_path=public as $$
declare sh player_shows;h horses;t show_tiers;s stables;result player_show_entries;
begin
 select * into sh from player_shows where id=target_show for update;if sh.status<>'open' or sh.run_at<=now() then raise exception 'Show is no longer open';end if;
 if sh.max_entries is not null and(select count(*) from player_show_entries where show_id=sh.id)>=sh.max_entries then raise exception 'Show is full';end if;
 if(select count(*) from player_show_entries where show_id=sh.id and owner_id=auth.uid())>=sh.maximum_per_owner then raise exception 'Owner entry limit reached';end if;
 select * into h from horses where id=target_horse for update;if h.owner_id<>auth.uid() then raise exception 'Choose a horse you own';end if;
 select * into t from show_tiers where id=sh.tier_id;if h.career_points<t.minimum_points or(t.maximum_points is not null and h.career_points>t.maximum_points) then raise exception 'Horse is not eligible for this Career Point tier';end if;
 select * into s from stables where id=auth.uid() for update;if s.balance<sh.entry_fee then raise exception 'Insufficient LED for entry fee';end if;
 if sh.entry_fee>0 then update stables set balance=balance-sh.entry_fee where id=s.id;update player_shows set entry_fee_purse=entry_fee_purse+sh.entry_fee where id=sh.id;insert into currency_ledger(stable_id,amount,reason,horse_id) values(s.id,-sh.entry_fee,'Show entry: '||sh.name,h.id);end if;
 insert into player_show_entries(show_id,horse_id,owner_id,tier_id,career_points_snapshot,horse_name_snapshot,owner_name_snapshot,owner_account_snapshot) values(sh.id,h.id,s.id,sh.tier_id,h.career_points,h.name,s.name,s.account_number) returning * into result;return result;
exception when unique_violation then raise exception 'Horse is already entered';end $$;

create or replace function public.process_due_player_shows() returns integer language plpgsql security definer set search_path=public as $$
declare sh player_shows;ent record;weights jsonb;purse bigint;rule show_placement_rules;rank_no int;processed int:=0;breakdown jsonb;score numeric;base_score numeric;inserted uuid;
begin
 for sh in select * from player_shows where status in('open','processing') and run_at<=now() order by run_at for update skip locked loop
  update player_shows set status='processing' where id=sh.id;rank_no:=0;purse:=sh.entry_fee_purse+sh.show_fund_allocation+sh.treasury_allocation;select stat_weights into weights from show_disciplines where id=sh.discipline_id;
  for ent in select e.*,h.stats,h.tack_bonuses from player_show_entries e join horses h on h.id=e.horse_id where e.show_id=sh.id order by e.id loop
   breakdown:=show_score_breakdown(ent.horse_id,weights,sh.run_at);
   score:=(select sum((breakdown->key->>'effective')::numeric*(value::text)::numeric)/nullif(sum((value::text)::numeric),0) from jsonb_each(weights));
   base_score:=(select sum(((breakdown->key->>'base')::numeric+(breakdown->key->>'training')::numeric)*(value::text)::numeric)/nullif(sum((value::text)::numeric),0) from jsonb_each(weights));
   update player_show_entries set eligibility_snapshot=coalesce(eligibility_snapshot,'{}'::jsonb)||jsonb_build_object('competition_score',score,'base_score',base_score,'score_breakdown',breakdown) where id=ent.id;
  end loop;
  for ent in select e.*,(e.eligibility_snapshot->>'competition_score')::numeric score,(e.eligibility_snapshot->>'base_score')::numeric base_score,e.eligibility_snapshot->'score_breakdown' breakdown from player_show_entries e where e.show_id=sh.id order by score desc,base_score desc,e.career_points_snapshot desc,e.entered_at,e.horse_id loop
   rank_no:=rank_no+1;select * into rule from show_placement_rules where placement=rank_no;inserted:=null;
   insert into player_show_results(show_id,entry_id,horse_id,owner_id,placement,competition_score,base_contribution,tack_contribution,service_contribution,career_points_awarded,led_winnings,horse_name_snapshot,owner_name_snapshot,owner_account_snapshot,score_breakdown)
   values(sh.id,ent.id,ent.horse_id,ent.owner_id,rank_no,ent.score,ent.base_score,coalesce((select avg((value->>'tack')::numeric) from jsonb_each(ent.breakdown)),0),coalesce((select avg((value->>'service')::numeric) from jsonb_each(ent.breakdown)),0),coalesce(rule.career_points,0),floor(purse*coalesce(rule.prize_percent,0)/100),ent.horse_name_snapshot,ent.owner_name_snapshot,ent.owner_account_snapshot,ent.breakdown)
   on conflict(entry_id) do nothing returning id into inserted;
   if inserted is not null then
    update horses set career_points=career_points+coalesce(rule.career_points,0) where id=ent.horse_id;
    if coalesce(rule.prize_percent,0)>0 then update stables set balance=balance+floor(purse*rule.prize_percent/100) where id=ent.owner_id;insert into currency_ledger(stable_id,amount,reason,horse_id) values(ent.owner_id,floor(purse*rule.prize_percent/100),'Show winnings: '||sh.name,ent.horse_id);end if;
   end if;
  end loop;
  update player_shows set status='complete',processed_at=coalesce(processed_at,now()) where id=sh.id;processed:=processed+1;
 end loop;return processed;
end $$;

drop function if exists public.get_player_shows();
create function public.get_player_shows() returns table(id uuid,name text,discipline text,tier text,run_at timestamptz,entry_fee bigint,max_entries integer,entry_count bigint,description text,creator_name text,creator_account bigint,status text,discipline_id text,tier_id text,purse bigint,creator_id uuid) language sql security definer set search_path=public stable as $$
select sh.id,sh.name,d.name,t.name,sh.run_at,sh.entry_fee,sh.max_entries,count(e.id),sh.description,s.name,s.account_number,sh.status,sh.discipline_id,sh.tier_id,sh.entry_fee_purse+sh.show_fund_allocation+sh.treasury_allocation,sh.creator_id from player_shows sh join show_disciplines d on d.id=sh.discipline_id join show_tiers t on t.id=sh.tier_id join stables s on s.id=sh.creator_id left join player_show_entries e on e.show_id=sh.id where sh.status='open' group by sh.id,d.name,t.name,s.name,s.account_number order by sh.run_at $$;

create or replace function public.get_show_archive(search_text text default '',filter_discipline text default '',filter_tier text default '',filter_host uuid default null,sort_mode text default 'newest') returns table(id uuid,name text,discipline text,tier text,run_at timestamptz,entry_count bigint,purse bigint,creator_name text,creator_account bigint) language sql security definer set search_path=public stable as $$
select sh.id,sh.name,d.name,t.name,sh.run_at,count(e.id),sh.entry_fee_purse+sh.show_fund_allocation+sh.treasury_allocation,s.name,s.account_number from player_shows sh join show_disciplines d on d.id=sh.discipline_id join show_tiers t on t.id=sh.tier_id join stables s on s.id=sh.creator_id left join player_show_entries e on e.show_id=sh.id where sh.status='complete' and(filter_discipline='' or sh.discipline_id=filter_discipline) and(filter_tier='' or sh.tier_id=filter_tier) and(filter_host is null or sh.creator_id=filter_host) and(search_text='' or sh.name ilike '%'||search_text||'%' or d.name ilike '%'||search_text||'%' or s.name ilike '%'||search_text||'%' or exists(select 1 from player_show_results r where r.show_id=sh.id and(r.horse_name_snapshot ilike '%'||search_text||'%' or r.owner_name_snapshot ilike '%'||search_text||'%'))) group by sh.id,d.name,t.name,s.name,s.account_number order by case when sort_mode='oldest' then sh.run_at end asc,case when sort_mode='largest_purse' then sh.entry_fee_purse+sh.show_fund_allocation+sh.treasury_allocation end desc,case when sort_mode='most_entries' then count(e.id) end desc,sh.run_at desc $$;

create or replace function public.get_show_results(target_show uuid) returns jsonb language sql security definer set search_path=public stable as $$
select jsonb_build_object('show',jsonb_build_object('id',sh.id,'name',sh.name,'discipline',d.name,'tier',t.name,'run_at',sh.run_at,'host_name',s.name,'host_account',s.account_number,'entries',(select count(*) from player_show_entries where show_id=sh.id),'purse',sh.entry_fee_purse+sh.show_fund_allocation+sh.treasury_allocation),'results',coalesce((select jsonb_agg(jsonb_build_object('result_id',r.id,'horse_id',r.horse_id,'horse_name',r.horse_name_snapshot,'owner_name',r.owner_name_snapshot,'owner_account',r.owner_account_snapshot,'placement',r.placement,'score',r.competition_score,'prize',r.led_winnings,'career_points',r.career_points_awarded,'breakdown',r.score_breakdown) order by r.placement) from player_show_results r where r.show_id=sh.id),'[]'::jsonb)) from player_shows sh join show_disciplines d on d.id=sh.discipline_id join show_tiers t on t.id=sh.tier_id join stables s on s.id=sh.creator_id where sh.id=target_show and sh.status='complete' $$;

create or replace function public.get_horse_show_record(target_horse uuid) returns jsonb language sql security definer set search_path=public stable as $$
select jsonb_build_object('starts',count(r.id),'wins',count(*) filter(where r.placement=1),'places',count(*) filter(where r.placement=2),'shows',count(*) filter(where r.placement=3),'other_placings',count(*) filter(where r.placement>3),'career_points',coalesce(sum(r.career_points_awarded),0),'earnings',coalesce(sum(r.led_winnings),0),'disciplines',coalesce((select jsonb_agg(x) from(select d.name discipline,count(*) starts,count(*) filter(where rr.placement=1) wins,count(*) filter(where rr.placement=2) places,count(*) filter(where rr.placement=3) shows from player_show_results rr join player_shows sh on sh.id=rr.show_id join show_disciplines d on d.id=sh.discipline_id where rr.horse_id=target_horse group by d.name order by count(*) desc,d.name)x),'[]'::jsonb),'history',coalesce((select jsonb_agg(x order by run_at desc) from(select r.id,r.show_id,sh.name,d.name discipline,t.name tier,sh.run_at,r.placement,r.competition_score score,r.career_points_awarded career_points,r.led_winnings earnings,r.owner_name_snapshot,r.owner_account_snapshot from player_show_results r join player_shows sh on sh.id=r.show_id join show_disciplines d on d.id=sh.discipline_id join show_tiers t on t.id=sh.tier_id where r.horse_id=target_horse)x),'[]'::jsonb)) from player_show_results r where r.horse_id=target_horse $$;

revoke all on function public.show_score_breakdown(uuid,jsonb,timestamptz),public.enter_player_show(uuid,uuid),public.process_due_player_shows(),public.get_player_shows(),public.get_show_archive(text,text,text,uuid,text),public.get_show_results(uuid),public.get_horse_show_record(uuid) from public;
grant execute on function public.get_player_shows(),public.get_show_archive(text,text,text,uuid,text),public.get_show_results(uuid),public.get_horse_show_record(uuid) to authenticated;
grant execute on function public.enter_player_show(uuid,uuid) to authenticated;
grant execute on function public.show_score_breakdown(uuid,jsonb,timestamptz),public.process_due_player_shows() to service_role;
