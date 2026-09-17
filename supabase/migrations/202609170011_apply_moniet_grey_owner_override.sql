-- Apply the Owner-requested Moniet El Nefous Bay -> Grey correction through the
-- same authoritative genotype/phenotype mechanism repaired in 202609170010.
-- This is intentionally the only production horse changed by this migration.

alter table public.horse_edit_audit
  add column if not exists result text not null default 'success'
  check(result in('success','failed'));

do $$
declare
  v_owner_id uuid;
  matches integer;
  old_h public.horses;
  new_h public.horses;
begin
  select s.id into v_owner_id from public.stables s where s.account_number=1;
  if v_owner_id is null then raise exception 'Owner Account #1 was not found';end if;

  select count(*) into matches
  from public.horses h
  where h.name ilike '%Moniet%';
  if matches<>1 then
    raise exception 'Expected exactly one horse matching Moniet; found %',matches;
  end if;

  select * into old_h
  from public.horses h
  where h.name ilike '%Moniet%'
  for update;

  update public.horses h
  set genetics=public.owner_color_override_genetics(h.genetics,'Grey')
  where h.id=old_h.id
  returning * into new_h;

  if public.gene_count(new_h.genetics,'Gray','G')=0
     or new_h.color not like 'Gray (% base)'
     or new_h.visual_phenotype->>'color' not like 'Gray (% base)' then
    raise exception 'Moniet El Nefous Grey phenotype failed authoritative verification';
  end if;

  insert into public.horse_edit_audit(
    horse_id,horse_name,actor_id,actor_account,action,changed_fields,
    old_values,new_values,reason,result
  ) values(
    new_h.id,new_h.name,v_owner_id,1,'horse_edit',array['color','genetics'],
    to_jsonb(old_h),to_jsonb(new_h),'Owner-requested Bay to Grey correction','success'
  );

  raise notice 'Verified Moniet El Nefous id=% color=% base Extension=% Agouti=%',
    new_h.id,new_h.color,new_h.genetics->'Extension',new_h.genetics->'Agouti';
end$$;
