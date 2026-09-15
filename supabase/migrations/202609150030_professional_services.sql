-- Data-driven Legacy Equine Game Certifications and player-to-player horse services.
create table public.professions(
  id text primary key, name text not null unique, description text not null, active boolean not null default true, sort_order integer not null
);
create table public.certification_levels(
  level integer primary key check(level between 1 and 4), name text not null unique,
  required_services numeric(8,1) not null default 0, passing_score numeric(5,2) not null default 80,
  test_length integer not null default 5, retry_cooldown_minutes integer not null default 15
);
create table public.study_modules(
  id uuid primary key default gen_random_uuid(), profession_id text not null references public.professions(id), level integer not null references public.certification_levels(level),
  title text not null, summary text not null, lessons jsonb not null check(jsonb_typeof(lessons)='array'), sort_order integer not null default 0, active boolean not null default true
);
create table public.certification_questions(
  id uuid primary key default gen_random_uuid(), profession_id text not null references public.professions(id), level integer not null references public.certification_levels(level),
  prompt text not null, choices jsonb not null check(jsonb_array_length(choices)>=2), correct_index integer not null check(correct_index>=0), explanation text not null, active boolean not null default true
);
create table public.player_professions(
  stable_id uuid not null references public.stables(id) on delete cascade, profession_id text not null references public.professions(id), certification_level integer not null default 0 check(certification_level between 0 and 4),
  available boolean not null default false, lifetime_client_services integer not null default 0, lifetime_self_services integer not null default 0,
  qualifying_credit numeric(10,1) not null default 0, enrolled_at timestamptz not null default now(), certified_at timestamptz, primary key(stable_id,profession_id)
);
create table public.player_study_progress(
  stable_id uuid not null references public.stables(id) on delete cascade, profession_id text not null references public.professions(id), level integer not null references public.certification_levels(level),
  started_at timestamptz not null default now(), completed_at timestamptz, primary key(stable_id,profession_id,level)
);
create table public.certification_attempts(
  id uuid primary key default gen_random_uuid(), stable_id uuid not null references public.stables(id), profession_id text not null references public.professions(id), level integer not null references public.certification_levels(level),
  score numeric(5,2) not null, passed boolean not null, answers jsonb not null, created_at timestamptz not null default now()
);
create table public.service_catalog(
  id text primary key, profession_id text not null references public.professions(id), name text not null, minimum_level integer not null references public.certification_levels(level),
  min_price integer not null check(min_price>=0), max_price integer not null check(max_price>=min_price), cooldown_hours integer not null default 24,
  effect jsonb not null default '{}', duration_hours integer not null default 168, active boolean not null default true
);
create table public.player_service_offerings(
  stable_id uuid not null references public.stables(id) on delete cascade, service_id text not null references public.service_catalog(id), price integer not null, enabled boolean not null default true,
  primary key(stable_id,service_id)
);
create table public.horse_service_records(
  id uuid primary key default gen_random_uuid(), horse_id uuid not null references public.horses(id), client_id uuid not null references public.stables(id), provider_id uuid not null references public.stables(id),
  profession_id text not null references public.professions(id), service_id text not null references public.service_catalog(id), provider_level integer not null, price integer not null,
  quality text not null, effect jsonb not null default '{}', effect_expires_at timestamptz, self_service boolean not null, status text not null default 'completed' check(status in('completed','canceled')),
  idempotency_key uuid not null unique, completed_at timestamptz not null default now()
);

insert into public.professions(id,name,description,sort_order) values
 ('farrier','Farrier','Hoof care, trimming, and performance shoeing.',1),('veterinarian','Veterinarian','Game-focused wellness, evaluation, and recovery services.',2),
 ('trainer','Trainer','Conditioning, discipline development, and performance preparation.',3),('massage','Equine Massage Therapist','Game-focused recovery and performance preparation.',4);
insert into public.certification_levels values (1,'Basic',0,80,3,5),(2,'Proficient',10,80,4,10),(3,'Advanced',25,80,5,15),(4,'Professional',50,80,6,20);

insert into public.study_modules(profession_id,level,title,summary,lessons) values
('farrier',1,'Sound Hoof Foundations','Learn the structures and routine care that support a sound hoof.','["The hoof wall bears weight while the sole, frog, and internal structures help absorb force.","Routine trimming maintains balance and prevents excess growth; shoeing is chosen for the individual horse.","LE services are game mechanics and never replace real farrier care."]'),
('farrier',2,'Balance and Basic Shoeing','Connect hoof balance, breakover, and basic shoe selection.','["Medial-lateral balance supports even loading.","Breakover and heel support are considered together.","A service plan should match work, footing, and current hoof status."]'),
('farrier',3,'Performance Hoof Care','Explore sport demands and specialty concepts.','["Performance disciplines place different demands on traction and support.","Changes should preserve sound, functional movement.","Specialty packages require accurate assessment and follow-up."]'),
('farrier',4,'Professional Practice','Apply the full LE farrier service framework.','["Professional service balances protection, movement, and the horse’s workload.","Documenting service history supports continuity of care.","Professional certification is the highest current LE game tier."]'),
('veterinarian',1,'Horse Wellness Basics','Recognize normal observations and routine management.','["Regular observation includes appetite, demeanor, movement, and hydration.","A wellness exam is preventive game care.","LE certification is not real veterinary licensure."]'),
('veterinarian',2,'Evaluation and Recovery','Build a structured game evaluation and recovery plan.','["Compare current signs to the horse’s normal baseline.","Recovery balances rest, reassessment, and gradual return.","Urgent real-world concerns require a licensed veterinarian."]'),
('veterinarian',3,'Performance Management','Consider workload, recovery, and reproductive evaluation.','["Performance evaluation considers the whole horse.","Management changes should be gradual and recorded.","Reproductive evaluation remains a simplified game service."]'),
('veterinarian',4,'Professional Equine Management','Coordinate high-level LE health services.','["Professional-level service integrates history, observation, and follow-up.","Transparent records follow the horse.","No LE result is a real diagnosis."]'),
('trainer',1,'Training Principles','Learn consistency, clear cues, and gradual conditioning.','["Training progresses through repeatable, achievable steps.","Fitness develops gradually with recovery.","The horse’s temperament and current ability guide the session."]'),
('trainer',2,'Discipline Development','Shape a horse toward a chosen discipline.','["Specificity connects exercises to performance goals.","Foundation skills remain important as difficulty increases.","Track permanent development separately from temporary effects."]'),
('trainer',3,'Advanced Conditioning','Plan progressive workload and refinement.','["Periodized work alternates challenge and recovery.","Quality practice is more valuable than repetitive clicking.","Transparent development records preserve breeding values."]'),
('trainer',4,'Professional Development','Coordinate long-term high-level development.','["Professional plans connect conformation, temperament, fitness, and goals.","Reassessment keeps the plan appropriate.","Professional is the highest current LE game certification."]'),
('massage',1,'Muscle and Recovery Basics','Learn major muscle groups and general recovery concepts.','["Large muscle groups power movement and benefit from appropriate recovery.","General massage is a temporary condition service.","LE certification is not real massage qualification."]'),
('massage',2,'Performance Preparation','Connect workload and targeted game preparation.','["Preparation supports rather than replaces conditioning.","Response and comfort guide the scope of a session.","Effects are temporary and never inherited."]'),
('massage',3,'Advanced Recovery','Plan higher-level recovery support.','["Recovery plans consider recent workload and upcoming demands.","Documented history helps avoid excessive repeat service.","Cooldowns protect game balance and horse welfare."]'),
('massage',4,'Professional Bodywork','Deliver the highest normal LE massage service.','["Professional bodywork integrates preparation, recovery, and follow-up.","Temporary bonuses remain clearly labeled.","Refer real health concerns to qualified professionals."]');

insert into public.certification_questions(profession_id,level,prompt,choices,correct_index,explanation)
select p.id,l.level,
 case p.id when 'farrier' then 'Which goal best describes routine hoof trimming?' when 'veterinarian' then 'What is the best first step in a routine wellness check?' when 'trainer' then 'Which approach best supports lasting training?' else 'What best describes an LE massage effect?' end,
 case p.id when 'farrier' then '["Maintain balanced growth","Maximize hoof length","Replace all conditioning"]'::jsonb when 'veterinarian' then '["Compare observations with the horse’s normal baseline","Immediately diagnose from one sign","Ignore movement"]'::jsonb when 'trainer' then '["Gradual, consistent progression","Repeating the hardest task continuously","Skipping recovery"]'::jsonb else '["A temporary condition bonus","A genetic change","A permanent base-stat rewrite"]'::jsonb end,
 0,'Correct: LE care uses balanced, transparent, horse-appropriate progression.'
from professions p cross join certification_levels l;

insert into public.service_catalog values
('routine_trim','farrier','Routine Trim',1,75,175,72,'{"Agility":1}',168,true),('front_shoes','farrier','Basic Front Shoes',1,100,225,96,'{"Speed":1}',168,true),
('full_set','farrier','Full Set',2,175,350,120,'{"Agility":1,"Speed":1}',240,true),('performance_shoes','farrier','Performance Shoes',3,250,500,120,'{"Speed":2,"Agility":1}',240,true),
('specialty_package','farrier','Professional Specialty Package',4,400,750,168,'{"Speed":2,"Agility":2}',336,true),
('wellness_exam','veterinarian','Wellness Exam',1,75,200,72,'{"Temperament":1}',72,true),('performance_evaluation','veterinarian','Performance Evaluation',2,175,350,120,'{"Endurance":1}',120,true),
('recovery_service','veterinarian','Injury / Recovery Service',3,300,600,168,'{"Endurance":2,"Temperament":1}',168,true),('reproductive_evaluation','veterinarian','Reproductive Evaluation',4,400,750,168,'{"Conformation":1}',168,true),
('basic_training','trainer','Basic Training',1,100,225,48,'{"Intelligence":1}',0,true),('discipline_training','trainer','Discipline Training',2,225,425,72,'{"Agility":1,"Intelligence":1}',0,true),
('advanced_training','trainer','Advanced Training',3,350,650,96,'{"Agility":1,"Speed":1,"Endurance":1}',0,true),('professional_development','trainer','Professional Development',4,500,900,120,'{"Conformation":1,"Intelligence":2}',0,true),
('general_massage','massage','General Massage',1,75,175,48,'{"Temperament":1}',48,true),('performance_massage','massage','Performance Massage',2,125,275,72,'{"Agility":1,"Speed":1}',72,true),
('recovery_massage','massage','Recovery Massage',3,225,425,96,'{"Endurance":2}',96,true),('professional_bodywork','massage','Professional Bodywork',4,350,600,120,'{"Agility":2,"Endurance":1}',120,true);

alter table public.professions enable row level security;alter table public.certification_levels enable row level security;alter table public.study_modules enable row level security;
alter table public.certification_questions enable row level security;alter table public.player_professions enable row level security;alter table public.player_study_progress enable row level security;
alter table public.certification_attempts enable row level security;alter table public.service_catalog enable row level security;alter table public.player_service_offerings enable row level security;alter table public.horse_service_records enable row level security;
create policy "profession reference readable" on public.professions for select using(true);create policy "levels readable" on public.certification_levels for select using(true);
create policy "modules readable" on public.study_modules for select using(true);create policy "catalog readable" on public.service_catalog for select using(true);
create policy "player professions readable" on public.player_professions for select using(true);create policy "offerings readable" on public.player_service_offerings for select using(true);
create policy "own study readable" on public.player_study_progress for select using(stable_id=auth.uid());create policy "own attempts readable" on public.certification_attempts for select using(stable_id=auth.uid());
create policy "horse service records readable" on public.horse_service_records for select using(true);

create or replace function public.get_profession_dashboard()
returns jsonb language sql security definer set search_path=public stable as $$
 select jsonb_build_object('professions',coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'description',p.description,'level',coalesce(pp.certification_level,0),'level_name',coalesce(cl.name,'Not enrolled'),'available',coalesce(pp.available,false),'client_services',coalesce(pp.lifetime_client_services,0),'self_services',coalesce(pp.lifetime_self_services,0),'qualifying_credit',coalesce(pp.qualifying_credit,0),'study_completed',sp.completed_at is not null,'required_services',coalesce(nextcl.required_services,0),'next_level',case when coalesce(pp.certification_level,0)<4 then coalesce(pp.certification_level,0)+1 end) order by p.sort_order),'[]'))
 from professions p left join player_professions pp on pp.profession_id=p.id and pp.stable_id=auth.uid() left join certification_levels cl on cl.level=pp.certification_level left join certification_levels nextcl on nextcl.level=coalesce(pp.certification_level,0)+1 left join player_study_progress sp on sp.stable_id=auth.uid() and sp.profession_id=p.id and sp.level=coalesce(pp.certification_level,0)+1 where p.active $$;

create or replace function public.enroll_profession(target_profession text) returns void language plpgsql security definer set search_path=public as $$begin
 if not exists(select 1 from professions where id=target_profession and active) then raise exception 'Profession not found';end if;
 insert into player_professions(stable_id,profession_id) values(auth.uid(),target_profession) on conflict do nothing;
 insert into player_study_progress(stable_id,profession_id,level) values(auth.uid(),target_profession,1) on conflict do nothing;end$$;
create or replace function public.complete_profession_study(target_profession text,target_level integer) returns void language plpgsql security definer set search_path=public as $$declare pp player_professions;req numeric;begin
 select * into pp from player_professions where stable_id=auth.uid() and profession_id=target_profession;if not found then raise exception 'Enroll first';end if;
 if target_level<>pp.certification_level+1 then raise exception 'Complete certification levels in order';end if;select required_services into req from certification_levels where level=target_level;
 if pp.qualifying_credit<req then raise exception 'Complete % qualifying services before this study level',req;end if;
 insert into player_study_progress(stable_id,profession_id,level,completed_at) values(auth.uid(),target_profession,target_level,now()) on conflict(stable_id,profession_id,level) do update set completed_at=now();end$$;
create or replace function public.take_certification_test(target_profession text,target_level integer,submitted_answers jsonb) returns jsonb language plpgsql security definer set search_path=public as $$declare pp player_professions;cfg certification_levels;latest timestamptz;correct int;total int;score numeric;passed boolean;begin
 select * into pp from player_professions where stable_id=auth.uid() and profession_id=target_profession for update;if not found then raise exception 'Enroll first';end if;if target_level<>pp.certification_level+1 then raise exception 'Invalid certification level';end if;
 if not exists(select 1 from player_study_progress where stable_id=auth.uid() and profession_id=target_profession and level=target_level and completed_at is not null) then raise exception 'Complete Study first';end if;
 select * into cfg from certification_levels where level=target_level;select max(created_at) into latest from certification_attempts where stable_id=auth.uid() and profession_id=target_profession and level=target_level;
 if latest is not null and latest>now()-make_interval(mins=>cfg.retry_cooldown_minutes) then raise exception 'Certification retest cooldown is active';end if;
 select count(*),count(*) filter(where (submitted_answers->>q.id::text)::int=q.correct_index) into total,correct from certification_questions q where q.profession_id=target_profession and q.level=target_level and q.active;
 if total=0 then raise exception 'No active questions configured';end if;score:=round(correct::numeric/total*100,2);passed:=score>=cfg.passing_score;
 insert into certification_attempts(stable_id,profession_id,level,score,passed,answers) values(auth.uid(),target_profession,target_level,score,passed,submitted_answers);
 if passed then update player_professions set certification_level=target_level,certified_at=now(),available=true where stable_id=auth.uid() and profession_id=target_profession;end if;
 return jsonb_build_object('score',score,'passed',passed,'passing_score',cfg.passing_score);end$$;

create or replace function public.get_certification_questions(target_profession text,target_level integer)
returns table(id uuid,prompt text,choices jsonb) language sql security definer set search_path=public stable as $$select q.id,q.prompt,q.choices from certification_questions q where q.profession_id=target_profession and q.level=target_level and q.active order by random() limit (select test_length from certification_levels where level=target_level)$$;
create or replace function public.set_professional_availability(target_profession text,is_available boolean) returns void language sql security definer set search_path=public as $$update player_professions set available=is_available where stable_id=auth.uid() and profession_id=target_profession and certification_level>0$$;
create or replace function public.set_service_offering(target_service text,new_price integer,is_enabled boolean) returns void language plpgsql security definer set search_path=public as $$declare svc service_catalog;lvl int;begin
 select * into svc from service_catalog where id=target_service and active;select certification_level into lvl from player_professions where stable_id=auth.uid() and profession_id=svc.profession_id;
 if svc.id is null or coalesce(lvl,0)<svc.minimum_level then raise exception 'Certification does not qualify for this service';end if;if new_price not between svc.min_price and svc.max_price then raise exception 'Price must be between % and % LED',svc.min_price,svc.max_price;end if;
 insert into player_service_offerings values(auth.uid(),target_service,new_price,is_enabled) on conflict(stable_id,service_id) do update set price=new_price,enabled=is_enabled;end$$;

create or replace function public.get_service_directory(target_profession text default null)
returns table(provider_id uuid,stable_name text,account_number bigint,profession_id text,profession_name text,certification text,completed_services integer,service_id text,service_name text,price integer) language sql security definer set search_path=public stable as $$
 select s.id,s.name,s.account_number,p.id,p.name,cl.name,pp.lifetime_client_services+pp.lifetime_self_services as completed_services,sc.id,sc.name,o.price from player_service_offerings o join player_professions pp on pp.stable_id=o.stable_id join stables s on s.id=o.stable_id join service_catalog sc on sc.id=o.service_id join professions p on p.id=sc.profession_id join certification_levels cl on cl.level=pp.certification_level where o.enabled and pp.available and sc.minimum_level<=pp.certification_level and (target_profession is null or p.id=target_profession) order by pp.certification_level desc,completed_services desc,o.price $$;

create or replace function public.purchase_professional_service(target_horse uuid,target_provider uuid,target_service text,request_key uuid)
returns public.horse_service_records language plpgsql security definer set search_path=public as $$declare h horses;provider player_professions;svc service_catalog;offering player_service_offerings;client stables;result horse_service_records;last_at timestamptz;self boolean;quality text;credit numeric;begin
 select * into h from horses where id=target_horse for update;if h.owner_id<>auth.uid() then raise exception 'You must own this horse';end if;select * into svc from service_catalog where id=target_service and active;
 select * into provider from player_professions where stable_id=target_provider and profession_id=svc.profession_id for update;select * into offering from player_service_offerings where stable_id=target_provider and service_id=target_service and enabled for update;
 if provider.certification_level<svc.minimum_level or not provider.available or offering.price is null then raise exception 'This service is not currently available';end if;
 select max(completed_at) into last_at from horse_service_records where horse_id=target_horse and service_id=target_service and status='completed';if last_at is not null and last_at>now()-make_interval(hours=>svc.cooldown_hours) then raise exception 'This horse is still in the service cooldown';end if;
 self:=target_provider=auth.uid();if not self then select * into client from stables where id=auth.uid() for update;if client.balance<offering.price then raise exception 'Insufficient LED balance';end if;update stables set balance=balance-offering.price where id=auth.uid();update stables set balance=balance+offering.price where id=target_provider;insert into currency_ledger(stable_id,amount,reason,horse_id) values(auth.uid(),-offering.price,'Professional service: '||svc.name,h.id),(target_provider,offering.price,'Professional service provided: '||svc.name,h.id);end if;
 quality:=case provider.certification_level when 1 then 'Good' when 2 then 'Very Good' when 3 then 'Excellent' else 'Exceptional' end;credit:=case when self then .5 else 1 end;
 insert into horse_service_records(horse_id,client_id,provider_id,profession_id,service_id,provider_level,price,quality,effect,effect_expires_at,self_service,idempotency_key) values(h.id,auth.uid(),target_provider,svc.profession_id,svc.id,provider.certification_level,case when self then 0 else offering.price end,quality,svc.effect,case when svc.duration_hours>0 then now()+make_interval(hours=>svc.duration_hours) end,self,request_key) returning * into result;
 update player_professions set lifetime_client_services=lifetime_client_services+(case when self then 0 else 1 end),lifetime_self_services=lifetime_self_services+(case when self then 1 else 0 end),qualifying_credit=qualifying_credit+credit where stable_id=target_provider and profession_id=svc.profession_id;return result;exception when unique_violation then select * into result from horse_service_records where idempotency_key=request_key;return result;end$$;

create or replace function public.get_horse_service_history(target_horse uuid)
returns table(completed_at timestamptz,profession_name text,service_name text,provider_name text,provider_account bigint,certification text,quality text,effect jsonb,effect_expires_at timestamptz,self_service boolean) language sql security definer set search_path=public stable as $$select r.completed_at,p.name,sc.name,s.name,s.account_number,cl.name,r.quality,r.effect,r.effect_expires_at,r.self_service from horse_service_records r join professions p on p.id=r.profession_id join service_catalog sc on sc.id=r.service_id join stables s on s.id=r.provider_id join certification_levels cl on cl.level=r.provider_level where r.horse_id=target_horse and r.status='completed' order by r.completed_at desc$$;

revoke all on function public.enroll_profession(text),public.complete_profession_study(text,integer),public.take_certification_test(text,integer,jsonb),public.get_certification_questions(text,integer),public.set_professional_availability(text,boolean),public.set_service_offering(text,integer,boolean),public.purchase_professional_service(uuid,uuid,text,uuid) from public;
grant execute on function public.get_profession_dashboard(),public.enroll_profession(text),public.complete_profession_study(text,integer),public.take_certification_test(text,integer,jsonb),public.get_certification_questions(text,integer),public.set_professional_availability(text,boolean),public.set_service_offering(text,integer,boolean),public.get_service_directory(text),public.purchase_professional_service(uuid,uuid,text,uuid),public.get_horse_service_history(uuid) to authenticated;
