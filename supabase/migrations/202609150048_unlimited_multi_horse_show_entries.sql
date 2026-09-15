-- Unlimited eligible horses per owner; strict, database-driven competition tiers.
alter table public.player_shows alter column maximum_per_owner set default 2147483647;
update public.player_shows set maximum_per_owner=2147483647;

create or replace function public.get_horse_competition_tier(career_point_total integer)
returns text language sql stable security definer set search_path=public as $$
 select id from show_tiers where active and career_point_total>=minimum_points and(maximum_points is null or career_point_total<=maximum_points) order by sort_order limit 1
$$;

create or replace function public.get_show_entry_options(target_show uuid)
returns table(horse_id uuid,name text,breed text,career_points integer,current_tier_id text,current_tier text,entry_status text,ineligibility_reason text)
language sql stable security definer set search_path=public as $$
 select h.id,h.name,h.breed,h.career_points,get_horse_competition_tier(h.career_points),ct.name,
 case when e.id is not null then 'entered' when get_horse_competition_tier(h.career_points)=sh.tier_id and h.sanctuary_retired_at is null then 'eligible' else 'ineligible' end,
 case when e.id is not null then 'Already entered' when h.sanctuary_retired_at is not null then 'Permanently retired to the LE Equine Sanctuary' when get_horse_competition_tier(h.career_points) is null then 'No active competition tier matches these Career Points' when get_horse_competition_tier(h.career_points)<>sh.tier_id then ct.name||' — Show requires '||required.name else '' end
 from horses h cross join player_shows sh join show_tiers required on required.id=sh.tier_id left join show_tiers ct on ct.id=get_horse_competition_tier(h.career_points) left join player_show_entries e on e.show_id=sh.id and e.horse_id=h.id
 where sh.id=target_show and h.owner_id=auth.uid() order by case when e.id is not null then 2 when get_horse_competition_tier(h.career_points)=sh.tier_id then 1 else 3 end,h.name
$$;

create or replace function public.enter_player_show_batch(target_show uuid,target_horses uuid[])
returns jsonb language plpgsql security definer set search_path=public as $$
declare sh player_shows;s stables;h horses;horse_ids uuid[];horse_id uuid;required_tier show_tiers;existing_count bigint;total_fee bigint;created_ids uuid[]='{}';begin
 if auth.uid() is null then raise exception 'Authentication required';end if;
 select coalesce(array_agg(distinct x order by x),'{}') into horse_ids from unnest(coalesce(target_horses,'{}')) x;
 if cardinality(horse_ids)=0 then raise exception 'Select at least one eligible horse';end if;
 select * into sh from player_shows where id=target_show for update;if not found or sh.status<>'open' or sh.run_at<=now() then raise exception 'Show is no longer open';end if;
 select * into required_tier from show_tiers where id=sh.tier_id and active;if not found then raise exception 'Show tier is unavailable';end if;
 select count(*) into existing_count from player_show_entries where show_id=sh.id;
 if sh.max_entries is not null and existing_count+cardinality(horse_ids)>sh.max_entries then raise exception 'Only % total horse entries remain in this show',greatest(0,sh.max_entries-existing_count);end if;
 select * into s from stables where id=auth.uid() for update;if not found then raise exception 'Stable not found';end if;
 foreach horse_id in array horse_ids loop
  select * into h from horses where id=horse_id for update;
  if not found or h.owner_id<>s.id then raise exception 'One selected horse is no longer owned by your stable';end if;
  if h.sanctuary_retired_at is not null then raise exception '% is permanently retired and cannot show',h.name;end if;
  if exists(select 1 from player_show_entries where show_id=sh.id and horse_id=h.id) then raise exception '% is already entered in this show',h.name;end if;
  if get_horse_competition_tier(h.career_points)<>sh.tier_id then raise exception '% is % tier; this show requires %',h.name,coalesce((select name from show_tiers where id=get_horse_competition_tier(h.career_points)),'unassigned'),required_tier.name;end if;
 end loop;
 total_fee:=sh.entry_fee*cardinality(horse_ids);if s.balance<total_fee then raise exception 'Insufficient LED. % horses cost % LED; current balance is % LED',cardinality(horse_ids),total_fee,s.balance;end if;
 foreach horse_id in array horse_ids loop
  select * into h from horses where id=horse_id;
  insert into player_show_entries(show_id,horse_id,owner_id,tier_id,career_points_snapshot,horse_name_snapshot,owner_name_snapshot,owner_account_snapshot,eligibility_snapshot)
  values(sh.id,h.id,s.id,sh.tier_id,h.career_points,h.name,s.name,s.account_number,jsonb_build_object('career_points_at_entry',h.career_points,'tier_at_entry',sh.tier_id,'tier_name_at_entry',required_tier.name)) returning id into horse_id;
  created_ids:=array_append(created_ids,horse_id);
 end loop;
 if total_fee>0 then update stables set balance=balance-total_fee where id=s.id;update player_shows set entry_fee_purse=entry_fee_purse+total_fee where id=sh.id;insert into currency_ledger(stable_id,amount,reason,horse_id) select s.id,-sh.entry_fee,'Show entry: '||sh.name,e.horse_id from player_show_entries e where e.id=any(created_ids);end if;
 return jsonb_build_object('entries_created',cardinality(created_ids),'fee_each',sh.entry_fee,'total_fee',total_fee,'balance_after',s.balance-total_fee,'entry_ids',created_ids);
exception when unique_violation then raise exception 'A selected horse is already entered in this show';end$$;

drop function public.enter_player_show(uuid,uuid);
create function public.enter_player_show(target_show uuid,target_horse uuid) returns public.player_show_entries language plpgsql security definer set search_path=public as $$declare result player_show_entries;begin perform enter_player_show_batch(target_show,array[target_horse]);select * into result from player_show_entries where show_id=target_show and horse_id=target_horse;return result;end$$;

revoke all on function public.get_horse_competition_tier(integer),public.get_show_entry_options(uuid),public.enter_player_show_batch(uuid,uuid[]),public.enter_player_show(uuid,uuid) from public;
grant execute on function public.get_horse_competition_tier(integer),public.get_show_entry_options(uuid),public.enter_player_show_batch(uuid,uuid[]),public.enter_player_show(uuid,uuid) to authenticated;
