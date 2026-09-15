-- Human-approved Quarter Horse conformation masters. These originals are
-- immutable source assets; all derived masks/composites use separate files.
alter table public.horse_visual_assets add column if not exists immutable_source boolean not null default false;
alter table public.horse_visual_assets add column if not exists source_sha256 text;

insert into public.horse_visual_assets(asset_key,asset_type,breed,sex,image_url,z_index,status,active,review_notes,created_by,approved_by,approved_at,immutable_source,source_sha256)
select 'qh_mare_master_01','body_template','Quarter Horse','Mare','/horse-visuals/masters/qh_mare_master_01.png',0,'approved',true,'Official Legacy Equine Quarter Horse Mare Master 01 — conformation locked',s.id,s.id,now(),true,'23e79c1f3e61fd974feff11f51d78a407a4e6dc9f7ada5b47f49145f0a2bc72a'
from public.stables s where s.account_number=1
on conflict(asset_key) do nothing;

insert into public.horse_visual_assets(asset_key,asset_type,breed,sex,image_url,z_index,status,active,review_notes,created_by,approved_by,approved_at,immutable_source,source_sha256)
select 'qh_stallion_master_01','body_template','Quarter Horse','Stallion','/horse-visuals/masters/qh_stallion_master_01.png',0,'approved',true,'Official Legacy Equine Quarter Horse Stallion Master 01 — conformation locked',s.id,s.id,now(),true,'d8c6c21ce376f004daae79ec6c1ddb714880b2db7fba62db6a98ec2529168486'
from public.stables s where s.account_number=1
on conflict(asset_key) do nothing;

create or replace function public.protect_immutable_horse_visual_source() returns trigger language plpgsql set search_path=public as $$
begin
 if old.immutable_source then raise exception 'Approved master source assets are immutable';end if;
 if tg_op='DELETE' then return old;end if;
 return new;
end$$;
drop trigger if exists protect_immutable_horse_visual_source on public.horse_visual_assets;
create trigger protect_immutable_horse_visual_source before update or delete on public.horse_visual_assets for each row execute function public.protect_immutable_horse_visual_source();

comment on column public.horse_visual_assets.immutable_source is 'True for human-approved, pixel-locked source masters that cannot be changed or deleted.';
comment on column public.horse_visual_assets.source_sha256 is 'SHA-256 checksum of the immutable original upload.';
