begin;

create function public.enforce_leatherworker_live_experience()
returns trigger language plpgsql security definer set search_path=public as $$
declare required integer;
begin
 if new.profession_id <> 'leatherworker' then return new; end if;
 if tg_table_name = 'profession_advancement_overrides' then
  raise exception 'Leatherworker live progression requires completed paid commissions';
 end if;
 if new.target_level <= 1 then return new; end if;
 select required_services into required from profession_level_requirements
 where profession_id = 'leatherworker' and level = new.target_level - 1;
 if required is null or public.legitimate_profession_service_count(
  new.stable_id, 'leatherworker', new.target_level - 1
 ) < required then
  raise exception 'Complete the required paid commissions before advancing';
 end if;
 return new;
end $$;

revoke all on function public.enforce_leatherworker_live_experience() from public;
create trigger leatherworker_no_live_override before insert or update on public.profession_advancement_overrides
for each row execute function public.enforce_leatherworker_live_experience();
create trigger leatherworker_live_advancement before insert or update on public.profession_career_advancements
for each row execute function public.enforce_leatherworker_live_experience();

create function public.enforce_leatherworker_listing_tier()
returns trigger language plpgsql security definer set search_path=public as $$
declare tier_level integer;
begin
 if new.listed_price is null or new.maker_stable_id is distinct from new.stable_id
 or new.custom_tack_bonuses is null then return new; end if;
 select min(minimum_level) into tier_level from service_catalog
 where profession_id = 'leatherworker' and active and lower(tack_tier) = lower(new.crafted_tier);
 if tier_level is null or not exists (
  select 1 from player_profession_certifications where stable_id = new.stable_id
  and profession_id = 'leatherworker' and level >= tier_level
 ) then raise exception 'Earn certification for this tack tier before listing it'; end if;
 return new;
end $$;
revoke all on function public.enforce_leatherworker_listing_tier() from public;
create trigger leatherworker_live_listing before update of listed_price on public.player_store_items
for each row execute function public.enforce_leatherworker_listing_tier();

do $$
declare owner_id uuid;
begin
 select pp.stable_id into owner_id
 from player_professions pp join stables s on s.id = pp.stable_id
 where s.account_number = 1 and pp.profession_id = 'leatherworker'
 and pp.certification_level = 4 for update of pp;
 if owner_id is null then raise exception 'Expected Owner Leatherworker record not found'; end if;
 if not exists (select 1 from player_profession_certifications where stable_id = owner_id and profession_id = 'leatherworker' and level = 1)
 or (select count(*) from profession_advancement_overrides where stable_id = owner_id and profession_id = 'leatherworker' and certification_level between 1 and 3 and actual_service_count = 0) <> 3
 or public.legitimate_profession_service_count(owner_id, 'leatherworker', 1) >=
 (select required_services from profession_level_requirements where profession_id = 'leatherworker' and level = 1)
 then raise exception 'Owner Leatherworker evidence changed; review before repair'; end if;

 insert into profession_persistence_audit(stable_id, evidence)
 values (owner_id, jsonb_build_object(
  'repair', 'leatherworker_live_experience',
  'career', (select to_jsonb(x) from player_professions x where stable_id = owner_id and profession_id = 'leatherworker'),
  'certificates', (select jsonb_agg(to_jsonb(x)) from player_profession_certifications x where stable_id = owner_id and profession_id = 'leatherworker'),
  'study', (select jsonb_agg(to_jsonb(x)) from player_study_progress x where stable_id = owner_id and profession_id = 'leatherworker'),
  'advancements', (select jsonb_agg(to_jsonb(x)) from profession_career_advancements x where stable_id = owner_id and profession_id = 'leatherworker'),
  'overrides', (select jsonb_agg(to_jsonb(x)) from profession_advancement_overrides x where stable_id = owner_id and profession_id = 'leatherworker'),
  'completion', (select to_jsonb(x) from profession_career_completions x where stable_id = owner_id and profession_id = 'leatherworker')
 ));

 delete from player_profession_certifications where stable_id = owner_id and profession_id = 'leatherworker' and level > 1;
 delete from player_study_progress where stable_id = owner_id and profession_id = 'leatherworker' and level > 1;
 delete from profession_career_advancements where stable_id = owner_id and profession_id = 'leatherworker' and target_level > 1;
 delete from profession_advancement_overrides where stable_id = owner_id and profession_id = 'leatherworker';
 delete from profession_career_completions where stable_id = owner_id and profession_id = 'leatherworker';
 delete from profession_rate_setups where stable_id = owner_id and profession_id = 'leatherworker' and level > 1;
 update player_service_offerings o set enabled = false from service_catalog sc
 where o.stable_id = owner_id and o.service_id = sc.id and sc.profession_id = 'leatherworker' and sc.minimum_level > 1;
 update player_store_items set listed_price = null, listed_at = null
 where stable_id = owner_id and maker_stable_id = owner_id
 and lower(crafted_tier) in ('quality', 'elite', 'legendary') and listed_price is not null;
 alter table public.player_professions disable trigger guard_profession_progress_regression;
 update player_professions set certification_level = 1,
 certified_at = (select granted_at from player_profession_certifications where stable_id = owner_id and profession_id = 'leatherworker' and level = 1)
 where stable_id = owner_id and profession_id = 'leatherworker';
 alter table public.player_professions enable trigger guard_profession_progress_regression;
end $$;

commit;
