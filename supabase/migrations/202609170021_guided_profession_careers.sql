-- Persist the player's explicit transition from service experience into the next
-- certification curriculum. Certification rules and service thresholds remain
-- unchanged; this only gives the guided workspace a durable stage boundary.
create table if not exists public.profession_career_advancements (
  stable_id uuid not null references public.stables(id) on delete cascade,
  profession_id text not null references public.professions(id) on delete cascade,
  target_level integer not null references public.certification_levels(level),
  advanced_at timestamptz not null default now(),
  primary key (stable_id, profession_id, target_level)
);

alter table public.profession_career_advancements enable row level security;
create policy "own career advancements readable"
  on public.profession_career_advancements for select
  using (stable_id = auth.uid());

-- Basic study is opened by enrollment. Previously completed levels are also
-- considered opened so this UX migration never rolls a player's progress back.
insert into public.profession_career_advancements(stable_id, profession_id, target_level, advanced_at)
select pp.stable_id, pp.profession_id, levels.level, pp.enrolled_at
from public.player_professions pp
cross join lateral generate_series(1, greatest(1, pp.certification_level)) levels(level)
on conflict do nothing;

create or replace function public.seed_basic_profession_career()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into profession_career_advancements(stable_id,profession_id,target_level)
  values(new.stable_id,new.profession_id,1) on conflict do nothing;
  return new;
end$$;

drop trigger if exists seed_basic_profession_career on public.player_professions;
create trigger seed_basic_profession_career
after insert on public.player_professions
for each row execute function public.seed_basic_profession_career();

create or replace function public.advance_profession_career(target_profession text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  pp player_professions;
  target integer;
  required numeric;
begin
  select * into pp from player_professions
  where stable_id=auth.uid() and profession_id=target_profession for update;
  if not found then raise exception 'Enroll first'; end if;
  if pp.certification_level=0 then raise exception 'Complete the Basic certification test first'; end if;
  if pp.certification_level>=4 then return jsonb_build_object('completed',true,'level',4); end if;
  target:=pp.certification_level+1;
  select required_services into required from certification_levels where level=target;
  if pp.qualifying_credit<required then
    raise exception 'Complete % qualifying services before advancing',required;
  end if;
  insert into profession_career_advancements(stable_id,profession_id,target_level)
  values(auth.uid(),target_profession,target) on conflict do nothing;
  insert into player_study_progress(stable_id,profession_id,level)
  values(auth.uid(),target_profession,target) on conflict do nothing;
  return jsonb_build_object('completed',false,'level',target);
end$$;

create or replace function public.complete_profession_study(target_profession text,target_level integer)
returns void language plpgsql security definer set search_path=public as $$
declare pp player_professions; req numeric;
begin
  select * into pp from player_professions where stable_id=auth.uid() and profession_id=target_profession;
  if not found then raise exception 'Enroll first'; end if;
  if target_level<>pp.certification_level+1 then raise exception 'Complete certification levels in order'; end if;
  if not exists(select 1 from profession_career_advancements a where a.stable_id=auth.uid() and a.profession_id=target_profession and a.target_level=$2) then
    raise exception 'Advance to this certification level first';
  end if;
  select required_services into req from certification_levels where level=target_level;
  if pp.qualifying_credit<req then raise exception 'Complete % qualifying services before this study level',req; end if;
  insert into player_study_progress(stable_id,profession_id,level,completed_at)
  values(auth.uid(),target_profession,target_level,now())
  on conflict(stable_id,profession_id,level) do update set completed_at=now();
end$$;

create or replace function public.get_profession_dashboard() returns jsonb
language sql security definer set search_path=public stable as $$
 select jsonb_build_object(
  'owner_qa_access',public.has_profession_qa_access(),
  'can_enroll',not exists(select 1 from player_professions where stable_id=auth.uid() and certification_level<4),
  'professions',coalesce(jsonb_agg(jsonb_build_object(
   'id',p.id,'name',p.name,'description',p.description,'enrollment_fee',p.enrollment_fee,
   'level',coalesce(pp.certification_level,0),'level_name',coalesce(cl.name,'Not enrolled'),'available',coalesce(pp.available,false),
   'client_services',coalesce(pp.lifetime_client_services,0),'self_services',coalesce(pp.lifetime_self_services,0),'qualifying_credit',coalesce(pp.qualifying_credit,0),
   'study_completed',sp.completed_at is not null,'required_services',coalesce(nextcl.required_services,0),'exam_fee',coalesce(nextcl.exam_fee,0),
   'next_level',case when coalesce(pp.certification_level,0)<4 then coalesce(pp.certification_level,0)+1 end,
   'next_level_advanced',coalesce(pp.certification_level,0)=0 or adv.target_level is not null
  )order by p.sort_order),'[]'))
 from professions p
 left join player_professions pp on pp.profession_id=p.id and pp.stable_id=auth.uid()
 left join certification_levels cl on cl.level=pp.certification_level
 left join certification_levels nextcl on nextcl.level=coalesce(pp.certification_level,0)+1
 left join player_study_progress sp on sp.stable_id=auth.uid() and sp.profession_id=p.id and sp.level=coalesce(pp.certification_level,0)+1
 left join profession_career_advancements adv on adv.stable_id=auth.uid() and adv.profession_id=p.id and adv.target_level=coalesce(pp.certification_level,0)+1
 where p.active
$$;

revoke all on function public.advance_profession_career(text) from public;
grant execute on function public.advance_profession_career(text) to authenticated;
