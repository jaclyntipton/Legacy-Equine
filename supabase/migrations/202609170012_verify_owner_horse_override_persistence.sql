-- Separate post-commit verification: this migration runs only after the Moniet
-- correction transaction committed, mirroring a fresh profile/database reload.
do $$
declare
  persisted public.horses;
begin
  select * into persisted
  from public.horses h
  where h.name ilike '%Moniet%';

  if not found
     or public.gene_count(persisted.genetics,'Gray','G')=0
     or persisted.color not like 'Gray (% base)'
     or persisted.visual_phenotype->>'color'<>persisted.color then
    raise exception 'Post-commit Moniet Grey persistence verification failed';
  end if;

  if not exists(
    select 1 from public.horse_edit_audit a
    where a.horse_id=persisted.id
      and a.reason='Owner-requested Bay to Grey correction'
      and a.result='success'
      and a.new_values->>'color'=persisted.color
  ) then
    raise exception 'Committed mutation is missing its matching success audit';
  end if;
end$$;
