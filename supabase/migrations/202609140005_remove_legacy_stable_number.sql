-- Remove the prototype identity column so account_number is the sole public
-- historical numbering system and the old QA-consumed value cannot resurface.
alter table public.stables drop constraint if exists stables_stable_number_key;
alter table public.stables drop column if exists stable_number;
