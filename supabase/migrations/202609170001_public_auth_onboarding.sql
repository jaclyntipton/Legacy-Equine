alter table public.stables alter column balance set default 3000;

create or replace function public.public_signup_availability(p_username text,p_stable_name text)returns jsonb language plpgsql stable security definer set search_path=public as $$
declare normalized text:=trim(coalesce(p_username,''));stable_value text:=trim(coalesce(p_stable_name,''));
begin
 if normalized!~'^[A-Za-z0-9_]{3,24}$'then raise exception 'Username must be 3–24 letters, numbers, or underscores';end if;
 if length(stable_value)not between 2 and 60 then raise exception 'Stable name must be 2–60 characters';end if;
 return jsonb_build_object('username_available',not exists(select 1 from stables where lower(username)=lower(normalized)),'stable_name_valid',true);
end$$;

create or replace function public.initialize_new_auth_player()returns trigger language plpgsql security definer set search_path=public,auth as $$
declare stable_value text:=trim(coalesce(new.raw_user_meta_data->>'stable_name',''));username_value text:=trim(coalesce(new.raw_user_meta_data->>'username',''));is_test boolean;
begin
 if stable_value=''and username_value=''then return new;end if;
 if length(stable_value)not between 2 and 60 then raise exception 'Stable name must be 2–60 characters';end if;
 if username_value!~'^[A-Za-z0-9_]{3,24}$'then raise exception 'Username must be 3–24 letters, numbers, or underscores';end if;
 if exists(select 1 from public.stables where lower(username)=lower(username_value))then raise exception 'That username is unavailable';end if;
 is_test:=coalesce(new.email ilike '%+test@%',false)or coalesce(new.email ilike '%+qa@%',false)or coalesce(new.email ilike '%@example.%',false);
 insert into public.stables(id,name,username,balance,account_number,account_xp)values(new.id,stable_value,username_value,3000,case when is_test then null else nextval('public.account_number_seq')end,0);
 insert into public.currency_ledger(stable_id,amount,reason)values(new.id,3000,'Starting funds');
 return new;
end$$;

drop trigger if exists initialize_legacy_equine_player on auth.users;
create trigger initialize_legacy_equine_player after insert on auth.users for each row execute function public.initialize_new_auth_player();

create or replace function public.initialize_stable(stable_name text)returns public.stables language plpgsql security definer set search_path=public as $$
declare result public.stables;is_test boolean;
begin
 if auth.uid()is null then raise exception 'Authentication required';end if;
 select * into result from stables where id=auth.uid();if found then return result;end if;
 if length(trim(stable_name))not between 2 and 60 then raise exception 'Stable name must be 2–60 characters';end if;
 is_test:=coalesce((auth.jwt()->>'email')ilike'%+test@%',false)or coalesce((auth.jwt()->>'email')ilike'%+qa@%',false)or coalesce((auth.jwt()->>'email')ilike'%@example.%',false);
 insert into stables(id,name,balance,account_number,account_xp)values(auth.uid(),trim(stable_name),3000,case when is_test then null else nextval('account_number_seq')end,0)returning * into result;
 insert into currency_ledger(stable_id,amount,reason)values(auth.uid(),3000,'Starting funds');return result;
end$$;

revoke all on function public.public_signup_availability(text,text)from public;
grant execute on function public.public_signup_availability(text,text)to anon,authenticated;
revoke all on function public.initialize_stable(text)from public;
grant execute on function public.initialize_stable(text)to authenticated;
comment on function public.initialize_new_auth_player is 'Transactionally initializes genuine LE players during Auth creation: stable, sequential public number, username, Level 1/0 XP defaults, 3,000 LED ledger, and capacity trigger.';
