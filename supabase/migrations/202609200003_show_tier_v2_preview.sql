-- Phase 1: install the authoritative stat-tier resolver and dry-run tools.
-- No existing entries are mutated by this migration.
alter table public.show_tiers add column if not exists minimum_average numeric(10,4);
update public.show_tiers set minimum_average=case id when'novice'then 0 when'intermediate'then 30 when'advanced'then 55 when'elite'then 80 else minimum_average end;
alter table public.show_tiers alter column minimum_average set not null;

create or replace function public.horse_permanent_stat_average(p_horse uuid)returns numeric
language sql stable security definer set search_path=public as $$
 select round((coalesce((stats->>'Agility')::numeric,0)+coalesce((stats->>'Speed')::numeric,0)+coalesce((stats->>'Endurance')::numeric,0)+coalesce((stats->>'Temperament')::numeric,0)+coalesce((stats->>'Strength')::numeric,0)+coalesce((stats->>'Intelligence')::numeric,0)+coalesce((stats->>'Conformation')::numeric,0))/7,4)from horses where id=p_horse
$$;
create or replace function public.get_show_level_for_average(p_average numeric)returns text
language sql stable security definer set search_path=public as $$
 select id from show_tiers where active and p_average>=minimum_average order by minimum_average desc limit 1
$$;
create or replace function public.get_horse_show_level(p_horse uuid)returns text
language sql stable security definer set search_path=public as $$select get_show_level_for_average(horse_permanent_stat_average(p_horse))$$;
create or replace function public.get_show_level_config()returns jsonb language sql stable security definer set search_path=public as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'minimum_average',minimum_average,'maximum_average',next_minimum-0.01,'sort_order',sort_order)order by sort_order),'[]'::jsonb)from(select id,name,minimum_average,sort_order,lead(minimum_average)over(order by minimum_average)next_minimum from show_tiers where active)x
$$;
create or replace function public.preview_show_tier_v2_migration()returns jsonb language sql stable security definer set search_path=public as $$
 select jsonb_build_object('horses',jsonb_build_object('novice',count(*)filter(where level='novice'),'intermediate',count(*)filter(where level='intermediate'),'advanced',count(*)filter(where level='advanced'),'elite',count(*)filter(where level='elite')),'future_entries',jsonb_build_object('eligible',(select count(*)from player_show_entries e join player_shows sh on sh.id=e.show_id where sh.status in('open','processing')and sh.run_at>now()and get_horse_show_level(e.horse_id)=sh.tier_id),'invalid',(select count(*)from player_show_entries e join player_shows sh on sh.id=e.show_id where sh.status in('open','processing')and sh.run_at>now()and get_horse_show_level(e.horse_id)<>sh.tier_id)))from(select get_horse_show_level(id)level from horses where owner_id is not null and sanctuary_retired_at is null)x
$$;
create or replace function public.admin_preview_show_level_counts(p_novice numeric,p_intermediate numeric,p_advanced numeric,p_elite numeric)returns jsonb language plpgsql stable security definer set search_path=public as $$begin
 if not has_show_capability('shows.admin.edit')then raise exception'Show administration permission required';end if;if p_novice<>0 or p_intermediate<=p_novice or p_advanced<=p_intermediate or p_elite<=p_advanced then raise exception'Show Level minimums must be ascending and Novice must begin at 0';end if;
 return(select jsonb_build_object('novice',count(*)filter(where avg>=p_novice and avg<p_intermediate),'intermediate',count(*)filter(where avg>=p_intermediate and avg<p_advanced),'advanced',count(*)filter(where avg>=p_advanced and avg<p_elite),'elite',count(*)filter(where avg>=p_elite))from(select horse_permanent_stat_average(id)avg from horses where owner_id is not null and sanctuary_retired_at is null)x);end$$;
revoke all on function public.horse_permanent_stat_average(uuid),public.get_show_level_for_average(numeric),public.get_horse_show_level(uuid),public.get_show_level_config(),public.preview_show_tier_v2_migration(),public.admin_preview_show_level_counts(numeric,numeric,numeric,numeric)from public;
grant execute on function public.horse_permanent_stat_average(uuid),public.get_show_level_for_average(numeric),public.get_horse_show_level(uuid),public.get_show_level_config()to authenticated;
grant execute on function public.preview_show_tier_v2_migration(),public.admin_preview_show_level_counts(numeric,numeric,numeric,numeric)to authenticated;
