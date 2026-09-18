-- Owner QA may enter multiple real careers, but Live Gameplay still requires an
-- atomic paid enrollment. Service-gate overrides are explicit and auditable;
-- they never manufacture service or ledger rows and never change honest counts.

create table if not exists public.profession_advancement_overrides(
 id uuid primary key default gen_random_uuid(),
 stable_id uuid not null references public.stables(id) on delete cascade,
 profession_id text not null references public.professions(id) on delete cascade,
 certification_level integer not null references public.certification_levels(level),
 configured_requirement integer not null,
 actual_service_count integer not null,
 actor_id uuid not null references public.stables(id),
 reason text not null,
 created_at timestamptz not null default now(),
 unique(stable_id,profession_id,certification_level)
);
alter table public.profession_advancement_overrides enable row level security;
drop policy if exists "own profession QA overrides readable" on public.profession_advancement_overrides;
create policy "own profession QA overrides readable" on public.profession_advancement_overrides
 for select using(stable_id=auth.uid()or public.has_admin_permission('professions.qa_progression_override'));

create or replace function public.enroll_profession(target_profession text)returns void
language plpgsql security definer set search_path=public as $$
declare p professions;s stables;
begin
 select * into s from stables where id=auth.uid()for update;
 if not found then raise exception 'Stable account not found';end if;
 if exists(select 1 from player_professions where stable_id=s.id and profession_id=target_profession)then raise exception 'You are already permanently enrolled';end if;
 if not public.is_owner_account(s.id)and exists(select 1 from player_professions where stable_id=s.id and certification_level<4)then raise exception 'Complete your current career through Professional before enrolling in another';end if;
 select * into p from professions where id=target_profession and active;
 if p.id is null then raise exception 'Profession not found';end if;
 if s.balance<p.enrollment_fee then raise exception 'You need % LED to enroll',p.enrollment_fee;end if;
 update stables set balance=balance-p.enrollment_fee where id=s.id;
 insert into currency_ledger(stable_id,amount,reason)values(s.id,-p.enrollment_fee,p.name||' enrollment fee');
 perform allocate_profession_fee(s.id,p.enrollment_fee,p.name||' enrollment fee');
 insert into player_professions(stable_id,profession_id)values(s.id,p.id);
 insert into player_study_progress(stable_id,profession_id,level)values(s.id,p.id,1)on conflict do nothing;
end$$;

create or replace function public.admin_mark_profession_requirement_complete(target_profession text,target_level integer,p_reason text default 'QA/testing')
returns jsonb language plpgsql security definer set search_path=public as $$
declare pp player_professions;required integer;actual integer;result profession_advancement_overrides;
begin
 if not public.has_admin_permission('professions.qa_progression_override')then raise exception 'Profession QA progression override permission required';end if;
 select * into pp from player_professions where stable_id=auth.uid()and profession_id=target_profession for update;
 if not found then raise exception 'Enroll first';end if;
 if target_level<>pp.certification_level or target_level not between 1 and 4 then raise exception 'Override must match the current certified level';end if;
 if not exists(select 1 from player_profession_certifications where stable_id=auth.uid()and profession_id=target_profession and level=target_level)then raise exception 'Current level certificate is required';end if;
 select required_services into required from profession_level_requirements where profession_id=target_profession and level=target_level;
 if required is null then raise exception 'Service requirement not configured';end if;
 actual:=public.legitimate_profession_service_count(auth.uid(),target_profession,target_level);
 insert into profession_advancement_overrides(stable_id,profession_id,certification_level,configured_requirement,actual_service_count,actor_id,reason)
 values(auth.uid(),target_profession,target_level,required,actual,auth.uid(),left(coalesce(nullif(trim(p_reason),''),'QA/testing'),500))
 on conflict(stable_id,profession_id,certification_level)do update set configured_requirement=excluded.configured_requirement,actual_service_count=excluded.actual_service_count,actor_id=excluded.actor_id,reason=excluded.reason,created_at=now()
 returning * into result;
 insert into admin_audit_log(actor_id,action_type,system,target_type,target_id,details)
 values(auth.uid(),'profession.qa_progression_override','professions','profession',target_profession,
  jsonb_build_object('account',auth.uid(),'profession',target_profession,'certification_level',target_level,'configured_requirement',required,'actual_service_count',actual,'reason',result.reason));
 return jsonb_build_object('profession',target_profession,'level',target_level,'configured_requirement',required,'actual_service_count',actual,'overridden',true);
end$$;

create or replace function public.advance_profession_career(target_profession text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare pp player_professions;target integer;required integer;completed integer;overridden boolean;
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
 overridden:=exists(select 1 from profession_advancement_overrides o where o.stable_id=auth.uid()and o.profession_id=target_profession and o.certification_level=pp.certification_level);
 if completed<required and not overridden then raise exception 'Complete % legitimate paid client services before advancing',required;end if;
 target:=pp.certification_level+1;
 insert into profession_career_advancements(stable_id,profession_id,target_level)values(auth.uid(),target_profession,target)on conflict do nothing;
 insert into player_study_progress(stable_id,profession_id,level)values(auth.uid(),target_profession,target)on conflict do nothing;
 return jsonb_build_object('completed',false,'level',target,'actual_services',completed,'requirement_overridden',overridden);
end$$;

create or replace function public.get_profession_dashboard()returns jsonb
language sql security definer set search_path=public stable as $$
 select jsonb_build_object(
  'owner_qa_access',public.has_profession_qa_access(),
  'qa_progression_override_access',public.has_admin_permission('professions.qa_progression_override'),
  'can_enroll',public.is_owner_account()or not exists(select 1 from player_professions where stable_id=auth.uid()and certification_level<4),
  'professions',coalesce(jsonb_agg(jsonb_build_object(
   'id',p.id,'name',p.name,'description',p.description,'enrollment_fee',p.enrollment_fee,
   'enrolled',pp.stable_id is not null,'level',coalesce(pp.certification_level,0),'level_name',coalesce(cl.name,'Not enrolled'),'available',coalesce(pp.available,false),
   'status_label',case
    when pp.stable_id is null then'Not Enrolled'
    when done.completed_at is not null then'Career Complete'
    when pp.certification_level=0 and sp.completed_at is null then'Enrolled · Basic Study'
    when pp.certification_level=0 then'Enrolled · Basic Test'
    when rates.completed_at is null then cl.name||' Certified · Rates Required'
    when adv.target_level is not null and sp.completed_at is null then nextcl.name||' Study'
    when adv.target_level is not null then nextcl.name||' Test'
    when coalesce(legit.completed,0)>=coalesce(req.required_services,0)or ov.id is not null then'Ready to Advance'
    else cl.name||' Certified · '||coalesce(legit.completed,0)||'/'||coalesce(req.required_services,0)||' Services'end,
   'client_services',coalesce(pp.lifetime_client_services,0),'self_services',coalesce(pp.lifetime_self_services,0),'qualifying_credit',coalesce(legit.completed,0),
   'study_completed',sp.completed_at is not null,'required_services',coalesce(req.required_services,0),'exam_fee',coalesce(nextcl.exam_fee,0),
   'next_level',case when coalesce(pp.certification_level,0)<4 then coalesce(pp.certification_level,0)+1 end,
   'next_level_advanced',case when coalesce(pp.certification_level,0)=0 then adv.target_level is not null when pp.certification_level=4 then done.completed_at is not null else adv.target_level is not null end,
   'career_completed',done.completed_at is not null,'rates_configured',rates.completed_at is not null,
   'requirement_overridden',ov.id is not null,
   'certified_levels',coalesce((select jsonb_agg(c.level order by c.level)from player_profession_certifications c where c.stable_id=auth.uid()and c.profession_id=p.id),'[]'::jsonb),
   'career_state',case
    when pp.stable_id is null then'NOT_ENROLLED'
    when pp.certification_level=0 and sp.completed_at is null then'STUDY_REQUIRED'
    when pp.certification_level=0 then'TEST_AVAILABLE'
    when pp.certification_level=4 and rates.completed_at is not null then'PROFESSIONAL_CERTIFIED'
    when rates.completed_at is null then'RATES_REQUIRED'
    when adv.target_level is not null and sp.completed_at is null then'NEXT_LEVEL_STUDY'
    when adv.target_level is not null then'TEST_AVAILABLE'
    when coalesce(legit.completed,0)>=coalesce(req.required_services,0)or ov.id is not null then'ADVANCEMENT_AVAILABLE'
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
 left join profession_advancement_overrides ov on ov.stable_id=auth.uid()and ov.profession_id=p.id and ov.certification_level=pp.certification_level
 left join lateral(select legitimate_profession_service_count(auth.uid(),p.id,greatest(coalesce(pp.certification_level,0),1))completed)legit on true
 where p.active
$$;

revoke all on function public.admin_mark_profession_requirement_complete(text,integer,text)from public;
grant execute on function public.admin_mark_profession_requirement_complete(text,integer,text),public.enroll_profession(text),public.advance_profession_career(text),public.get_profession_dashboard()to authenticated;
