-- Fully qualified, atomic, unlimited multi-horse show entry.
drop function if exists public.enter_player_show(uuid,uuid);
drop function if exists public.enter_player_show_batch(uuid,uuid[]);
drop function if exists public.get_show_entry_options(uuid);

create or replace function public.get_show_entry_options(p_show_id uuid)
returns table(horse_id uuid,name text,breed text,career_points integer,current_tier_id text,current_tier text,entry_status text,ineligibility_reason text)
language sql stable security definer set search_path=public as $$
 select h.id,h.name,h.breed,h.career_points,public.get_horse_competition_tier(h.career_points),ct.name,
 case when e.id is not null then 'entered' when public.get_horse_competition_tier(h.career_points)=sh.tier_id and h.sanctuary_retired_at is null then 'eligible' else 'ineligible' end,
 case when e.id is not null then 'Already entered' when h.sanctuary_retired_at is not null then 'Permanently retired to the LE Equine Sanctuary' when public.get_horse_competition_tier(h.career_points) is null then 'No active competition tier matches these Career Points' when public.get_horse_competition_tier(h.career_points)<>sh.tier_id then ct.name||' — Show requires '||required.name else '' end
 from public.horses as h cross join public.player_shows as sh join public.show_tiers as required on required.id=sh.tier_id
 left join public.show_tiers as ct on ct.id=public.get_horse_competition_tier(h.career_points)
 left join public.player_show_entries as e on e.show_id=sh.id and e.horse_id=h.id
 where sh.id=p_show_id and h.owner_id=auth.uid()
 order by case when e.id is not null then 2 when public.get_horse_competition_tier(h.career_points)=sh.tier_id then 1 else 3 end,h.name
$$;

create or replace function public.enter_player_show_batch(p_show_id uuid,p_horse_ids uuid[])
returns jsonb language plpgsql security definer set search_path=public as $$
declare
 v_show public.player_shows;v_stable public.stables;v_horse public.horses;v_required_tier public.show_tiers;
 v_distinct_horse_ids uuid[];v_selected_horse_id uuid;v_entry_id uuid;v_created_entry_ids uuid[]:='{}';
 v_existing_count bigint;v_total_fee bigint;
begin
 if auth.uid() is null then raise exception 'Authentication required';end if;
 select coalesce(array_agg(distinct requested.id order by requested.id),'{}') into v_distinct_horse_ids from unnest(coalesce(p_horse_ids,'{}')) as requested(id);
 if cardinality(v_distinct_horse_ids)=0 then raise exception 'Select at least one eligible horse';end if;
 select ps.* into v_show from public.player_shows as ps where ps.id=p_show_id for update;
 if not found or v_show.status<>'open' or v_show.run_at<=now() then raise exception 'Show is no longer open';end if;
 select st.* into v_required_tier from public.show_tiers as st where st.id=v_show.tier_id and st.active;
 if not found then raise exception 'Show tier is unavailable';end if;
 select count(*) into v_existing_count from public.player_show_entries as pse where pse.show_id=v_show.id;
 if v_show.max_entries is not null and v_existing_count+cardinality(v_distinct_horse_ids)>v_show.max_entries then raise exception 'Only % total horse entries remain in this show',greatest(0,v_show.max_entries-v_existing_count);end if;
 select st.* into v_stable from public.stables as st where st.id=auth.uid() for update;
 if not found then raise exception 'Stable not found';end if;
 foreach v_selected_horse_id in array v_distinct_horse_ids loop
  select h.* into v_horse from public.horses as h where h.id=v_selected_horse_id for update;
  if not found or v_horse.owner_id<>v_stable.id then raise exception 'One selected horse is no longer owned by your stable';end if;
  if v_horse.sanctuary_retired_at is not null then raise exception '% is permanently retired and cannot show',v_horse.name;end if;
  if exists(select 1 from public.player_show_entries as pse where pse.show_id=v_show.id and pse.horse_id=v_horse.id) then raise exception '% is already entered in this show',v_horse.name;end if;
  if public.get_horse_competition_tier(v_horse.career_points)<>v_show.tier_id then raise exception '% is not eligible for this competition tier',v_horse.name;end if;
 end loop;
 v_total_fee:=v_show.entry_fee*cardinality(v_distinct_horse_ids);
 if v_stable.balance<v_total_fee then raise exception 'Insufficient LED for these show entries';end if;
 foreach v_selected_horse_id in array v_distinct_horse_ids loop
  select h.* into v_horse from public.horses as h where h.id=v_selected_horse_id;
  insert into public.player_show_entries as pse(show_id,horse_id,owner_id,tier_id,career_points_snapshot,horse_name_snapshot,owner_name_snapshot,owner_account_snapshot,eligibility_snapshot)
  values(v_show.id,v_horse.id,v_stable.id,v_show.tier_id,v_horse.career_points,v_horse.name,v_stable.name,v_stable.account_number,jsonb_build_object('career_points_at_entry',v_horse.career_points,'tier_at_entry',v_show.tier_id,'tier_name_at_entry',v_required_tier.name)) returning pse.id into v_entry_id;
  v_created_entry_ids:=array_append(v_created_entry_ids,v_entry_id);
 end loop;
 if v_total_fee>0 then
  update public.stables as st set balance=st.balance-v_total_fee where st.id=v_stable.id;
  update public.player_shows as ps set entry_fee_purse=ps.entry_fee_purse+v_total_fee where ps.id=v_show.id;
  insert into public.currency_ledger(stable_id,amount,reason,horse_id) select v_stable.id,-v_show.entry_fee,'Show entry: '||v_show.name,pse.horse_id from public.player_show_entries as pse where pse.id=any(v_created_entry_ids);
 end if;
 return jsonb_build_object('entries_created',cardinality(v_created_entry_ids),'fee_each',v_show.entry_fee,'total_fee',v_total_fee,'balance_after',v_stable.balance-v_total_fee,'entry_ids',v_created_entry_ids);
exception when unique_violation then raise exception 'A selected horse is already entered in this show';
end$$;

create function public.enter_player_show(p_show_id uuid,p_horse_id uuid) returns public.player_show_entries language plpgsql security definer set search_path=public as $$
declare v_result public.player_show_entries;begin
 perform public.enter_player_show_batch(p_show_id,array[p_horse_id]);
 select pse.* into v_result from public.player_show_entries as pse where pse.show_id=p_show_id and pse.horse_id=p_horse_id;
 return v_result;
end$$;

revoke all on function public.get_show_entry_options(uuid),public.enter_player_show_batch(uuid,uuid[]),public.enter_player_show(uuid,uuid) from public;
grant execute on function public.get_show_entry_options(uuid),public.enter_player_show_batch(uuid,uuid[]),public.enter_player_show(uuid,uuid) to authenticated;
