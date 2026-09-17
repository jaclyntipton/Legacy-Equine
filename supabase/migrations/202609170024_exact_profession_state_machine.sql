-- Persist Rates as a required post-certificate state and scope legitimate
-- client-service credit to the certification level at which it was earned.

create table public.profession_rate_setups (
  stable_id uuid not null references public.stables(id) on delete cascade,
  profession_id text not null references public.professions(id) on delete cascade,
  level integer not null references public.certification_levels(level),
  completed_at timestamptz not null default now(),
  primary key (stable_id, profession_id, level)
);

alter table public.profession_rate_setups enable row level security;
create policy "own profession rate setups readable" on public.profession_rate_setups
 for select using(stable_id=auth.uid());

create or replace function public.legitimate_profession_service_count(target_stable uuid,target_profession text,target_level integer)
returns integer language sql security definer set search_path=public stable as $$
 select count(*)::integer from horse_service_records
 where provider_id=target_stable and profession_id=target_profession
   and provider_level=target_level and status='completed'
   and not self_service and price>0
$$;

-- Preserve already-complete rate setups without treating a partial listing as
-- completion. Every service authorized at that level must have a valid active rate.
insert into public.profession_rate_setups(stable_id,profession_id,level,completed_at)
select pp.stable_id,pp.profession_id,l.level,coalesce(pp.certified_at,pp.enrolled_at)
from player_professions pp
cross join lateral generate_series(1,pp.certification_level)l(level)
join service_catalog sc on sc.profession_id=pp.profession_id and sc.active and sc.minimum_level<=l.level
left join player_service_offerings o on o.stable_id=pp.stable_id and o.service_id=sc.id and o.enabled and o.price between sc.min_price and sc.max_price
group by pp.stable_id,pp.profession_id,l.level,pp.certified_at,pp.enrolled_at
having count(*)=count(o.service_id)
on conflict do nothing;

-- Professional has no phantom fifth-level service gate. Its terminal active
-- career begins once the required Professional rates are configured.
delete from public.profession_career_completions c
where not exists(select 1 from profession_rate_setups r where r.stable_id=c.stable_id and r.profession_id=c.profession_id and r.level=4);
insert into public.profession_career_completions(stable_id,profession_id,completed_at)
select stable_id,profession_id,completed_at from profession_rate_setups where level=4
on conflict do nothing;

drop function public.set_service_offering(text,integer,boolean);
create function public.set_service_offering(target_service text,new_price integer,is_enabled boolean)
returns void language plpgsql security definer set search_path=public as $$
declare svc service_catalog;lvl integer;
begin
 select * into svc from service_catalog where id=target_service and active;
 select certification_level into lvl from player_professions where stable_id=auth.uid()and profession_id=svc.profession_id;
 if svc.id is null or coalesce(lvl,0)<svc.minimum_level then raise exception 'Certification does not qualify for this service';end if;
 if new_price not between svc.min_price and svc.max_price then raise exception 'Price must be between % and % LED',svc.min_price,svc.max_price;end if;
 insert into player_service_offerings(stable_id,service_id,price,enabled)values(auth.uid(),target_service,new_price,is_enabled)
 on conflict(stable_id,service_id)do update set price=new_price,enabled=is_enabled;
 if not exists(
  select 1 from service_catalog required
  left join player_service_offerings offered on offered.stable_id=auth.uid()and offered.service_id=required.id
  where required.profession_id=svc.profession_id and required.active and required.minimum_level<=lvl
    and(coalesce(offered.enabled,false)=false or offered.price not between required.min_price and required.max_price)
 )then
  insert into profession_rate_setups(stable_id,profession_id,level)values(auth.uid(),svc.profession_id,lvl)
  on conflict(stable_id,profession_id,level)do update set completed_at=now();
  if lvl=4 then insert into profession_career_completions(stable_id,profession_id)values(auth.uid(),svc.profession_id)on conflict do nothing;end if;
 else
  delete from profession_rate_setups where stable_id=auth.uid()and profession_id=svc.profession_id and level=lvl;
  if lvl=4 then delete from profession_career_completions where stable_id=auth.uid()and profession_id=svc.profession_id;end if;
 end if;
end$$;

create or replace function public.advance_profession_career(target_profession text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare pp player_professions;target integer;required integer;completed integer;
begin
 select * into pp from player_professions where stable_id=auth.uid()and profession_id=target_profession for update;
 if not found then raise exception 'Enroll first';end if;
 if pp.certification_level=0 then raise exception 'Complete the Basic certification test first';end if;
 if not exists(select 1 from player_profession_certifications where stable_id=auth.uid()and profession_id=target_profession and level=pp.certification_level)then raise exception 'Current level certificate is required';end if;
 if not exists(select 1 from profession_rate_setups where stable_id=auth.uid()and profession_id=target_profession and level=pp.certification_level)then raise exception 'Set every authorized service rate before advancing';end if;
 if pp.certification_level=4 then
  insert into profession_career_completions(stable_id,profession_id)values(auth.uid(),target_profession)on conflict do nothing;
  return jsonb_build_object('completed',true,'level',4);
 end if;
 select required_services into required from profession_level_requirements where profession_id=target_profession and level=pp.certification_level;
 completed:=legitimate_profession_service_count(auth.uid(),target_profession,pp.certification_level);
 if completed<required then raise exception 'Complete % legitimate paid client services before advancing',required;end if;
 target:=pp.certification_level+1;
 insert into profession_career_advancements(stable_id,profession_id,target_level)values(auth.uid(),target_profession,target)on conflict do nothing;
 insert into player_study_progress(stable_id,profession_id,level)values(auth.uid(),target_profession,target)on conflict do nothing;
 return jsonb_build_object('completed',false,'level',target);
end$$;

create or replace function public.get_profession_dashboard() returns jsonb
language sql security definer set search_path=public stable as $$
 select jsonb_build_object(
  'owner_qa_access',public.has_profession_qa_access(),
  'can_enroll',not exists(select 1 from player_professions where stable_id=auth.uid()and certification_level<4),
  'professions',coalesce(jsonb_agg(jsonb_build_object(
   'id',p.id,'name',p.name,'description',p.description,'enrollment_fee',p.enrollment_fee,
   'level',coalesce(pp.certification_level,0),'level_name',coalesce(cl.name,'Not enrolled'),'available',coalesce(pp.available,false),
   'client_services',coalesce(pp.lifetime_client_services,0),'self_services',coalesce(pp.lifetime_self_services,0),'qualifying_credit',coalesce(legit.completed,0),
   'study_completed',sp.completed_at is not null,'required_services',coalesce(req.required_services,0),'exam_fee',coalesce(nextcl.exam_fee,0),
   'next_level',case when coalesce(pp.certification_level,0)<4 then coalesce(pp.certification_level,0)+1 end,
   'next_level_advanced',case when coalesce(pp.certification_level,0)=0 then adv.target_level is not null when pp.certification_level=4 then done.completed_at is not null else adv.target_level is not null end,
   'career_completed',done.completed_at is not null,
   'rates_configured',rates.completed_at is not null,
   'certified_levels',coalesce((select jsonb_agg(c.level order by c.level)from player_profession_certifications c where c.stable_id=auth.uid()and c.profession_id=p.id),'[]'::jsonb),
   'career_state',case
    when coalesce(pp.certification_level,0)=0 and sp.completed_at is null then'STUDY_REQUIRED'
    when coalesce(pp.certification_level,0)=0 then'TEST_AVAILABLE'
    when pp.certification_level=4 and rates.completed_at is not null then'PROFESSIONAL_CERTIFIED'
    when rates.completed_at is null then'RATES_REQUIRED'
    when adv.target_level is not null and sp.completed_at is null then'NEXT_LEVEL_STUDY'
    when adv.target_level is not null then'TEST_AVAILABLE'
    when coalesce(legit.completed,0)>=coalesce(req.required_services,0)then'ADVANCEMENT_AVAILABLE'
    else'SERVICE_EXPERIENCE_REQUIRED'end
  )order by p.sort_order),'[]'))
 from professions p
 left join player_professions pp on pp.profession_id=p.id and pp.stable_id=auth.uid()
 left join certification_levels cl on cl.level=pp.certification_level
 left join certification_levels nextcl on nextcl.level=coalesce(pp.certification_level,0)+1
 left join profession_level_requirements req on req.profession_id=p.id and req.level=greatest(coalesce(pp.certification_level,0),1)
 left join player_study_progress sp on sp.stable_id=auth.uid()and sp.profession_id=p.id and sp.level=coalesce(pp.certification_level,0)+1
 left join profession_career_advancements adv on adv.stable_id=auth.uid()and adv.profession_id=p.id and adv.target_level=case when coalesce(pp.certification_level,0)=0 then 1 else pp.certification_level+1 end
 left join profession_rate_setups rates on rates.stable_id=auth.uid()and rates.profession_id=p.id and rates.level=pp.certification_level
 left join profession_career_completions done on done.stable_id=auth.uid()and done.profession_id=p.id
 left join lateral(select legitimate_profession_service_count(auth.uid(),p.id,greatest(coalesce(pp.certification_level,0),1))completed)legit on true
 where p.active
$$;

revoke all on function public.legitimate_profession_service_count(uuid,text,integer),public.set_service_offering(text,integer,boolean) from public;
grant execute on function public.set_service_offering(text,integer,boolean),public.advance_profession_career(text),public.get_profession_dashboard() to authenticated;
