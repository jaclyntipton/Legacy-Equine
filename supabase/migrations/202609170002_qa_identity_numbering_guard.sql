create or replace function public.is_nonpublic_test_email(email_value text)returns boolean language sql immutable set search_path=public as $$
 select coalesce(email_value~*'\+(qa|test)[^@]*@',false)or coalesce(email_value ilike'%@example.%',false)
$$;

update public.stables s set account_number=null from auth.users u where u.id=s.id and public.is_nonpublic_test_email(u.email);
select setval('public.account_number_seq',coalesce((select max(account_number)from public.stables where account_number is not null),1),true);

create or replace function public.initialize_new_auth_player()returns trigger language plpgsql security definer set search_path=public,auth as $$
declare stable_value text:=trim(coalesce(new.raw_user_meta_data->>'stable_name',''));username_value text:=trim(coalesce(new.raw_user_meta_data->>'username',''));is_test boolean;
begin
 if stable_value=''and username_value=''then return new;end if;
 if length(stable_value)not between 2 and 60 then raise exception 'Stable name must be 2–60 characters';end if;
 if username_value!~'^[A-Za-z0-9_]{3,24}$'then raise exception 'Username must be 3–24 letters, numbers, or underscores';end if;
 if exists(select 1 from public.stables where lower(username)=lower(username_value))then raise exception 'That username is unavailable';end if;
 is_test:=public.is_nonpublic_test_email(new.email);
 insert into public.stables(id,name,username,balance,account_number,account_xp)values(new.id,stable_value,username_value,3000,case when is_test then null else nextval('public.account_number_seq')end,0);
 insert into public.currency_ledger(stable_id,amount,reason)values(new.id,3000,'Starting funds');return new;
end$$;

create or replace function public.initialize_stable(stable_name text)returns public.stables language plpgsql security definer set search_path=public as $$
declare result public.stables;is_test boolean;
begin
 if auth.uid()is null then raise exception 'Authentication required';end if;select * into result from stables where id=auth.uid();if found then return result;end if;
 if length(trim(stable_name))not between 2 and 60 then raise exception 'Stable name must be 2–60 characters';end if;
 is_test:=public.is_nonpublic_test_email(auth.jwt()->>'email');
 insert into stables(id,name,balance,account_number,account_xp)values(auth.uid(),trim(stable_name),3000,case when is_test then null else nextval('account_number_seq')end,0)returning * into result;
 insert into currency_ledger(stable_id,amount,reason)values(auth.uid(),3000,'Starting funds');return result;
end$$;

revoke all on function public.is_nonpublic_test_email(text)from public;grant execute on function public.is_nonpublic_test_email(text)to service_role;
