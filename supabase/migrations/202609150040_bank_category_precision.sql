-- Avoid treating words such as "restored" as LE Store transactions.
create or replace function public.bank_category(reason_text text) returns text language sql immutable as $$select case
 when reason_text ilike '%award%' or reason_text ilike '%admin%credit%' then 'Awards'
 when reason_text ilike '%show%' then 'Shows'
 when reason_text ilike '%profession%enrollment%' or reason_text ilike '%certification%exam%' then 'Profession Education'
 when reason_text ilike '%service%' or reason_text ilike '%farrier%' or reason_text ilike '%trainer%' or reason_text ilike '%veterinarian%' or reason_text ilike '%massage%' then 'Professional Services'
 when reason_text ilike '%LE Store%' or reason_text ilike '%foundation horse%' then 'Horses'
 when reason_text ilike '%horse%' or reason_text ilike '%stud%' or reason_text ilike '%marketplace%' then 'Horses'
 when reason_text ilike '%shop%' or reason_text ilike '%tack%' then 'LE Shop'
 when reason_text ilike '%purchase%' then 'Purchases'
 else 'Other' end$$;
