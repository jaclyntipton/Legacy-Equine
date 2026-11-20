create or replace function public.admin_get_badger_face_balance() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.require_admin();
  return (select jsonb_build_object(
    'enabled', coalesce(metadata->>'generation_enabled'='true',false),
    'percent', coalesce((metadata->>'appearance_percent')::numeric,0.1),
    'rarity', coalesce(metadata->>'rarity','rare')
  ) from public.equine_visual_taxonomy where category='face_marking' and trait_key='badger_face_01');
end
$$;

create or replace function public.admin_set_badger_face_balance(p_enabled boolean, p_percent numeric, p_rarity text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin();
  if p_rarity is null or p_rarity not in ('common','uncommon','rare','exceptional') then
    raise exception 'Choose a valid rarity';
  end if;
  if p_enabled is null or p_percent is null or p_percent < 0 or p_percent > 100
    or (p_enabled and p_percent = 0) then
    raise exception 'Enter a valid appearance rate. Enabled generation must be above 0%%.';
  end if;
  update public.equine_visual_taxonomy
  set metadata = metadata || jsonb_build_object('generation_enabled',p_enabled,'appearance_percent',p_percent,'rarity',p_rarity)
  where category='face_marking' and trait_key='badger_face_01';
  if not found then raise exception 'Badger Face is not registered'; end if;
  return jsonb_build_object('enabled',p_enabled,'percent',p_percent,'rarity',p_rarity);
end
$$;

revoke all on function public.admin_set_badger_face_balance(boolean,numeric,text) from public, anon, authenticated;
grant execute on function public.admin_set_badger_face_balance(boolean,numeric,text) to authenticated;
