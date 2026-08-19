-- Storage buckets for Innself.
-- Run after 001_schema.sql.
-- Convention: objects are stored under a path starting with the owning
-- user's uid, e.g. job-photos/{auth.uid()}/{filename}.

insert into storage.buckets (id, name, public)
values
  ('job-photos', 'job-photos', true),
  ('technician-kyc', 'technician-kyc', false)
on conflict (id) do nothing;

-- job-photos: public read (bucket is public), write restricted to the
-- authenticated user uploading into their own folder.
create policy "job_photos_insert_own_folder" on storage.objects
  for insert with check (
    bucket_id = 'job-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "job_photos_update_own_folder" on storage.objects
  for update using (
    bucket_id = 'job-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- technician-kyc: private, owner-only read/write.
create policy "technician_kyc_select_own_folder" on storage.objects
  for select using (
    bucket_id = 'technician-kyc'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "technician_kyc_insert_own_folder" on storage.objects
  for insert with check (
    bucket_id = 'technician-kyc'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "technician_kyc_update_own_folder" on storage.objects
  for update using (
    bucket_id = 'technician-kyc'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
