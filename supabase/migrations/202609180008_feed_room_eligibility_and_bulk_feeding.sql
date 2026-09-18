-- Feed Room eligibility and atomic one-or-many development feeding.

create or replace function public.get_feed_room_eligibility()
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  today date := (now() at time zone 'America/New_York')::date;
begin
  return jsonb_build_object(
    'le_day', today,
    'eligible_horse_ids', coalesce((
      select jsonb_agg(h.id order by h.name, h.id)
      from horses h
      where h.owner_id=auth.uid()
        and not exists(
          select 1 from horse_feed_log f
          where f.horse_id=h.id and f.le_day=today
        )
    ), '[]'::jsonb)
  );
end
$$;

create or replace function public.feed_horses(
  p_horses uuid[],
  p_product text
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  today date := (now() at time zone 'America/New_York')::date;
  requested integer;
  owned integer;
  product store_products;
  horse_record horses;
  item_record player_store_items;
  v_horse_id uuid;
  stat text;
  gain integer;
  before_stats jsonb;
  after_stats jsonb;
  success boolean;
  results jsonb := '[]'::jsonb;
begin
  if auth.uid() is null then raise exception 'Sign in to feed horses'; end if;

  requested := coalesce(cardinality(p_horses), 0);
  if requested < 1 then raise exception 'Select at least one eligible horse'; end if;
  if requested <> (select count(distinct value) from unnest(p_horses) value) then
    raise exception 'Each horse may only be selected once';
  end if;

  select * into product
  from store_products
  where id=p_product and department='feed' and active
  for share;
  if not found then raise exception 'This Feed & Hay product is unavailable'; end if;

  -- Lock in a stable order before checking eligibility so concurrent submissions
  -- cannot feed the same horse twice. The unique horse/day constraint remains the
  -- final authoritative guard.
  for horse_record in
    select h.* from horses h
    where h.id=any(p_horses)
    order by h.id
    for update
  loop
    if horse_record.owner_id<>auth.uid() then raise exception 'Choose horses you own'; end if;
  end loop;
  if (select count(*) from horses h where h.id=any(p_horses) and h.owner_id=auth.uid())<>requested then
    raise exception 'Choose horses you own';
  end if;
  if exists(
    select 1 from horse_feed_log f
    where f.horse_id=any(p_horses) and f.le_day=today
  ) then
    raise exception 'One or more selected horses already received today''s Development Feeding';
  end if;

  select count(*) into owned
  from player_store_items i
  where i.stable_id=auth.uid() and i.product_id=p_product and i.consumed_at is null;
  if owned<requested then
    raise exception '% units required • % available', requested, owned;
  end if;

  for v_horse_id in select value from unnest(p_horses) value order by value
  loop
    select * into item_record
    from player_store_items i
    where i.stable_id=auth.uid() and i.product_id=p_product and i.consumed_at is null
    order by i.purchased_at, i.id
    limit 1
    for update skip locked;
    if not found then raise exception '% units required • fewer than % available', requested, requested; end if;

    select * into horse_record from horses where id=v_horse_id;
    before_stats:=horse_record.stats;
    success:=random()<product.feed_success_probability;
    stat:=null;
    gain:=0;
    after_stats:=before_stats;
    if success then
      stat:=product.eligible_stats[1+floor(random()*cardinality(product.eligible_stats))::integer];
      gain:=product.development_min+floor(random()*(product.development_max-product.development_min+1))::integer;
      after_stats:=jsonb_set(before_stats,array[stat],to_jsonb(coalesce((before_stats->>stat)::integer,0)+gain));
      update horses set stats=after_stats where id=v_horse_id;
    end if;

    update player_store_items set consumed_at=now() where id=item_record.id;
    insert into horse_feed_log(horse_id,stable_id,item_id,product_id,le_day,result,stat_affected,development_amount,stats_before,stats_after)
    values(v_horse_id,auth.uid(),item_record.id,product.id,today,case when success then 'development' else 'no_change' end,stat,gain,before_stats,after_stats);
    results:=results||jsonb_build_array(jsonb_build_object('horse_id',v_horse_id,'success',success,'stat',stat,'gain',gain));
  end loop;

  return jsonb_build_object(
    'fed', requested,
    'le_day', today,
    'results', results,
    'next_eligible', ((today+1)::timestamp at time zone 'America/New_York')
  );
end
$$;

revoke all on function public.get_feed_room_eligibility(), public.feed_horses(uuid[],text) from public;
grant execute on function public.get_feed_room_eligibility(), public.feed_horses(uuid[],text) to authenticated;
