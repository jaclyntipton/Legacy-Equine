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

commit;
