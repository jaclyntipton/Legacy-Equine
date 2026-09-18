-- Permanent career milestones may advance, never regress. QA routines never
-- write these tables and normal gameplay remains transactionally authoritative.
create or replace function public.guard_profession_progress_regression()
returns trigger language plpgsql set search_path=public as $$
begin
 if new.certification_level<old.certification_level then raise exception 'Permanent certification progress cannot be reduced';end if;
 if old.certified_at is not null and new.certified_at is null then new.certified_at:=old.certified_at;end if;
 return new;
end$$;
drop trigger if exists guard_profession_progress_regression on public.player_professions;
create trigger guard_profession_progress_regression before update on public.player_professions
for each row execute function public.guard_profession_progress_regression();

create or replace function public.sync_profession_certificate_to_career()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 update player_professions set
  certification_level=greatest(certification_level,new.level),
  certified_at=case when certification_level<=new.level then coalesce(new.granted_at,now())else certified_at end,
  available=true
 where stable_id=new.stable_id and profession_id=new.profession_id;
 return new;
end$$;
drop trigger if exists sync_profession_certificate_to_career on public.player_profession_certifications;
create trigger sync_profession_certificate_to_career after insert or update on public.player_profession_certifications
for each row execute function public.sync_profession_certificate_to_career();

-- One shared diagnostic verifies all four careers resolve from the same durable
-- certification and offering records consumed by Market/Profile/Stable.
create or replace function public.admin_profession_persistence_integrity()
returns jsonb language sql stable security definer set search_path=public as $$
 select jsonb_build_object(
  'professions',coalesce((select jsonb_agg(jsonb_build_object(
   'profession',p.id,
   'career_certificate_mismatches',(select count(*)from player_professions pp where pp.profession_id=p.id and pp.certification_level<>coalesce((select max(c.level)from player_profession_certifications c where c.stable_id=pp.stable_id and c.profession_id=pp.profession_id),0)),
   'invalid_offerings',(select count(*)from player_service_offerings o join service_catalog sc on sc.id=o.service_id where sc.profession_id=p.id and(o.price not between sc.min_price and sc.max_price or not exists(select 1 from player_profession_certifications c where c.stable_id=o.stable_id and c.profession_id=p.id and c.level>=sc.minimum_level)))
  )order by p.sort_order)from professions p where p.active),'[]'::jsonb),
  'shared_public_projection','get_public_professional_services'
 )
$$;
revoke all on function public.admin_profession_persistence_integrity() from public;
grant execute on function public.admin_profession_persistence_integrity() to authenticated;

-- Assert the shared architecture exists for every active profession.
do $$declare missing text;
begin
 select string_agg(p.id,', ')into missing from professions p
 where p.active and not exists(select 1 from service_catalog sc where sc.profession_id=p.id and sc.active);
 if missing is not null then raise exception 'Active professions missing persistent service catalogs: %',missing;end if;
end$$;
