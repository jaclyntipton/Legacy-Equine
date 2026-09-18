-- Apply the validated pre-authoritative AP snapshot exactly once, per result row.
do $$
declare
 v_run public.historical_ap_reconciliations;
 v_credited_results integer;
 v_credited_horses integer;
 v_credited_ap integer;
 v_second_run_ap integer;
begin
 select * into strict v_run
 from public.historical_ap_reconciliations
 where reconciliation_key='pre_authoritative_show_ap_v1'
 for update;

 if v_run.status<>'dry_run' then
  raise exception 'Historical AP reconciliation has already been applied';
 end if;

 create temporary table historical_ap_credits(
  horse_id uuid primary key,
  points integer not null,
  result_count integer not null,
  available_before integer not null,
  earned_before integer not null,
  allocated_before integer not null,
  stats_before jsonb not null,
  career_points_before integer not null
 ) on commit drop;

 with eligible as(
  select r.id,r.horse_id,r.show_id,r.placement,
   case r.placement when 1 then 3 when 2 then 2 when 3 then 1 end as points
  from public.player_show_results as r
  join public.player_shows as sh on sh.id=r.show_id
  left join public.horse_ap_awards as a on a.show_result_id=r.id
  where sh.status='complete'
   and not coalesce(sh.is_private,false)
   and not coalesce(sh.is_admin_qa,false)
   and coalesce(sh.processed_at,r.created_at)<v_run.activation_at
   and r.placement between 1 and 3
   and a.show_result_id is null
 ),inserted as(
  insert into public.horse_ap_awards(horse_id,show_id,show_result_id,placement,points)
  select e.horse_id,e.show_id,e.id,e.placement,e.points from eligible as e
  on conflict(show_result_id)do nothing
  returning horse_id,points
 ),per_horse as(
  select i.horse_id,sum(i.points)::integer as points,count(*)::integer as result_count
  from inserted as i group by i.horse_id
 )
 insert into historical_ap_credits
 select p.horse_id,p.points,p.result_count,h.allocatable_points,h.lifetime_ap_earned,
  h.lifetime_ap_allocated,h.stats,h.career_points
 from per_horse as p join public.horses as h on h.id=p.horse_id;

 select coalesce(sum(result_count),0),count(*),coalesce(sum(points),0)
 into v_credited_results,v_credited_horses,v_credited_ap
 from historical_ap_credits;

 if v_credited_results<>v_run.eligible_results
  or v_credited_horses<>v_run.horses
  or v_credited_ap<>v_run.total_ap then
  raise exception 'Historical AP apply no longer matches validated dry run';
 end if;

 update public.horses as h set
  allocatable_points=h.allocatable_points+c.points,
  lifetime_ap_earned=h.lifetime_ap_earned+c.points
 from historical_ap_credits as c where h.id=c.horse_id;

 if exists(
  select 1 from historical_ap_credits as c join public.horses as h on h.id=c.horse_id
  where h.allocatable_points<>c.available_before+c.points
   or h.lifetime_ap_earned<>c.earned_before+c.points
   or h.lifetime_ap_allocated<>c.allocated_before
   or h.stats<>c.stats_before
   or h.career_points<>c.career_points_before
 )then raise exception 'Historical AP horse-balance verification failed';end if;

 -- A literal second eligibility pass proves the same result rows cannot award twice.
 select coalesce(sum(case r.placement when 1 then 3 when 2 then 2 when 3 then 1 else 0 end),0)
 into v_second_run_ap
 from public.player_show_results as r
 join public.player_shows as sh on sh.id=r.show_id
 left join public.horse_ap_awards as a on a.show_result_id=r.id
 where sh.status='complete'
  and not coalesce(sh.is_private,false)
  and not coalesce(sh.is_admin_qa,false)
  and coalesce(sh.processed_at,r.created_at)<v_run.activation_at
  and r.placement between 1 and 3
  and a.show_result_id is null;
 if v_second_run_ap<>0 then raise exception 'Historical AP second pass was not idempotent';end if;

 update public.historical_ap_reconciliations set
  status='applied',credited_results=v_credited_results,credited_horses=v_credited_horses,
  credited_ap=v_credited_ap,second_run_ap=v_second_run_ap,applied_at=now()
 where id=v_run.id;
end$$;
