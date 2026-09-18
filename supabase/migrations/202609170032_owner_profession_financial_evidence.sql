-- Read-only financial corroboration for Owner #1 profession activity.
create or replace function public.admin_owner_profession_financial_evidence()
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare owner_id uuid;
begin
 if not exists(select 1 from stables where id=auth.uid()and(is_admin or account_number=1)) then raise exception 'Administrator access required';end if;
 select id into owner_id from stables where account_number=1;
 return jsonb_build_object(
  'player_ledger',coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'amount',l.amount,'reason',l.reason,'created_at',l.created_at)order by l.created_at)from currency_ledger l where l.stable_id=owner_id and(lower(l.reason)like'%farrier%'or lower(l.reason)like'%certification%')),'[]'::jsonb),
  'fund_ledger',coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'fund_id',l.fund_id,'amount',l.amount,'reason',l.reason,'created_at',l.created_at)order by l.created_at)from system_fund_ledger l where l.initiated_by=owner_id and(lower(l.reason)like'%farrier%'or lower(l.reason)like'%certification%')),'[]'::jsonb),
  'admin_audit',coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'action_type',l.action_type,'system',l.system,'details',l.details,'created_at',l.created_at)order by l.created_at)from admin_audit_log l where l.actor_id=owner_id and(lower(l.system)like'%profession%'or lower(l.action_type)like'%profession%')),'[]'::jsonb)
 );
end$$;
revoke all on function public.admin_owner_profession_financial_evidence() from public;
grant execute on function public.admin_owner_profession_financial_evidence() to authenticated;
