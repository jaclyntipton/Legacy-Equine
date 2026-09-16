-- Exact, timestamp-derived Age 2 gameplay boundary. Client state is never trusted.
create or replace function public.train_horse(target_horse uuid,stat_name text) returns public.horses language plpgsql security definer set search_path=public as $$
declare h horses;precise_age numeric;begin
 select * into h from horses where id=target_horse for update;
 if not found or h.owner_id<>auth.uid() then raise exception 'Horse not found or not owned';end if;
 precise_age:=horse_game_age(h.birth_date);
 if precise_age<2 then raise exception 'Too young to train. Training becomes available at age 2.';end if;
 if not exists(select 1 from stat_definitions where key=stat_name and active)then raise exception 'Invalid stat';end if;
 if h.last_trained_at is not null and h.last_trained_at>now()-interval '20 hours' then raise exception 'Training cooldown active';end if;
 update horses set stats=jsonb_set(stats,array[stat_name],to_jsonb(coalesce((stats->>stat_name)::int,0)+1)),last_trained_at=now() where id=h.id returning * into h;
 insert into training_log(horse_id,stable_id,stat_key,gain)values(h.id,auth.uid(),stat_name,1);return h;
end$$;

-- Preserve the complete authoritative breeding transaction while changing only
-- its exact lower boundary and player-safe explanation.
do $$declare definition text;begin
 select pg_get_functiondef('public.breed_horses(uuid,uuid)'::regprocedure) into definition;
 definition:=replace(definition,'sire_age<3','sire_age<2');
 definition:=replace(definition,'dam_age<3','dam_age<2');
 definition:=replace(definition,'Eligible at age 3.','Eligible at age 2.');
 execute definition;
end$$;

revoke all on function public.train_horse(uuid,text),public.breed_horses(uuid,uuid) from public;
grant execute on function public.train_horse(uuid,text),public.breed_horses(uuid,uuid) to authenticated;
