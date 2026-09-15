-- Preserve historical references while removing the superseded placeholder
-- from all new-show selectors.
update public.show_disciplines set active=false where id='jumping';
