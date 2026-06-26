-- Phase 20.5 (QA 2c) increment 2: public `backgrounds` storage bucket that
-- hosts the card-background catalog — `colors.json` (solid color board) and
-- `stock/*` images (calm/zen/peaceful/forest). Public read; writes via the
-- service role only (asset uploads run through `make backgrounds-upload`).

insert into storage.buckets (id, name, public)
values ('backgrounds', 'backgrounds', true)
on conflict (id) do update set public = true;

-- Anyone (anon + authenticated) may read/list objects in this bucket.
drop policy if exists "backgrounds public read" on storage.objects;
create policy "backgrounds public read"
    on storage.objects for select
    using (bucket_id = 'backgrounds');
