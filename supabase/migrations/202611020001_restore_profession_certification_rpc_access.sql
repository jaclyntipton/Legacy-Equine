-- Restore the authenticated certification endpoints omitted from the explicit
-- browser RPC allowlist. Each function remains self-scoped or server-authorized.
do $migration$
declare
  v_names text[] := array[
    'get_certification_questions',
    'take_certification_test',
    'get_profession_qa_questions',
    'grade_profession_qa_test'
  ];
  v_record record;
begin
  for v_record in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.prokind='f'
      and p.proname=any(v_names)
  loop
    execute format('grant execute on function %s to authenticated',v_record.signature);
  end loop;

  if exists(
    select 1
    from unnest(v_names) wanted(name)
    where not exists(
      select 1
      from pg_proc p
      join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='public'
        and p.prokind='f'
        and p.proname=wanted.name
        and has_function_privilege('authenticated',p.oid,'execute')
    )
  ) then
    raise exception 'Profession certification RPC access was not fully restored';
  end if;
end
$migration$;
