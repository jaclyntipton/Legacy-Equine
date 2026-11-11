create or replace function public.get_admin_led_gift_workspace()
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare source public.stables;
begin
 perform public.require_admin();
 select * into source from public.stables s where s.id=auth.uid();
 if not found then raise exception 'Admin player account not found';end if;
 return jsonb_build_object(
  'source',jsonb_build_object('id',source.id,'account_number',source.account_number,'name',source.name,'balance_exact',source.balance::text),
  'recipients',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'account_number',s.account_number,'name',s.name,'username',s.username) order by s.account_number) from public.stables s where s.id<>source.id and s.account_number is not null),'[]'::jsonb)
 );
end$$;

revoke all on function public.get_admin_led_gift_workspace() from public,anon;
grant execute on function public.get_admin_led_gift_workspace() to authenticated;
