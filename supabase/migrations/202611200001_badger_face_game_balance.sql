insert into public.equine_visual_taxonomy(category,trait_key,display_name,family,sort_order,metadata,active)
values ('face_marking','badger_face_01','Badger Face','face',130,
  '{"breed":"Quarter Horse","rarity":"rare","game_only":true,"generation_enabled":false,"appearance_percent":0.1}',true)
on conflict (category,trait_key) do nothing;

create or replace function public.admin_get_badger_face_balance() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.require_admin();
  return (select jsonb_build_object(
    'enabled', coalesce(metadata->>'generation_enabled'='true',false),
    'percent', coalesce((metadata->>'appearance_percent')::numeric,0.1)
  ) from public.equine_visual_taxonomy where category='face_marking' and trait_key='badger_face_01');
end
$$;

create or replace function public.admin_set_badger_face_balance(p_enabled boolean, p_percent numeric) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin();
  if p_enabled is null or p_percent is null or p_percent < 0 or p_percent > 100
    or (p_enabled and p_percent = 0) then
    raise exception 'Enter a valid appearance rate. Enabled generation must be above 0%%.';
  end if;
  update public.equine_visual_taxonomy
  set metadata = metadata || jsonb_build_object('generation_enabled',p_enabled,'appearance_percent',p_percent)
  where category='face_marking' and trait_key='badger_face_01';
  if not found then raise exception 'Badger Face is not registered'; end if;
  return jsonb_build_object('enabled',p_enabled,'percent',p_percent);
end
$$;

revoke all on function public.admin_get_badger_face_balance(), public.admin_set_badger_face_balance(boolean,numeric)
from public, anon, authenticated;
grant execute on function public.admin_get_badger_face_balance(), public.admin_set_badger_face_balance(boolean,numeric)
to authenticated;

create or replace function public.random_horse_markings(g jsonb,b text default null) returns jsonb language plpgsql volatile set search_path=public as $$declare white_bias numeric:=case when gene_count(g,'Sabino1','SB1')>0 or gene_count(g,'Splash1','SW1')>0 or gene_count(g,'Frame','O')>0 then .55 else .22 end;face_options text[]:=case when b='Rocky Mountain Horse'then array['snip_01','faint_01','faint_star_01','star_01','half_star_01','strip_01']else array['snip_01','faint_01','faint_star_01','star_01','half_star_01','strip_01','broken_strip_01','star_strip_01','blaze_01','blaze_snip_01','irregular_blaze_01','bald_face_01']end;leg_options text[]:=array['coronet_01','white_heel_01','half_pastern_01','pastern_01','ankle_01','half_sock_01','full_sock_01','high_sock_01'];begin return jsonb_build_object('face',case when b='Quarter Horse' and random()<coalesce((select case when metadata->>'generation_enabled'='true' then (metadata->>'appearance_percent')::numeric / 100 else 0 end from public.equine_visual_taxonomy where category='face_marking' and trait_key='badger_face_01' and active),0) then 'badger_face_01' when random()<white_bias then face_options[1+floor(random()*array_length(face_options,1))::int]else'none'end,'left_front',case when b='Rocky Mountain Horse'then'none'when random()<white_bias then leg_options[1+floor(random()*array_length(leg_options,1))::int]else'none'end,'right_front',case when b='Rocky Mountain Horse'then'none'when random()<white_bias then leg_options[1+floor(random()*array_length(leg_options,1))::int]else'none'end,'left_hind',case when b='Rocky Mountain Horse'then'none'when random()<white_bias then leg_options[1+floor(random()*array_length(leg_options,1))::int]else'none'end,'right_hind',case when b='Rocky Mountain Horse'then'none'when random()<white_bias then leg_options[1+floor(random()*array_length(leg_options,1))::int]else'none'end);end$$;
