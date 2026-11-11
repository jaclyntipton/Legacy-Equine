-- Synchronize a phone only after Supabase Auth/Twilio confirms it.
create or replace function public.require_player_signup_phone()returns trigger language plpgsql security definer set search_path=public,auth as $$
declare player_signup boolean:=trim(coalesce(new.raw_user_meta_data->>'stable_name',''))<>''or trim(coalesce(new.raw_user_meta_data->>'username',''))<>'';pending text:=trim(coalesce(new.raw_user_meta_data->>'pending_phone',''));
begin
 if player_signup and pending!~'^\+[1-9][0-9]{7,14}$'then raise exception'A valid phone number is required for player registration';end if;
 return new;
end$$;
drop trigger if exists require_legacy_equine_signup_phone on auth.users;
create trigger require_legacy_equine_signup_phone before insert on auth.users for each row execute function public.require_player_signup_phone();

create or replace function public.sync_my_verified_phone()returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare verified_phone text;confirmed_at timestamptz;
begin
 if auth.uid()is null then raise exception'Authentication required';end if;
 select phone,phone_confirmed_at into verified_phone,confirmed_at from auth.users where id=auth.uid();
 if verified_phone is null or confirmed_at is null then raise exception'Phone verification is not complete';end if;
 update public.stables set phone_e164=verified_phone,phone_verified_at=confirmed_at where id=auth.uid();
 if not found then raise exception'Player account not found';end if;
 return jsonb_build_object('verified',true,'verified_at',confirmed_at);
exception when unique_violation then raise exception'This phone number is already verified for another Legacy Equine account';
end$$;
revoke all on function public.sync_my_verified_phone()from public;
grant execute on function public.sync_my_verified_phone()to authenticated;
comment on function public.sync_my_verified_phone is 'Copies only an Auth-confirmed phone into the caller player record; client-supplied phone values are never trusted.';
