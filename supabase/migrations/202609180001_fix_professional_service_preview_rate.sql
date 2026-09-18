-- Keep Professional Market eligibility and review on the provider's saved rate.
create or replace function public.preview_professional_service(
 target_horse uuid,
 target_provider uuid,
 target_service text,
 owner_qa boolean default false
)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
 h horses;svc service_catalog;provider player_professions;
 offering player_service_offerings;provider_stable stables;wellness jsonb;
 v_provider_level integer;v_service_price integer;qa boolean;
 eligible boolean:=true;reason text;next_at timestamptz;age numeric;
 fraction numeric;window_key text;last_at timestamptz;effect_text text;
begin
 select hr.* into h from horses hr where hr.id=target_horse;
 if not found or h.owner_id<>auth.uid() then raise exception 'Horse not found or not owned';end if;
 select sc.* into svc from service_catalog sc where sc.id=target_service and sc.active;
 if not found then raise exception 'Service unavailable';end if;
 select st.* into provider_stable from stables st where st.id=target_provider;
 if not found then raise exception 'Provider unavailable';end if;
 qa:=owner_qa and public.is_owner_account() and target_provider=auth.uid();
 if owner_qa and not qa then raise exception 'Owner Account #1 QA access required';end if;
 if qa then v_provider_level:=4;v_service_price:=0;
 else
  select pp.* into provider from player_professions pp where pp.stable_id=target_provider and pp.profession_id=svc.profession_id;
  select pso.* into offering from player_service_offerings pso where pso.stable_id=target_provider and pso.service_id=svc.id and pso.enabled;
  if not found or provider.stable_id is null or provider.certification_level<svc.minimum_level or not provider.available then raise exception 'This service is not currently available';end if;
  v_provider_level:=provider.certification_level;v_service_price:=offering.price;
  if v_service_price not between svc.min_price and svc.max_price then raise exception 'Provider rate is outside the configured range';end if;
 end if;
 age:=horse_game_age(h.birth_date);
 select max(hsr.completed_at) into last_at from horse_service_records hsr where hsr.horse_id=h.id and hsr.service_id=svc.id and hsr.status='completed';
 if last_at is not null and last_at>now()-make_interval(hours=>svc.cooldown_hours) then eligible:=false;reason:='This horse is still in the service cooldown';next_at:=last_at+make_interval(hours=>svc.cooldown_hours);end if;
 if svc.profession_id='trainer' then
  if age<2 then eligible:=false;reason:='Training services become available at age 2';next_at:=now()+(((2-age)*(select hgc.real_days_per_horse_year from horse_game_config hgc where hgc.id=true))::text||' days')::interval;
  elsif h.last_trained_at is not null and h.last_trained_at>now()-interval '20 hours' then eligible:=false;reason:='Training cooldown active';next_at:=h.last_trained_at+interval '20 hours';end if;
 elsif svc.profession_id='veterinarian' then
  fraction:=age-floor(age);window_key:=floor(age)::integer||case when fraction<.5 then ':first'else':second'end;
  if exists(select 1 from horse_service_records hsr where hsr.horse_id=h.id and hsr.profession_id='veterinarian' and hsr.status='completed' and hsr.care_window=window_key) then eligible:=false;reason:='Routine Vet care is already complete for this half of the horse-year';next_at:=now()+(((case when fraction<.5 then .5-fraction else 1-fraction end)*(select hgc.real_days_per_horse_year from horse_game_config hgc where hgc.id=true))::text||' days')::interval;end if;
 elsif svc.profession_id in('farrier','massage') then
  window_key:=le_week_start(now())::text;
  if exists(select 1 from horse_service_records hsr where hsr.horse_id=h.id and hsr.profession_id=svc.profession_id and hsr.status='completed' and hsr.care_window=window_key) then eligible:=false;reason:=case when svc.profession_id='farrier'then'Farrier care is already complete for this LE week'else'Massage care is already complete for this LE week'end;next_at:=((le_week_start(now())+7)::timestamp at time zone 'America/New_York');end if;
 end if;
 if svc.wellness_component is not null then wellness:=get_horse_wellness(h.id);effect_text:='Restore up to '||coalesce((svc.restoration_by_level->>v_provider_level::text)::integer,0)||' '||initcap(svc.wellness_component)||' (maximum 100)';
 else effect_text:='Permanent Development: '||(select string_agg(j.key||' +'||j.value,' · ' order by j.key)from jsonb_each_text(svc.effect)j);end if;
 return jsonb_build_object(
  'eligible',eligible,'reason',reason,'next_eligible',next_at,'horse_name',h.name,
  'provider_name',provider_stable.name||' #'||provider_stable.account_number,
  'service_name',svc.name,'profession_id',svc.profession_id,
  'certification',case when qa then'Owner QA'else(select cl.name from certification_levels cl where cl.level=v_provider_level)end,
  'price',case when qa then 0 else v_service_price end,'owner_qa',qa,
  'current_state',case when svc.wellness_component is not null then jsonb_build_object(initcap(svc.wellness_component),wellness->svc.wellness_component,'Readiness',wellness->'readiness')else jsonb_build_object('Age',round(age,2),'Developed stats',h.stats)end,
  'expected_effect',effect_text
 );
end$$;

revoke all on function public.preview_professional_service(uuid,uuid,text,boolean) from public;
grant execute on function public.preview_professional_service(uuid,uuid,text,boolean) to authenticated;
