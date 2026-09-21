-- Paid Show entries are final. Eligibility is authoritative when the entry is accepted.
alter table public.player_shows add column if not exists completion_reason text;

comment on column public.player_shows.completion_reason is
 'Terminal execution outcome. no_entries means the Show completed normally with zero entrants.';

-- Retain the old signatures so an outdated worker fails closed instead of refunding/deleting entries.
create or replace function public.remove_invalid_show_entry(p_entry uuid,p_reason text)returns boolean
language plpgsql security definer set search_path=public as $$
begin
 raise exception 'Paid Show entries are final; use audited Admin data correction for corrupt records';
end$$;

create or replace function public.revalidate_show_entries(p_show uuid)returns jsonb
language sql stable security definer set search_path=public as $$
 select jsonb_build_object(
  'show_id',p_show,
  'entry_count',(select count(*)from player_show_entries e where e.show_id=p_show),
  'removed',0,
  'refunded',0,
  'eligibility_moment','entry_created',
  'entries_final',true
 )
$$;

-- Scheduled, single Run Now, and Bulk Run all share this processor.
-- Zero-entry Shows complete normally; one or more entries are scored exactly once.
create or replace function public.process_due_player_shows()returns integer
language plpgsql security definer set search_path=public as $$
declare
 sh player_shows;ent record;weights jsonb;purse bigint;rule show_placement_rules;
 rank_no int;processed int:=0;breakdown jsonb;score numeric;base_score numeric;
 inserted uuid;payout bigint;entry_count integer;
begin
 for sh in
  select*from player_shows
  where status in('open','processing')and run_at<=now()
  order by run_at for update skip locked
 loop
  update player_shows set status='processing'where id=sh.id;
  select count(*)into entry_count from player_show_entries where show_id=sh.id;
  if entry_count=0 then
   update player_shows
   set status='complete',processed_at=coalesce(processed_at,now()),completion_reason='no_entries'
   where id=sh.id;
   processed:=processed+1;
   continue;
  end if;

  rank_no:=0;
  purse:=sh.entry_fee_purse+sh.show_fund_allocation+sh.treasury_allocation;
  select stat_weights into weights from show_disciplines where id=sh.discipline_id;
  for ent in
   select e.*,h.stats,h.tack_bonuses from player_show_entries e
   join horses h on h.id=e.horse_id where e.show_id=sh.id order by e.id
  loop
   breakdown:=show_score_breakdown(ent.horse_id,weights,sh.run_at);
   score:=(select sum((breakdown->key->>'effective')::numeric*(value::text)::numeric)/nullif(sum((value::text)::numeric),0)from jsonb_each(weights));
   base_score:=(select sum(((breakdown->key->>'base')::numeric+(breakdown->key->>'training')::numeric)*(value::text)::numeric)/nullif(sum((value::text)::numeric),0)from jsonb_each(weights));
   update player_show_entries set eligibility_snapshot=coalesce(eligibility_snapshot,'{}')||jsonb_build_object(
    'competition_score',score,'base_score',base_score,'score_breakdown',breakdown,
    'permanent_average_at_run',horse_permanent_stat_average(ent.horse_id),
    'show_level_at_run',get_horse_show_level(ent.horse_id),
    'eligibility_locked_at_entry',true
   )where id=ent.id;
  end loop;

  for ent in
   select e.*,(e.eligibility_snapshot->>'competition_score')::numeric score,
    (e.eligibility_snapshot->>'base_score')::numeric base_score,
    e.eligibility_snapshot->'score_breakdown'breakdown
   from player_show_entries e where e.show_id=sh.id
   order by score desc,base_score desc,e.career_points_snapshot desc,e.entered_at,e.horse_id
  loop
   rank_no:=rank_no+1;
   select*into rule from show_placement_rules where placement=rank_no;
   payout:=floor(purse*coalesce(rule.prize_percent,0)/100);
   inserted:=null;
   insert into player_show_results(
    show_id,entry_id,horse_id,owner_id,placement,competition_score,base_contribution,
    tack_contribution,service_contribution,career_points_awarded,led_winnings,
    horse_name_snapshot,owner_name_snapshot,owner_account_snapshot,score_breakdown
   )values(
    sh.id,ent.id,ent.horse_id,ent.owner_id,rank_no,ent.score,ent.base_score,
    coalesce((select avg((value->>'tack')::numeric)from jsonb_each(ent.breakdown)),0),
    coalesce((select avg((value->>'service')::numeric)from jsonb_each(ent.breakdown)),0),
    coalesce(rule.career_points,0),payout,ent.horse_name_snapshot,ent.owner_name_snapshot,
    ent.owner_account_snapshot,ent.breakdown
   )on conflict(entry_id)do nothing returning id into inserted;
   if inserted is not null then
    update horses set career_points=career_points+coalesce(rule.career_points,0)where id=ent.horse_id;
    if payout>0 then
     update stables set balance=balance+payout where id=ent.owner_id;
     insert into currency_ledger(stable_id,amount,reason,horse_id)
     values(ent.owner_id,payout,'Show winnings: '||sh.name,ent.horse_id);
    end if;
   end if;
  end loop;
  update player_shows
  set status='complete',processed_at=coalesce(processed_at,now()),completion_reason='results_recorded'
  where id=sh.id;
  processed:=processed+1;
 end loop;
 return processed;
end$$;

-- Normal Shows cannot be cancelled. Historical cancelled rows remain intact.
create or replace function public.admin_show_action(p_show uuid,p_action text,p_changes jsonb default '{}')returns jsonb
language plpgsql security definer set search_path=public as $$
declare sh player_shows;new_id uuid;result jsonb;
begin
 select*into sh from player_shows where id=p_show for update;if not found then raise exception'Show not found';end if;
 if p_action='cancel'then raise exception'Normal Shows cannot be cancelled; paid entries are final';
 elsif p_action='lock'or p_action='unlock'then
  if not has_show_capability('shows.admin.lock')then raise exception'Show lock permission required';end if;
  if sh.status<>'open'then raise exception'Only open Shows can be locked or unlocked';end if;
  update player_shows set locked_at=case when p_action='lock'then now()else null end,locked_by=case when p_action='lock'then auth.uid()else null end where id=sh.id;
 elsif p_action='edit'then
  if not has_show_capability('shows.admin.edit')then raise exception'Show editing permission required';end if;
  if sh.status<>'open'then raise exception'Only open Shows can be edited';end if;
  update player_shows set name=left(coalesce(nullif(trim(p_changes->>'name'),''),name),80),description=left(coalesce(p_changes->>'description',description),1000),run_at=coalesce((p_changes->>'run_at')::timestamptz,run_at),run_date=coalesce((p_changes->>'run_at')::timestamptz::date,run_date),max_entries=coalesce((p_changes->>'max_entries')::integer,max_entries)where id=sh.id;
 elsif p_action in('duplicate','duplicate_test')then
  if not has_show_capability('shows.admin.duplicate')then raise exception'Show duplication permission required';end if;
  if p_action='duplicate_test'and not has_show_capability('shows.admin.qa')then raise exception'Show QA permission required';end if;
  insert into player_shows(creator_id,name,discipline_id,tier_id,run_date,run_at,entry_fee,max_entries,maximum_per_owner,description,is_private,is_admin_qa,duplicated_from)
  values(auth.uid(),left(sh.name||case when p_action='duplicate_test'then' — QA Test'else' — Copy'end,80),sh.discipline_id,sh.tier_id,greatest(current_date+1,sh.run_date+1),(greatest(current_date+1,sh.run_date+1)::timestamp at time zone'America/New_York'),sh.entry_fee,sh.max_entries,sh.maximum_per_owner,sh.description,case when p_action='duplicate_test'then true else sh.is_private end,case when p_action='duplicate_test'then true else sh.is_admin_qa end,sh.id)returning id into new_id;
 elsif p_action='run_now'then
  if not has_show_capability('shows.admin.run_now')then raise exception'Run Show permission required';end if;
  if sh.status<>'open'then raise exception'Only an open Show can run';end if;
  update player_shows set locked_at=coalesce(locked_at,now()),locked_by=coalesce(locked_by,auth.uid()),run_at=least(run_at,now())where id=sh.id;
  perform process_due_player_shows();
  if not exists(select 1 from player_shows where id=sh.id and status='complete')then raise exception'Show processing did not complete';end if;
 else raise exception'Unknown Show action';end if;
 insert into show_admin_audit(show_id,actor_id,action,details)values(sh.id,auth.uid(),p_action,coalesce(p_changes,'{}'));
 select jsonb_build_object('show_id',sh.id,'action',p_action,'duplicate_id',new_id,'status',(select status from player_shows where id=sh.id),'completion_reason',(select completion_reason from player_shows where id=sh.id))into result;
 return result;
end$$;

revoke all on function public.remove_invalid_show_entry(uuid,text),public.revalidate_show_entries(uuid),public.process_due_player_shows()from public;
grant execute on function public.process_due_player_shows()to service_role;

