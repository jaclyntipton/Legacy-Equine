-- Keep the real Profession career authoritative across Owner QA navigation and
-- reconcile only milestones supported by permanent attempts/offerings.
create table if not exists public.profession_persistence_audit(
 id uuid primary key default gen_random_uuid(),
 stable_id uuid not null references public.stables(id) on delete cascade,
 evidence jsonb not null,
 reconciled_at timestamptz not null default now()
);
alter table public.profession_persistence_audit enable row level security;
drop policy if exists "owner reads profession persistence audit" on public.profession_persistence_audit;
create policy "owner reads profession persistence audit" on public.profession_persistence_audit
 for select using(public.is_owner_account());

do $$
declare owner_id uuid;evidence jsonb;
begin
 select id into owner_id from public.stables where account_number=1;
 if owner_id is null then return;end if;
 select jsonb_build_object(
  'passed_attempts',coalesce((select jsonb_agg(jsonb_build_object('profession',profession_id,'level',level,'passed_at',created_at)order by created_at)from public.certification_attempts where stable_id=owner_id and passed),'[]'::jsonb),
  'saved_offerings',coalesce((select jsonb_agg(jsonb_build_object('service',service_id,'price',price,'enabled',enabled)order by service_id)from public.player_service_offerings where stable_id=owner_id),'[]'::jsonb)
 )into evidence;

 -- A passed permanent attempt is the only evidence accepted for a missing
 -- certificate. QA grading never writes certification_attempts.
 insert into public.player_profession_certifications(stable_id,profession_id,level,granted_at,attempt_id)
 select owner_id,a.profession_id,a.level,a.created_at,a.id
 from public.certification_attempts a
 where a.stable_id=owner_id and a.passed
 on conflict(stable_id,profession_id,level)do nothing;

 update public.player_professions pp set
  certification_level=x.level,
  certified_at=coalesce(x.certified_at,pp.certified_at),
  available=true
 from(
  select profession_id,max(level)level,max(created_at)certified_at
  from public.certification_attempts where stable_id=owner_id and passed group by profession_id
 )x
 where pp.stable_id=owner_id and pp.profession_id=x.profession_id and pp.certification_level<x.level;

 -- Existing valid saved offerings are authoritative evidence of configured
 -- rates. A setup is complete only when every service unlocked at that level
 -- has an enabled, in-range offering.
 insert into public.profession_rate_setups(stable_id,profession_id,level,completed_at)
 select pp.stable_id,pp.profession_id,l.level,now()
 from public.player_professions pp
 cross join lateral generate_series(1,pp.certification_level)l(level)
 join public.service_catalog sc on sc.profession_id=pp.profession_id and sc.active and sc.minimum_level<=l.level
 left join public.player_service_offerings o on o.stable_id=pp.stable_id and o.service_id=sc.id and o.enabled and o.price between sc.min_price and sc.max_price
 where pp.stable_id=owner_id
 group by pp.stable_id,pp.profession_id,l.level
 having count(*)=count(o.service_id)
 on conflict(stable_id,profession_id,level)do update set completed_at=excluded.completed_at;

 insert into public.profession_persistence_audit(stable_id,evidence)values(owner_id,evidence);
 raise notice 'Account #1 profession persistence evidence: %',evidence;
end$$;

create or replace function public.get_my_profession_persistence() returns jsonb
language sql stable security definer set search_path=public as $$
 select jsonb_build_object(
  'careers',coalesce((select jsonb_agg(jsonb_build_object('profession',pp.profession_id,'level',pp.certification_level,'certified_at',pp.certified_at,'available',pp.available,'certified_levels',coalesce((select jsonb_agg(c.level order by c.level)from player_profession_certifications c where c.stable_id=pp.stable_id and c.profession_id=pp.profession_id),'[]'::jsonb),'offerings',coalesce((select jsonb_agg(jsonb_build_object('service',o.service_id,'price',o.price,'enabled',o.enabled)order by o.service_id)from player_service_offerings o join service_catalog sc on sc.id=o.service_id where o.stable_id=pp.stable_id and sc.profession_id=pp.profession_id),'[]'::jsonb))order by pp.profession_id)from player_professions pp where pp.stable_id=auth.uid()),'[]'::jsonb)
 )
$$;
revoke all on function public.get_my_profession_persistence() from public;
grant execute on function public.get_my_profession_persistence() to authenticated;
