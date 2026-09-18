-- Safety pause for the production `result` ambiguity repair. Preserve the exact
-- prior schedule state so the verified follow-up migration can restore it.
create table if not exists public.show_auto_host_repair_state(
 id boolean primary key default true check(id),
 was_enabled boolean not null,
 was_daily_enabled boolean not null,
 paused_at timestamptz not null default now(),
 restored_at timestamptz
);
insert into public.show_auto_host_repair_state(id,was_enabled,was_daily_enabled,paused_at,restored_at)
select true,c.enabled,c.daily_enabled,now(),null from public.show_auto_host_config c where c.id=true
on conflict(id)do update set was_enabled=excluded.was_enabled,was_daily_enabled=excluded.was_daily_enabled,paused_at=excluded.paused_at,restored_at=null;
update public.show_auto_host_config set enabled=false where id=true;
