-- Automated/isolated QA identities intentionally have no public LE account
-- number. Preserve every other maker snapshot while allowing that one field to
-- remain null for those nonpublic identities.
alter table public.leatherwork_commissions
  alter column maker_account_number drop not null;
