-- Read-only historical AP reconciliation report. This migration intentionally performs no writes.
do $$
declare
 v_activation timestamptz;
 v_shows integer;
 v_eligible integer;
 v_skipped integer;
 v_total integer;
 v_horses integer;
 v_detail_total integer;
 v_report jsonb;
begin
 select c.updated_at into strict v_activation from show_ap_config as c where c.id=true;

 with historical as(
  select r.id,r.horse_id,r.placement
  from player_show_results as r
  join player_shows as sh on sh.id=r.show_id
  where sh.status='complete'
   and not coalesce(sh.is_private,false)
   and not coalesce(sh.is_admin_qa,false)
   and coalesce(sh.processed_at,r.created_at)<v_activation
   and r.placement between 1 and 3
 )
 select count(*)filter(where a.show_result_id is null),count(*)filter(where a.show_result_id is not null),
  coalesce(sum(case h.placement when 1 then 3 when 2 then 2 when 3 then 1 else 0 end)filter(where a.show_result_id is null),0),
  count(distinct h.horse_id)filter(where a.show_result_id is null)
 into v_eligible,v_skipped,v_total,v_horses
 from historical as h left join horse_ap_awards as a on a.show_result_id=h.id;

 select count(distinct sh.id)into v_shows
 from player_shows as sh
 where sh.status='complete'
  and not coalesce(sh.is_private,false)
  and not coalesce(sh.is_admin_qa,false)
  and sh.processed_at<v_activation;

 with eligible as(
  select r.horse_id,r.placement
  from player_show_results as r
  join player_shows as sh on sh.id=r.show_id
  left join horse_ap_awards as a on a.show_result_id=r.id
  where sh.status='complete'
   and not coalesce(sh.is_private,false)
   and not coalesce(sh.is_admin_qa,false)
   and coalesce(sh.processed_at,r.created_at)<v_activation
   and r.placement between 1 and 3
   and a.show_result_id is null
 ),per_horse as(
  select h.id,h.name,
   count(*)filter(where e.placement=1)::integer as wins,
   count(*)filter(where e.placement=2)::integer as seconds,
   count(*)filter(where e.placement=3)::integer as thirds,
   sum(case e.placement when 1 then 3 when 2 then 2 when 3 then 1 else 0 end)::integer as historical_ap
  from eligible as e join horses as h on h.id=e.horse_id group by h.id,h.name
 )
 select coalesce(jsonb_agg(jsonb_build_object('horse_id',p.id,'horse',p.name,'wins',p.wins,'seconds',p.seconds,'thirds',p.thirds,'historical_ap',p.historical_ap)order by p.historical_ap desc,p.name),'[]'::jsonb),coalesce(sum(p.historical_ap),0)
 into v_report,v_detail_total from per_horse as p;

 if v_total<>v_detail_total then raise exception 'Historical AP dry-run consistency failure: result total %, horse total %',v_total,v_detail_total;end if;
 if jsonb_array_length(v_report)<>v_horses then raise exception 'Historical AP dry-run horse count mismatch';end if;

 raise notice 'HISTORICAL_AP_DRY_RUN activation=% shows=% eligible_top3=% already_awarded=% horses=% total_ap=%',v_activation,v_shows,v_eligible,v_skipped,v_horses,v_total;
 raise notice 'HISTORICAL_AP_BY_HORSE %',v_report;
end$$;
