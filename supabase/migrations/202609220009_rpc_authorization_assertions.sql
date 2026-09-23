-- Production assertions and auditable summary for the RPC authorization pass.
do $audit$
declare
  v_total integer;
  v_definer integer;
  v_anon integer;
  v_authenticated integer;
  v_public integer;
  v_unsafe_path integer;
begin
  select count(*) filter (where p.prokind = 'f'),
         count(*) filter (where p.prokind = 'f' and p.prosecdef),
         count(*) filter (where p.prokind = 'f' and has_function_privilege('anon', p.oid, 'execute')),
         count(*) filter (where p.prokind = 'f' and has_function_privilege('authenticated', p.oid, 'execute')),
         count(*) filter (where p.prokind = 'f' and has_function_privilege('public', p.oid, 'execute')),
         count(*) filter (
           where p.prokind = 'f' and p.prosecdef
             and not exists (
               select 1 from unnest(coalesce(p.proconfig, array[]::text[])) setting
               where setting like 'search_path=%'
             )
         )
    into v_total, v_definer, v_anon, v_authenticated, v_public, v_unsafe_path
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public';

  if v_total <> 344 then
    raise exception 'RPC inventory drift: expected 344, found %', v_total;
  end if;
  if v_definer <> 297 then
    raise exception 'SECURITY DEFINER inventory drift: expected 297, found %', v_definer;
  end if;
  if v_public <> 0 then
    raise exception 'PUBLIC retains execute on % exposed functions', v_public;
  end if;
  if v_unsafe_path <> 0 then
    raise exception '% SECURITY DEFINER functions lack fixed safe search_path', v_unsafe_path;
  end if;

  raise notice 'RPC authorization inventory: total=%, security_definer=%, anon=%, authenticated=%, public=%',
    v_total, v_definer, v_anon, v_authenticated, v_public;
end
$audit$;
