-- Atomic multi-horse organization between the private General Barn and public
-- Training Barn. Ownership, capacity, and gameplay eligibility are unchanged.
create or replace function public.move_owned_horses_to_barn(p_horses uuid[],p_barn text)
returns integer language plpgsql security definer set search_path=public as $$
declare requested integer;moved integer;begin
 if p_barn not in('training','general')then raise exception'Choose the Training Barn or General Barn';end if;
 requested:=coalesce(cardinality(p_horses),0);
 if requested<1 or requested>500 then raise exception'Choose between 1 and 500 horses';end if;
 if(select count(distinct horse_id)from unnest(p_horses)as selected(horse_id))<>requested then raise exception'Each horse may be selected once';end if;
 perform 1 from horses h where h.id=any(p_horses)order by h.id for update;
 if(select count(*)from horses h where h.id=any(p_horses)and h.owner_id=auth.uid()and not h.retired)<>requested then raise exception'Every selected horse must be an active horse you own';end if;
 update horses set stable_barn=p_barn where id=any(p_horses)and owner_id=auth.uid()and not retired;
 get diagnostics moved=row_count;
 if moved<>requested then raise exception'Barn move could not be completed';end if;
 return moved;
end$$;
revoke all on function public.move_owned_horses_to_barn(uuid[],text)from public,anon;
grant execute on function public.move_owned_horses_to_barn(uuid[],text)to authenticated;
