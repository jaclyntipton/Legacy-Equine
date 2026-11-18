alter table public.news_email_preferences add column if not exists prompted_at timestamptz;
update public.news_email_preferences set prompted_at=coalesce(prompted_at,updated_at) where prompted_at is null;

create or replace function public.get_news_email_preference() returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare pref news_email_preferences;
begin
 if auth.uid() is null then raise exception 'Authentication required';end if;
 select * into pref from news_email_preferences where stable_id=auth.uid();
 return jsonb_build_object(
  'subscribed',coalesce(pref.subscribed,false),
  'consented_at',pref.consented_at,
  'unsubscribed_at',pref.unsubscribed_at,
  'prompted_at',pref.prompted_at,
  'frequency','weekly'
 );
end$$;

create or replace function public.save_news_email_preference(p_subscribed boolean) returns jsonb
language plpgsql security definer set search_path=public as $$
declare pref news_email_preferences;
begin
 if auth.uid() is null or not exists(select 1 from stables where id=auth.uid())then raise exception 'Authentication required';end if;
 insert into news_email_preferences(stable_id,subscribed,consented_at,unsubscribed_at,prompted_at,updated_at)
 values(auth.uid(),p_subscribed,case when p_subscribed then now()end,case when not p_subscribed then now()end,now(),now())
 on conflict(stable_id)do update set
  subscribed=excluded.subscribed,
  consented_at=case when excluded.subscribed then coalesce(news_email_preferences.consented_at,now())else news_email_preferences.consented_at end,
  unsubscribed_at=case when excluded.subscribed then null else now()end,
  prompted_at=coalesce(news_email_preferences.prompted_at,now()),
  updated_at=now()
 returning * into pref;
 return jsonb_build_object('subscribed',pref.subscribed,'consented_at',pref.consented_at,'unsubscribed_at',pref.unsubscribed_at,'prompted_at',pref.prompted_at,'frequency','weekly');
end$$;

revoke all on function public.get_news_email_preference(),public.save_news_email_preference(boolean) from public,anon;
grant execute on function public.get_news_email_preference(),public.save_news_email_preference(boolean) to authenticated;
