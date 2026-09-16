-- PostgREST cannot disambiguate a no-argument overload from a function whose
-- only argument has a default. Keep the breed-aware API as the single source.
drop function if exists public.get_store_inventory();

grant execute on function public.get_store_inventory(text) to authenticated;
