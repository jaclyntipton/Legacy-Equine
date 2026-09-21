-- Expose the terminal no-entry outcome through the existing Admin Show workspace.
create or replace function public.admin_show_workspace()returns jsonb
language plpgsql stable security definer set search_path=public as $$
begin
 if not(has_admin_permission('admin.shows.view')or has_show_capability('shows.admin.processing')or has_show_capability('shows.admin.edit'))then raise exception'Show administration permission required';end if;
 return jsonb_build_object(
  'shows',coalesce((select jsonb_agg(jsonb_build_object('id',sh.id,'name',sh.name,'discipline_id',sh.discipline_id,'discipline',d.name,'tier_id',sh.tier_id,'tier',t.name,'run_at',sh.run_at,'run_date',sh.run_date,'entry_fee',sh.entry_fee,'max_entries',sh.max_entries,'description',sh.description,'status',sh.status,'completion_reason',sh.completion_reason,'entry_count',(select count(*)from player_show_entries e where e.show_id=sh.id),'purse',sh.entry_fee_purse+sh.show_fund_allocation+sh.treasury_allocation,'locked',sh.locked_at is not null,'is_private',sh.is_private,'is_admin_qa',sh.is_admin_qa,'processed_at',sh.processed_at,'cancelled_at',sh.cancelled_at)order by sh.run_at desc)from player_shows sh join show_disciplines d on d.id=sh.discipline_id join show_tiers t on t.id=sh.tier_id),'[]'::jsonb),
  'audit',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'show_id',a.show_id,'show_name',sh.name,'actor',s.name,'actor_account',s.account_number,'action',a.action,'details',a.details,'created_at',a.created_at)order by a.created_at desc)from show_admin_audit a left join player_shows sh on sh.id=a.show_id join stables s on s.id=a.actor_id limit 300),'[]'::jsonb),
  'allowlist',coalesce((select jsonb_agg(jsonb_build_object('stable_id',q.stable_id,'name',s.name,'account_number',s.account_number,'active',q.active,'note',q.note)order by s.account_number)from show_qa_allowlist q join stables s on s.id=q.stable_id),'[]'::jsonb),
  'accounts',coalesce((select jsonb_agg(jsonb_build_object('stable_id',s.id,'name',s.name,'account_number',s.account_number)order by s.account_number)from stables s where s.account_number is not null),'[]'::jsonb),
  'capabilities',get_show_capabilities()
 );
end$$;

revoke all on function public.admin_show_workspace()from public;
grant execute on function public.admin_show_workspace()to authenticated;

