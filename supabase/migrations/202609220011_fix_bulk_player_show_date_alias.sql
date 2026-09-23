-- Resolve the PL/pgSQL variable / SQL range-variable collision in the bulk
-- show quota date expansion. No show creation behavior changes.
create or replace function public.bulk_create_player_shows(
  p_name_prefix text,
  p_discipline_ids text[],
  p_tier_ids text[],
  p_run_dates date[],
  p_entry_fee integer default 0,
  p_max_entries integer default null,
  p_description text default ''
) returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  s stables;
  progress jsonb;
  d text;
  t text;
  rd date;
  created uuid[] := '{}';
  one player_shows;
  total integer;
  cfg economy_config;
begin
  select * into s from stables where id=auth.uid() for update;
  progress := get_account_progression();
  if not (progress->>'bulk_show_creation')::boolean then
    raise exception 'Bulk show creation unlocks at Account Level 15';
  end if;

  total := cardinality(p_discipline_ids)*cardinality(p_tier_ids)*cardinality(p_run_dates);
  if total<1 then raise exception 'Choose at least one discipline, tier, and date'; end if;
  if total>100 and not is_owner_account(s.id) then
    raise exception 'A bulk set may contain at most 100 shows';
  end if;

  perform assert_show_host_quota(
    s.id,
    total,
    (
      select array_agg(expanded_date.run_date_value)
      from unnest(p_run_dates) as expanded_date(run_date_value)
      cross join generate_series(
        1,
        cardinality(p_discipline_ids)*cardinality(p_tier_ids)
      ) as repeated_date(ordinal)
    )
  );

  select * into cfg from economy_config where id=true;
  if s.balance<cfg.show_hosting_fee*total then
    raise exception 'Insufficient LED for all hosting fees';
  end if;

  foreach rd in array p_run_dates loop
    foreach d in array p_discipline_ids loop
      foreach t in array p_tier_ids loop
        if not exists(select 1 from show_disciplines where id=d and active)
          or not exists(select 1 from show_tiers where id=t and active) then
          raise exception 'A selected discipline or tier is unavailable';
        end if;
      end loop;
    end loop;
  end loop;

  if cfg.show_hosting_fee*total>0 then
    update stables set balance=balance-cfg.show_hosting_fee*total where id=s.id;
    insert into currency_ledger(stable_id,amount,reason)
    values(s.id,-cfg.show_hosting_fee*total,'Bulk show hosting fees');
  end if;

  foreach rd in array p_run_dates loop
    foreach d in array p_discipline_ids loop
      foreach t in array p_tier_ids loop
        insert into player_shows(
          creator_id,name,discipline_id,tier_id,run_date,run_at,entry_fee,
          max_entries,description,maximum_per_owner
        ) values(
          s.id,
          left(trim(p_name_prefix)||' — '||(select name from show_disciplines where id=d)||' '||(select name from show_tiers where id=t),80),
          d,t,rd,rd::timestamp at time zone 'America/New_York',p_entry_fee,
          p_max_entries,left(coalesce(p_description,''),1000),1000
        ) returning * into one;
        created:=array_append(created,one.id);
      end loop;
    end loop;
  end loop;

  return jsonb_build_object(
    'shows_created',total,
    'show_ids',created,
    'hosting_fees',cfg.show_hosting_fee*total
  );
end
$$;

