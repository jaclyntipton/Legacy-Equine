-- Funding-blocked Auto Host cycles never evaluate or skip individual combinations.
-- Keep that state distinct from Maintain-X combinations that legitimately need no work.
create or replace function public.normalize_auto_host_blocked_run()
returns trigger
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_blocked integer;
begin
  if new.result->>'status'='insufficient_show_fund' then
    v_blocked:=coalesce(
      (new.result->>'blocked_combinations')::integer,
      (new.result->>'skipped')::integer,
      new.shows_skipped,
      0
    );
    new.shows_skipped:=0;
    new.result:=jsonb_set(
      jsonb_set(new.result,'{skipped}','0'::jsonb,true),
      '{blocked_combinations}',to_jsonb(v_blocked),true
    );
  end if;
  return new;
end$$;

revoke all on function public.normalize_auto_host_blocked_run() from public,anon,authenticated;

drop trigger if exists normalize_auto_host_blocked_run on public.show_auto_host_runs;
create trigger normalize_auto_host_blocked_run
before insert or update of result,shows_skipped on public.show_auto_host_runs
for each row execute function public.normalize_auto_host_blocked_run();

update public.show_auto_host_runs
set shows_skipped=0,
    result=jsonb_set(
      jsonb_set(result,'{skipped}','0'::jsonb,true),
      '{blocked_combinations}',to_jsonb(shows_skipped),true
    )
where result->>'status'='insufficient_show_fund'
  and shows_skipped<>0;
