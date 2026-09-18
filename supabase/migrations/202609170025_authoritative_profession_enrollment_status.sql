-- Enrollment exists as soon as player_professions exists; certification_level=0
-- means enrolled in Basic Study, never "Not Enrolled".
create or replace function public.get_profession_dashboard() returns jsonb
language sql security definer set search_path=public stable as $$
 select jsonb_build_object(
  'owner_qa_access',public.has_profession_qa_access(),
  'can_enroll',not exists(select 1 from player_professions where stable_id=auth.uid()and certification_level<4),
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
    when coalesce(legit.completed,0)>=coalesce(req.required_services,0)then'Ready to Advance'
    else cl.name||' Certified · '||coalesce(legit.completed,0)||'/'||coalesce(req.required_services,0)||' Services'end,
   'client_services',coalesce(pp.lifetime_client_services,0),'self_services',coalesce(pp.lifetime_self_services,0),'qualifying_credit',coalesce(legit.completed,0),
   'study_completed',sp.completed_at is not null,'required_services',coalesce(req.required_services,0),'exam_fee',coalesce(nextcl.exam_fee,0),
   'next_level',case when coalesce(pp.certification_level,0)<4 then coalesce(pp.certification_level,0)+1 end,
   'next_level_advanced',case when coalesce(pp.certification_level,0)=0 then adv.target_level is not null when pp.certification_level=4 then done.completed_at is not null else adv.target_level is not null end,
   'career_completed',done.completed_at is not null,'rates_configured',rates.completed_at is not null,
   'certified_levels',coalesce((select jsonb_agg(c.level order by c.level)from player_profession_certifications c where c.stable_id=auth.uid()and c.profession_id=p.id),'[]'::jsonb),
   'career_state',case
    when pp.stable_id is null then'NOT_ENROLLED'
    when pp.certification_level=0 and sp.completed_at is null then'STUDY_REQUIRED'
    when pp.certification_level=0 then'TEST_AVAILABLE'
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
