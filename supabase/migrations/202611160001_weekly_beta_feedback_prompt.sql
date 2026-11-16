create table if not exists public.player_feedback_prompt_state(
 stable_id uuid primary key references public.stables(id)on delete cascade,
 last_prompted_at timestamptz,
 snoozed_until timestamptz,
 opted_out boolean not null default false,
 prompt_count integer not null default 0 check(prompt_count>=0),
 shared_count integer not null default 0 check(shared_count>=0),
 updated_at timestamptz not null default now()
);

alter table public.player_feedback_prompt_state enable row level security;
drop policy if exists "players read own feedback prompt state" on public.player_feedback_prompt_state;
create policy "players read own feedback prompt state" on public.player_feedback_prompt_state
 for select using(stable_id=auth.uid());

create or replace function public.weekly_feedback_prompt_status()returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare s player_feedback_prompt_state;due boolean;
begin
 if auth.uid()is null then raise exception'Authentication required';end if;
 select*into s from player_feedback_prompt_state where stable_id=auth.uid();
 due:=coalesce(not s.opted_out and coalesce(s.snoozed_until,'epoch'::timestamptz)<=now()and coalesce(s.last_prompted_at,'epoch'::timestamptz)<=now()-interval'7 days',true);
 return jsonb_build_object('should_show',due,'opted_out',coalesce(s.opted_out,false),'last_prompted_at',s.last_prompted_at);
end$$;

create or replace function public.record_weekly_feedback_prompt(p_action text)returns boolean
language plpgsql security definer set search_path=public as $$
declare current_state player_feedback_prompt_state;due boolean;
begin
 if auth.uid()is null then raise exception'Authentication required';end if;
 if p_action not in('shown','later','never','share')then raise exception'Invalid feedback prompt action';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,31));
 select*into current_state from player_feedback_prompt_state where stable_id=auth.uid()for update;
 due:=coalesce(not current_state.opted_out and coalesce(current_state.snoozed_until,'epoch'::timestamptz)<=now()and coalesce(current_state.last_prompted_at,'epoch'::timestamptz)<=now()-interval'7 days',true);
 if p_action='shown'and not due then return false;end if;
 insert into player_feedback_prompt_state(stable_id,last_prompted_at,snoozed_until,opted_out,prompt_count,shared_count,updated_at)
 values(auth.uid(),case when p_action='shown'then now()else null end,case when p_action in('shown','later','share')then now()+interval'7 days'else null end,p_action='never',case when p_action='shown'then 1 else 0 end,case when p_action='share'then 1 else 0 end,now())
 on conflict(stable_id)do update set
  last_prompted_at=case when p_action='shown'then now()else player_feedback_prompt_state.last_prompted_at end,
  snoozed_until=case when p_action in('shown','later','share')then now()+interval'7 days'else player_feedback_prompt_state.snoozed_until end,
  opted_out=case when p_action='never'then true else player_feedback_prompt_state.opted_out end,
  prompt_count=player_feedback_prompt_state.prompt_count+case when p_action='shown'then 1 else 0 end,
  shared_count=player_feedback_prompt_state.shared_count+case when p_action='share'then 1 else 0 end,
  updated_at=now();
 return true;
end$$;

revoke all on table public.player_feedback_prompt_state from public,anon,authenticated;
grant select on table public.player_feedback_prompt_state to authenticated;
revoke all on function public.weekly_feedback_prompt_status(),public.record_weekly_feedback_prompt(text)from public,anon;
grant execute on function public.weekly_feedback_prompt_status(),public.record_weekly_feedback_prompt(text)to authenticated;

comment on function public.record_weekly_feedback_prompt(text)is'Server-persisted weekly beta feedback cadence and permanent opt-out.';
