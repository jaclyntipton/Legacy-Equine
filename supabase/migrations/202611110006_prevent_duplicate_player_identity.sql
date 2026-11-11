-- Prevent one person from creating multiple player accounts with different emails.
-- Private identity remains server-only and is never exposed through signup availability.
create or replace function public.complete_account_information(p_first_name text,p_last_name text,p_date_of_birth date)returns jsonb language plpgsql security definer set search_path=public as $$
declare first_value text:=trim(coalesce(p_first_name,''));last_value text:=trim(coalesce(p_last_name,''));adult boolean;identity_key text;
begin
 if auth.uid()is null or not exists(select 1 from stables where id=auth.uid())then raise exception'Authenticated account required';end if;
 if exists(select 1 from account_private_identity where account_id=auth.uid())then raise exception'Account information is already complete. Contact Admin through Help & Support for corrections.';end if;
 if length(first_value)not between 1 and 80 or length(last_value)not between 1 and 80 then raise exception'First and last name are required';end if;
 if p_date_of_birth is null or p_date_of_birth>current_date then raise exception'Enter a valid date of birth';end if;
 identity_key:=regexp_replace(lower(first_value),'[^a-z0-9]','','g')||'|'||regexp_replace(lower(last_value),'[^a-z0-9]','','g')||'|'||p_date_of_birth::text;
 perform pg_advisory_xact_lock(hashtextextended(identity_key,0));
 if exists(select 1 from account_private_identity i where i.account_id<>auth.uid()and regexp_replace(lower(trim(i.first_name)),'[^a-z0-9]','','g')=regexp_replace(lower(first_value),'[^a-z0-9]','','g')and regexp_replace(lower(trim(i.last_name)),'[^a-z0-9]','','g')=regexp_replace(lower(last_value),'[^a-z0-9]','','g')and i.date_of_birth=p_date_of_birth)then
  raise exception'An account already exists for this player. Log in, reset your password, or contact Help & Support.';
 end if;
 adult:=account_is_adult(p_date_of_birth,current_date);
 insert into account_private_identity(account_id,first_name,last_name,date_of_birth,age_status,social_allowed)values(auth.uid(),first_value,last_value,p_date_of_birth,case when adult then'adult'else'age_review'end,adult);
 if not adult then update stables set account_status='age_review'where id=auth.uid();end if;
 insert into account_private_identity_audit(account_id,actor_id,action,reason)values(auth.uid(),auth.uid(),'identity.completed',case when adult then'Existing account information completed'else'Existing account requires age-policy review'end);
 return get_my_account_eligibility();
end$$;

create or replace function public.initialize_new_auth_player()returns trigger language plpgsql security definer set search_path=public,auth as $$
declare stable_value text:=trim(coalesce(new.raw_user_meta_data->>'stable_name',''));username_value text:=trim(coalesce(new.raw_user_meta_data->>'username',''));first_value text:=trim(coalesce(new.raw_user_meta_data->>'private_first_name',''));last_value text:=trim(coalesce(new.raw_user_meta_data->>'private_last_name',''));dob date;is_test boolean;identity_key text;
begin
 if stable_value=''and username_value=''then return new;end if;
 if length(stable_value)not between 2 and 60 then raise exception'Stable name must be 2–60 characters';end if;
 if username_value!~'^[A-Za-z0-9_]{3,24}$'then raise exception'Username must be 3–24 letters, numbers, or underscores';end if;
 if length(first_value)not between 1 and 80 or length(last_value)not between 1 and 80 then raise exception'First and last name are required';end if;
 begin dob:=(new.raw_user_meta_data->>'date_of_birth')::date;exception when others then raise exception'Enter a valid date of birth';end;
 if dob>current_date then raise exception'Enter a valid date of birth';end if;
 if not account_is_adult(dob,current_date)then raise exception'Legacy Equine is currently available to players age 18 and older.';end if;
 if exists(select 1 from public.stables where lower(username)=lower(username_value))then raise exception'That username is unavailable';end if;
 identity_key:=regexp_replace(lower(first_value),'[^a-z0-9]','','g')||'|'||regexp_replace(lower(last_value),'[^a-z0-9]','','g')||'|'||dob::text;
 perform pg_advisory_xact_lock(hashtextextended(identity_key,0));
 if exists(select 1 from public.account_private_identity i where regexp_replace(lower(trim(i.first_name)),'[^a-z0-9]','','g')=regexp_replace(lower(first_value),'[^a-z0-9]','','g')and regexp_replace(lower(trim(i.last_name)),'[^a-z0-9]','','g')=regexp_replace(lower(last_value),'[^a-z0-9]','','g')and i.date_of_birth=dob)then
  raise exception'An account already exists for this player. Log in, reset your password, or contact Help & Support.';
 end if;
 is_test:=coalesce(new.email ilike'%+test@%',false)or coalesce(new.email ilike'%+qa@%',false)or coalesce(new.email ilike'%@example.%',false);
 insert into public.stables(id,name,username,balance,account_number,account_xp)values(new.id,stable_value,username_value,3000,case when is_test then null else nextval('public.account_number_seq')end,0);
 insert into public.account_private_identity(account_id,first_name,last_name,date_of_birth,age_status,social_allowed)values(new.id,first_value,last_value,dob,'adult',true);
 insert into public.currency_ledger(stable_id,amount,reason)values(new.id,3000,'Starting funds');
 return new;
end$$;

comment on function public.initialize_new_auth_player is 'Transactionally initializes a genuine LE player and rejects a second account for the same normalized legal name and DOB.';
