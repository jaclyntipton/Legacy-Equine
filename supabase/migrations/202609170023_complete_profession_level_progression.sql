-- Complete the shared Study -> Test -> Certificate -> Rates -> Services ->
-- Advancement state machine for every profession and certification level.

create table public.profession_level_requirements (
  profession_id text not null references public.professions(id) on delete cascade,
  level integer not null references public.certification_levels(level),
  required_services integer not null check (required_services > 0),
  primary key (profession_id, level)
);

insert into public.profession_level_requirements(profession_id,level,required_services)
select p.id,l.level,case l.level when 1 then 5 else l.required_services::integer end
from public.professions p cross join public.certification_levels l;

create table public.player_profession_certifications (
  stable_id uuid not null references public.stables(id) on delete cascade,
  profession_id text not null references public.professions(id) on delete cascade,
  level integer not null references public.certification_levels(level),
  granted_at timestamptz not null default now(),
  attempt_id uuid references public.certification_attempts(id),
  primary key (stable_id, profession_id, level)
);

create table public.profession_career_completions (
  stable_id uuid not null references public.stables(id) on delete cascade,
  profession_id text not null references public.professions(id) on delete cascade,
  completed_at timestamptz not null default now(),
  primary key (stable_id, profession_id)
);

alter table public.profession_level_requirements enable row level security;
alter table public.player_profession_certifications enable row level security;
alter table public.profession_career_completions enable row level security;
create policy "profession requirements readable" on public.profession_level_requirements for select using(true);
create policy "own profession certificates readable" on public.player_profession_certifications for select using(stable_id=auth.uid());
create policy "own career completion readable" on public.profession_career_completions for select using(stable_id=auth.uid());

-- Preserve certificates already earned under the previous max-level-only model.
insert into public.player_profession_certifications(stable_id,profession_id,level,granted_at,attempt_id)
select pp.stable_id,pp.profession_id,l.level,
 coalesce(a.created_at,pp.certified_at,pp.enrolled_at),a.id
from public.player_professions pp
cross join lateral generate_series(1,pp.certification_level) l(level)
left join lateral (
 select ca.id,ca.created_at from public.certification_attempts ca
 where ca.stable_id=pp.stable_id and ca.profession_id=pp.profession_id
   and ca.level=l.level and ca.passed
 order by ca.created_at limit 1
) a on true
on conflict do nothing;

create or replace function public.legitimate_profession_service_count(target_stable uuid,target_profession text)
returns integer language sql security definer set search_path=public stable as $$
 select count(*)::integer from horse_service_records
 where provider_id=target_stable and profession_id=target_profession
   and status='completed' and not self_service and price>0
$$;

create or replace function public.take_certification_test(target_profession text,target_level integer,submitted_answers jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare pp player_professions;cfg certification_levels;latest timestamptz;correct int;total int;score numeric;passed boolean;s stables;pname text;attempt_id uuid;
begin
 select * into pp from player_professions where stable_id=auth.uid() and profession_id=target_profession for update;
 if not found then raise exception 'Enroll first';end if;
 if target_level<>pp.certification_level+1 then raise exception 'Invalid certification level';end if;
 if not exists(select 1 from player_study_progress where stable_id=auth.uid() and profession_id=target_profession and level=target_level and completed_at is not null)then raise exception 'Complete Study first';end if;
 select * into cfg from certification_levels where level=target_level;
 select max(created_at)into latest from certification_attempts where stable_id=auth.uid()and profession_id=target_profession and level=target_level;
 if latest is not null and latest>now()-make_interval(mins=>cfg.retry_cooldown_minutes)then raise exception 'Certification retest cooldown is active';end if;
 select * into s from stables where id=auth.uid()for update;
 if s.balance<cfg.exam_fee then raise exception 'You need % more LED for this exam',cfg.exam_fee-s.balance;end if;
 select name into pname from professions where id=target_profession;
 select count(*),count(*)filter(where(submitted_answers->>q.id::text)::int=q.correct_index)into total,correct from certification_questions q where q.profession_id=target_profession and q.level=target_level and q.active;
 if total=0 then raise exception 'No active questions configured';end if;
 score:=round(correct::numeric/total*100,2);passed:=score>=cfg.passing_score;
 update stables set balance=balance-cfg.exam_fee where id=s.id;
 insert into currency_ledger(stable_id,amount,reason)values(s.id,-cfg.exam_fee,pname||' certification exam fee');
 insert into certification_attempts(stable_id,profession_id,level,score,passed,answers)values(s.id,target_profession,target_level,score,passed,submitted_answers)returning id into attempt_id;
 perform allocate_profession_fee(s.id,cfg.exam_fee,pname||' certification exam fee',attempt_id);
 if passed then
  update player_professions set certification_level=target_level,certified_at=now(),available=true where stable_id=s.id and profession_id=target_profession;
  insert into player_profession_certifications(stable_id,profession_id,level,attempt_id)values(s.id,target_profession,target_level,attempt_id)on conflict do nothing;
 end if;
 return jsonb_build_object('score',score,'passed',passed,'passing_score',cfg.passing_score,'fee_paid',cfg.exam_fee,'certificate_granted',passed,'certification_level',target_level);
end$$;

create or replace function public.advance_profession_career(target_profession text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare pp player_professions;target integer;required integer;completed integer;
begin
 select * into pp from player_professions where stable_id=auth.uid()and profession_id=target_profession for update;
 if not found then raise exception 'Enroll first';end if;
 if pp.certification_level=0 then raise exception 'Complete the Basic certification test first';end if;
 if not exists(select 1 from player_profession_certifications where stable_id=auth.uid()and profession_id=target_profession and level=pp.certification_level)then raise exception 'Current level certificate is required';end if;
 select required_services into required from profession_level_requirements where profession_id=target_profession and level=pp.certification_level;
 completed:=legitimate_profession_service_count(auth.uid(),target_profession);
 if completed<required then raise exception 'Complete % legitimate paid services before advancing',required;end if;
 if pp.certification_level=4 then
  insert into profession_career_completions(stable_id,profession_id)values(auth.uid(),target_profession)on conflict do nothing;
  return jsonb_build_object('completed',true,'level',4);
 end if;
 target:=pp.certification_level+1;
 insert into profession_career_advancements(stable_id,profession_id,target_level)values(auth.uid(),target_profession,target)on conflict do nothing;
 insert into player_study_progress(stable_id,profession_id,level)values(auth.uid(),target_profession,target)on conflict do nothing;
 return jsonb_build_object('completed',false,'level',target);
end$$;

create or replace function public.complete_profession_study(target_profession text,target_level integer)
returns void language plpgsql security definer set search_path=public as $$
declare pp player_professions;
begin
 select * into pp from player_professions where stable_id=auth.uid()and profession_id=target_profession;
 if not found then raise exception 'Enroll first';end if;
 if target_level<>pp.certification_level+1 then raise exception 'Complete certification levels in order';end if;
 if not exists(select 1 from profession_career_advancements where stable_id=auth.uid()and profession_id=target_profession and profession_career_advancements.target_level=$2)then raise exception 'Advance to this certification level first';end if;
 insert into player_study_progress(stable_id,profession_id,level,completed_at)values(auth.uid(),target_profession,target_level,now())on conflict(stable_id,profession_id,level)do update set completed_at=now();
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
   'certified_levels',coalesce((select jsonb_agg(c.level order by c.level)from player_profession_certifications c where c.stable_id=auth.uid()and c.profession_id=p.id),'[]'::jsonb)
  )order by p.sort_order),'[]'))
 from professions p
 left join player_professions pp on pp.profession_id=p.id and pp.stable_id=auth.uid()
 left join certification_levels cl on cl.level=pp.certification_level
 left join certification_levels nextcl on nextcl.level=coalesce(pp.certification_level,0)+1
 left join profession_level_requirements req on req.profession_id=p.id and req.level=greatest(coalesce(pp.certification_level,0),1)
 left join player_study_progress sp on sp.stable_id=auth.uid()and sp.profession_id=p.id and sp.level=coalesce(pp.certification_level,0)+1
 left join profession_career_advancements adv on adv.stable_id=auth.uid()and adv.profession_id=p.id and adv.target_level=case when coalesce(pp.certification_level,0)=0 then 1 else pp.certification_level+1 end
 left join profession_career_completions done on done.stable_id=auth.uid()and done.profession_id=p.id
 left join lateral(select legitimate_profession_service_count(auth.uid(),p.id)completed)legit on true
 where p.active
$$;

do $$ declare missing text;
begin
 select string_agg(p.id||'/'||l.level,', ')into missing from professions p cross join certification_levels l left join profession_level_requirements r on r.profession_id=p.id and r.level=l.level where p.active and(r.required_services is null or r.required_services<=0);
 if missing is not null then raise exception 'Incomplete profession progression paths: %',missing;end if;
end$$;

revoke all on function public.legitimate_profession_service_count(uuid,text) from public;
grant execute on function public.take_certification_test(text,integer,jsonb),public.advance_profession_career(text),public.complete_profession_study(text,integer),public.get_profession_dashboard() to authenticated;
