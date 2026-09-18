-- Certification retry cooldowns remain authoritative for players. A separately
-- audited QA permission may bypass only the wait attached to one failed attempt.

create table if not exists public.profession_certification_cooldown_bypasses(
 id uuid primary key default gen_random_uuid(),
 stable_id uuid not null references public.stables(id) on delete cascade,
 profession_id text not null references public.professions(id) on delete cascade,
 certification_level integer not null references public.certification_levels(level),
 failed_attempt_id uuid not null unique references public.certification_attempts(id) on delete cascade,
 actor_id uuid not null references public.stables(id),
 created_at timestamptz not null default now()
);
alter table public.profession_certification_cooldown_bypasses enable row level security;
drop policy if exists "own certification cooldown bypasses readable" on public.profession_certification_cooldown_bypasses;
create policy "own certification cooldown bypasses readable" on public.profession_certification_cooldown_bypasses
 for select using(stable_id=auth.uid() or public.has_admin_permission('professions.qa_bypass_certification_cooldown'));

create or replace function public.get_profession_certification_cooldown(target_profession text,target_level integer)
returns jsonb language plpgsql security definer set search_path=public stable as $$
declare cfg certification_levels;attempt certification_attempts;bypassed boolean:=false;available_at timestamptz;active boolean:=false;
begin
 select * into cfg from certification_levels where level=target_level;
 if not found then raise exception 'Certification level not found';end if;
 select * into attempt from certification_attempts
  where stable_id=auth.uid()and profession_id=target_profession and level=target_level
  order by created_at desc limit 1;
 if attempt.id is not null then
  bypassed:=exists(select 1 from profession_certification_cooldown_bypasses b where b.failed_attempt_id=attempt.id);
  available_at:=attempt.created_at+make_interval(mins=>cfg.retry_cooldown_minutes);
  active:=not attempt.passed and not bypassed and available_at>now();
 end if;
 return jsonb_build_object(
  'active',active,'available_at',available_at,'retry_cooldown_minutes',cfg.retry_cooldown_minutes,
  'failed_attempt_id',case when attempt.id is not null and not attempt.passed then attempt.id end,
  'can_bypass',public.has_admin_permission('professions.qa_bypass_certification_cooldown')
 );
end$$;

create or replace function public.admin_bypass_profession_certification_cooldown(target_profession text,target_level integer)
returns jsonb language plpgsql security definer set search_path=public as $$
declare cfg certification_levels;attempt certification_attempts;entry profession_certification_cooldown_bypasses;
begin
 if not public.has_admin_permission('professions.qa_bypass_certification_cooldown')then raise exception 'Profession certification cooldown QA permission required';end if;
 select * into cfg from certification_levels where level=target_level;
 if not found then raise exception 'Certification level not found';end if;
 select * into attempt from certification_attempts
  where stable_id=auth.uid()and profession_id=target_profession and level=target_level
  order by created_at desc limit 1 for update;
 if attempt.id is null or attempt.passed then raise exception 'No failed certification cooldown is available to bypass';end if;
 if attempt.created_at+make_interval(mins=>cfg.retry_cooldown_minutes)<=now()then raise exception 'Certification cooldown is no longer active';end if;
 insert into profession_certification_cooldown_bypasses(stable_id,profession_id,certification_level,failed_attempt_id,actor_id)
 values(auth.uid(),target_profession,target_level,attempt.id,auth.uid())
 on conflict(failed_attempt_id)do update set actor_id=excluded.actor_id
 returning * into entry;
 insert into admin_audit_log(actor_id,action_type,system,target_type,target_id,details)
 values(auth.uid(),'profession.qa_certification_cooldown_bypass','professions','certification_attempt',attempt.id::text,
  jsonb_build_object('account',auth.uid(),'profession',target_profession,'certification_level',target_level,'failed_attempt_id',attempt.id,'failed_score',attempt.score,'original_result','FAILED'));
 return jsonb_build_object('bypassed',true,'failed_attempt_id',attempt.id,'failed_result_preserved',not attempt.passed);
end$$;

create or replace function public.take_certification_test(target_profession text,target_level integer,submitted_answers jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare pp player_professions;cfg certification_levels;latest certification_attempts;cooldown_bypassed boolean:=false;correct int;total int;score numeric;passed boolean;s stables;pname text;attempt_id uuid;
begin
 select * into pp from player_professions where stable_id=auth.uid()and profession_id=target_profession for update;
 if not found then raise exception 'Enroll first';end if;
 if target_level<>pp.certification_level+1 then raise exception 'Invalid certification level';end if;
 if not exists(select 1 from player_study_progress where stable_id=auth.uid()and profession_id=target_profession and level=target_level and completed_at is not null)then raise exception 'Complete Study first';end if;
 select * into cfg from certification_levels where level=target_level;
 select * into latest from certification_attempts where stable_id=auth.uid()and profession_id=target_profession and level=target_level order by created_at desc limit 1;
 if latest.id is not null then cooldown_bypassed:=exists(select 1 from profession_certification_cooldown_bypasses b where b.failed_attempt_id=latest.id);end if;
 if latest.id is not null and latest.created_at>now()-make_interval(mins=>cfg.retry_cooldown_minutes)and not cooldown_bypassed then raise exception 'Certification retest cooldown is active';end if;
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

create or replace function public.admin_update_profession_retry_cooldown(target_level integer,cooldown_minutes integer)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not public.has_admin_permission('admin.professions.edit')then raise exception 'Profession balancing permission required';end if;
 if cooldown_minutes<0 or cooldown_minutes>10080 then raise exception 'Certification retry cooldown must be between 0 and 10,080 minutes';end if;
 update certification_levels set retry_cooldown_minutes=cooldown_minutes where level=target_level;
 if not found then raise exception 'Certification level not found';end if;
 insert into admin_audit_log(actor_id,action_type,system,target_type,target_id,details)
 values(auth.uid(),'profession.certification_retry_cooldown_updated','professions','certification_level',target_level::text,jsonb_build_object('retry_cooldown_minutes',cooldown_minutes));
end$$;

revoke all on function public.admin_bypass_profession_certification_cooldown(text,integer),public.admin_update_profession_retry_cooldown(integer,integer)from public;
grant execute on function public.get_profession_certification_cooldown(text,integer),public.admin_bypass_profession_certification_cooldown(text,integer),public.admin_update_profession_retry_cooldown(integer,integer),public.take_certification_test(text,integer,jsonb)to authenticated;
