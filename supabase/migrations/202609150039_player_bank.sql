-- Player-facing Legacy Equine Bank. The accounting ledger remains authoritative.
create or replace function public.bank_category(reason_text text) returns text language sql immutable as $$select case
 when reason_text ilike '%award%' or reason_text ilike '%admin%credit%' then 'Awards'
 when reason_text ilike '%show%' then 'Shows'
 when reason_text ilike '%profession%enrollment%' or reason_text ilike '%certification%exam%' then 'Profession Education'
 when reason_text ilike '%service%' or reason_text ilike '%farrier%' or reason_text ilike '%trainer%' or reason_text ilike '%veterinarian%' or reason_text ilike '%massage%' then 'Professional Services'
 when reason_text ilike '%store%' or reason_text ilike '%foundation horse%' then 'Horses'
 when reason_text ilike '%horse%' or reason_text ilike '%stud%' or reason_text ilike '%marketplace%' then 'Horses'
 when reason_text ilike '%shop%' or reason_text ilike '%tack%' then 'LE Shop'
 when reason_text ilike '%purchase%' then 'Purchases'
 else 'Other' end$$;

create or replace function public.get_bank_activity(before_time timestamptz default null,page_size integer default 25,category_filter text default 'All')
returns table(id uuid,amount bigint,description text,category text,created_at timestamptz,horse_id uuid,resulting_balance bigint)
language sql security definer set search_path=public stable as $$
 with own as(select l.id,l.amount::bigint,l.reason,l.created_at,l.horse_id,bank_category(l.reason) category,
   s.balance::bigint-coalesce(sum(l.amount::bigint) over(order by l.created_at desc,l.id desc rows between unbounded preceding and 1 preceding),0) resulting_balance
  from currency_ledger l cross join lateral(select balance from stables where id=auth.uid())s where l.stable_id=auth.uid())
 select id,amount,reason,category,created_at,horse_id,resulting_balance from own
 where(before_time is null or created_at<before_time) and(category_filter='All' or category=category_filter or(category_filter='Income' and amount>0))
 order by created_at desc,id desc limit least(greatest(page_size,1),100)
$$;
create or replace function public.get_bank_summary() returns jsonb language sql security definer set search_path=public stable as $$select jsonb_build_object('current_balance',s.balance,'earned',coalesce(sum(l.amount) filter(where l.amount>0),0),'spent',abs(coalesce(sum(l.amount) filter(where l.amount<0),0))) from stables s left join currency_ledger l on l.stable_id=s.id where s.id=auth.uid() group by s.balance$$;
revoke all on function public.bank_category(text),public.get_bank_activity(timestamptz,integer,text),public.get_bank_summary() from public;
grant execute on function public.get_bank_activity(timestamptz,integer,text),public.get_bank_summary() to authenticated;
