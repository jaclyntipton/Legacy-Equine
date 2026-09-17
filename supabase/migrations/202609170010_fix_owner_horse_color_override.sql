-- Make Owner coat/color edits authoritative. The former RPC accepted `color` but
-- deliberately left the row unchanged unless callers also supplied genetics and
-- a phenotype override, then recorded that no-op as a successful audit event.

alter function public.owner_edit_horse(uuid,jsonb,text,boolean)
  rename to owner_edit_horse_core_20260917;

create or replace function public.owner_color_override_genetics(
  p_existing jsonb,
  p_requested text
) returns jsonb
language plpgsql immutable
set search_path=public
as $$
declare
  requested text:=lower(trim(coalesce(p_requested,'')));
  desired jsonb;
  result jsonb:=coalesce(p_existing,'{}'::jsonb);
  locus text;
begin
  if requested='' then raise exception 'Coat color is required';end if;

  -- Gray is a progressive dominant modifier over the existing base coat. Keep
  -- Extension/Agouti and every other locus intact so Bay -> Gray remains a Bay
  -- base genetically instead of fabricating a replacement base genotype.
  if requested in('gray','grey') or requested like 'gray (%' or requested like 'grey (%' then
    return jsonb_set(result,'{Gray}','["G","N"]'::jsonb,true);
  end if;

  desired:=public.genetics_for_visual(replace(requested,'grey','gray'),'');
  foreach locus in array array['Extension','Agouti','Cream','Dun','Champagne','Silver','Pearl','Gray','Roan'] loop
    if desired?locus then result:=jsonb_set(result,array[locus],desired->locus,true);end if;
  end loop;

  if lower(public.genetic_color(result))<>replace(requested,'grey','gray') then
    raise exception 'Unsupported coat color %. Use the Genetics editor for a custom genotype.',p_requested;
  end if;
  return result;
end$$;

create or replace function public.owner_edit_horse(
  p_horse_id uuid,
  p_changes jsonb,
  p_reason text default '',
  p_confirm_high_impact boolean default false
) returns public.horses
language plpgsql security definer
set search_path=public
as $$
declare
  requested_color text;
  current_genetics jsonb;
  effective_changes jsonb:=coalesce(p_changes,'{}'::jsonb);
  result public.horses;
begin
  perform public.require_horse_editor();

  if effective_changes?'color' then
    requested_color:=trim(effective_changes->>'color');
    select h.genetics into current_genetics from public.horses h where h.id=p_horse_id for update;
    if not found then raise exception 'Horse not found';end if;
    effective_changes:=jsonb_set(
      effective_changes,
      '{genetics}',
      public.owner_color_override_genetics(current_genetics,requested_color),
      true
    );
  end if;

  result:=public.owner_edit_horse_core_20260917(
    p_horse_id,
    effective_changes,
    p_reason,
    p_confirm_high_impact
  );

  -- This assertion runs in the same transaction as the mutation and audit. Any
  -- mismatch rolls both back, so a no-op can never leave a success audit behind.
  if requested_color is not null then
    if lower(replace(requested_color,'grey','gray')) in('gray','gray (bay base)','gray (black base)','gray (chestnut base)') then
      if public.gene_count(result.genetics,'Gray','G')=0 or result.color not like 'Gray (% base)' then
        raise exception 'The requested gray phenotype did not persist';
      end if;
    elsif lower(result.color)<>lower(replace(requested_color,'grey','gray')) then
      raise exception 'The requested coat phenotype did not persist';
    end if;
  end if;

  return result;
end$$;

revoke all on function public.owner_color_override_genetics(jsonb,text),public.owner_edit_horse(uuid,jsonb,text,boolean) from public;
grant execute on function public.owner_edit_horse(uuid,jsonb,text,boolean) to authenticated;

comment on function public.owner_edit_horse(uuid,jsonb,text,boolean) is
'Transactional Owner Horse Editor mutation. Color requests are converted to authoritative genetics before phenotype derivation and audit.';
