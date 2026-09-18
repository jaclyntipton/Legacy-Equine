-- pg_cron runs without an Auth JWT. The planner remains capability-gated for
-- authenticated callers while allowing the service-only scheduler function.
create or replace function public.show_auto_host_plan()returns jsonb language plpgsql stable security definer set search_path=public as $$
declare c show_auto_host_config;row record;items jsonb:='[]';current_count integer;wanted integer;create_count integer;total_current integer:=0;total_target integer:=0;total_create integer:=0;combo_count integer:=0;
begin if auth.uid()is not null and not has_show_capability('shows.admin.auto_host')then raise exception'Auto Host permission required';end if;select * into c from show_auto_host_config where id=true;
 for row in select x.*,d.name discipline,t.name tier from show_auto_host_combinations x join show_disciplines d on d.id=x.discipline_id join show_tiers t on t.id=x.tier_id where d.active and t.active and(case when c.selection_mode='full'then true else x.enabled end)order by d.name,t.sort_order loop
  wanted:=case when c.selection_mode='full'then c.default_quantity else row.quantity end;
  select count(*)into current_count from player_shows s where s.discipline_id=row.discipline_id and s.tier_id=row.tier_id and s.status='open'and not s.is_private and s.run_at>now();
  create_count:=case when c.quantity_mode='maintain'then greatest(wanted-current_count,0)else wanted end;combo_count:=combo_count+1;total_current:=total_current+current_count;total_target:=total_target+wanted;total_create:=total_create+create_count;
  items:=items||jsonb_build_array(jsonb_build_object('discipline_id',row.discipline_id,'discipline',row.discipline,'tier_id',row.tier_id,'tier',row.tier,'enabled',row.enabled,'quantity',wanted,'entry_fee',row.entry_fee,'base_purse',row.base_purse,'current',current_count,'would_create',create_count));
 end loop;
 return jsonb_build_object('enabled',c.enabled,'selection_mode',c.selection_mode,'quantity_mode',c.quantity_mode,'daily_enabled',c.daily_enabled,'default_quantity',c.default_quantity,'run_delay_days',c.run_delay_days,'use_show_defaults',c.use_show_defaults,'timezone',c.timezone,'creation_time',c.creation_time,'next_run',auto_host_next_run(),'combination_count',combo_count,'current_qualifying',total_current,'target_total',total_target,'would_create',total_create,'items',items);
end$$;
