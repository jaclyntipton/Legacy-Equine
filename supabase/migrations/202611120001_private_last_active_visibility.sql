-- Private player activity visibility: self plus Community staff only.
alter table public.stables
  add column if not exists last_active_at timestamptz;

update public.stables s
set last_active_at = coalesce(
  (select u.last_sign_in_at from auth.users u where u.id = s.id),
  s.created_at
)
where s.last_active_at is null;

alter table public.stables
  alter column last_active_at set default now(),
  alter column last_active_at set not null;

create or replace function public.touch_my_last_active()
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  activity_time timestamptz;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  update public.stables
  set last_active_at = clock_timestamp()
  where id = auth.uid()
    and last_active_at < clock_timestamp() - interval '2 minutes'
  returning last_active_at into activity_time;

  if activity_time is null then
    select last_active_at into activity_time
    from public.stables
    where id = auth.uid();
  end if;

  return activity_time;
end
$$;

create or replace function public.get_public_player_profile(p_stable uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  s public.stables;
  b public.stable_brands;
  can_view_activity boolean;
begin
  select * into s
  from public.stables
  where id = p_stable and account_status = 'active';

  if not found then
    raise exception 'Player profile not found';
  end if;

  select * into b
  from public.stable_brands
  where stable_id = s.id and (active or reserved);

  can_view_activity := auth.uid() = s.id or exists(
    select 1
    from public.stables viewer
    where viewer.id = auth.uid()
      and (
        viewer.is_admin
        or viewer.account_number = 1
        or viewer.community_role in ('moderator', 'admin', 'owner')
      )
  );

  return jsonb_build_object(
    'id', s.id,
    'username', s.username,
    'account_number', s.account_number,
    'avatar_url', s.avatar_url,
    'bio', s.bio,
    'established_at', s.created_at,
    'account_level', public.account_level_for_xp(s.account_xp),
    'stable_name', s.name,
    'brand', case when b.id is null then null else jsonb_build_object('code', b.code, 'mark_url', b.mark_url) end,
    'horse_count', (select count(*) from public.horses h where h.owner_id = s.id and not h.retired),
    'owner', auth.uid() = s.id,
    'last_active_at', case when can_view_activity then s.last_active_at else null end,
    'services', public.get_public_professional_services(s.id)
  );
end
$$;

drop function if exists public.admin_list_stables();
create function public.admin_list_stables()
returns table(
  id uuid,
  account_number bigint,
  name text,
  username text,
  balance bigint,
  is_admin boolean,
  stable_occupied bigint,
  stable_capacity bigint,
  unlimited_capacity boolean,
  can_edit_horses boolean,
  last_active_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.require_admin();
  return query
  select
    s.id,
    s.account_number,
    s.name,
    s.username,
    s.balance,
    s.is_admin,
    c.occupied,
    c.total_capacity,
    c.unlimited,
    (
      s.account_number = 1
      or exists(
        select 1 from public.staff_permissions p
        where p.stable_id = s.id and p.permission = 'horse_editor'
      )
    ),
    s.last_active_at
  from public.stables s
  cross join lateral public.stable_capacity(s.id) c
  where s.account_number is not null
  order by s.account_number;
end
$$;

revoke all on function public.touch_my_last_active() from public, anon;
grant execute on function public.touch_my_last_active() to authenticated;

revoke all on function public.get_public_player_profile(uuid) from public, anon;
grant execute on function public.get_public_player_profile(uuid) to authenticated;

revoke all on function public.admin_list_stables() from public, anon;
grant execute on function public.admin_list_stables() to authenticated;
