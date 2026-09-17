-- Profession QA must be a server-authorized, read-only workspace. Normal career
-- enrollment/progression remains unchanged and never receives a client-only bypass.

create or replace function public.has_profession_qa_access(p_user uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public as $$
 select public.is_owner_account(p_user)
   or public.has_admin_permission('admin.professions.qa',p_user)
$$;

create or replace function public.open_profession_qa_career(target_profession text,target_level integer)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare result jsonb;
begin
 if not public.has_profession_qa_access() then raise exception 'Profession QA permission required';end if;
 if target_level not between 1 and 4 then raise exception 'Invalid certification level';end if;
 if not exists(select 1 from professions p where p.id=target_profession and p.active)then raise exception 'Profession not found';end if;
 select jsonb_build_object(
  'profession',target_profession,'level',target_level,'qa',true,'read_only',true,
  'study',(select to_jsonb(m)from study_modules m where m.profession_id=target_profession and m.level=target_level and m.active limit 1),
  'services',coalesce((select jsonb_agg(to_jsonb(s)order by s.name)from service_catalog s where s.profession_id=target_profession and s.minimum_level<=target_level and s.active),'[]'::jsonb)
 )into result;
 return result;
end$$;

create or replace function public.get_profession_qa_questions(target_profession text,target_level integer)
returns table(id uuid,prompt text,choices jsonb) language plpgsql stable security definer set search_path=public as $$
begin
 perform public.open_profession_qa_career(target_profession,target_level);
 return query select q.id,q.prompt,q.choices from certification_questions q
 where q.profession_id=target_profession and q.level=target_level and q.active
 order by random() limit(select c.test_length from certification_levels c where c.level=target_level);
end$$;

create or replace function public.get_profession_dashboard() returns jsonb language sql security definer set search_path=public stable as $$
 select jsonb_build_object(
  'owner_qa_access',public.has_profession_qa_access(),
  'can_enroll',not exists(select 1 from player_professions where stable_id=auth.uid() and certification_level<4),
  'professions',coalesce(jsonb_agg(jsonb_build_object(
   'id',p.id,'name',p.name,'description',p.description,'enrollment_fee',p.enrollment_fee,
   'level',coalesce(pp.certification_level,0),'level_name',coalesce(cl.name,'Not enrolled'),'available',coalesce(pp.available,false),
   'client_services',coalesce(pp.lifetime_client_services,0),'self_services',coalesce(pp.lifetime_self_services,0),'qualifying_credit',coalesce(pp.qualifying_credit,0),
   'study_completed',sp.completed_at is not null,'required_services',coalesce(nextcl.required_services,0),'exam_fee',coalesce(nextcl.exam_fee,0),
   'next_level',case when coalesce(pp.certification_level,0)<4 then coalesce(pp.certification_level,0)+1 end
  )order by p.sort_order),'[]'))
 from professions p
 left join player_professions pp on pp.profession_id=p.id and pp.stable_id=auth.uid()
 left join certification_levels cl on cl.level=pp.certification_level
 left join certification_levels nextcl on nextcl.level=coalesce(pp.certification_level,0)+1
 left join player_study_progress sp on sp.stable_id=auth.uid() and sp.profession_id=p.id and sp.level=coalesce(pp.certification_level,0)+1
 where p.active
$$;

create or replace function public.grade_profession_qa_test(target_profession text,target_level integer,submitted_answers jsonb)
returns jsonb language plpgsql security definer set search_path=public stable as $$
declare correct integer;total integer;passing numeric;
begin
 perform public.open_profession_qa_career(target_profession,target_level);
 select count(*),count(*)filter(where(submitted_answers->>q.id::text)::integer=q.correct_index)into total,correct from certification_questions q where q.profession_id=target_profession and q.level=target_level and q.active and submitted_answers?q.id::text;
 select passing_score into passing from certification_levels where level=target_level;
 if total=0 then raise exception 'Answer at least one active question';end if;
 return jsonb_build_object('score',round(correct::numeric/total*100,2),'passed',round(correct::numeric/total*100,2)>=passing,'passing_score',passing,'qa',true,'read_only',true);
end$$;

revoke all on function public.has_profession_qa_access(uuid),public.open_profession_qa_career(text,integer),public.get_profession_qa_questions(text,integer) from public;
grant execute on function public.open_profession_qa_career(text,integer),public.get_profession_qa_questions(text,integer),public.grade_profession_qa_test(text,integer,jsonb) to authenticated;
