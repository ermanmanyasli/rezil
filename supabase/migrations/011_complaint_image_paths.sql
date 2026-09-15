-- Optimized photo pipeline: uploads move to immutable paths
--   complaints/{complaintUUID}/{photoUUID}.jpg
--   complaints/{complaintUUID}/{photoUUID}_thumb.jpg
-- so the report UUID is now the SECOND path segment. Update the
-- report-image storage policies accordingly (lower() tolerates UUID case).

drop policy if exists "authenticated users upload report images" on storage.objects;
create policy "authenticated users upload report images"
on storage.objects for insert to authenticated with check (
  bucket_id = 'report-images'
  and (storage.foldername(name))[1] = 'complaints'
  and public.user_owns_report(((storage.foldername(name))[2])::uuid)
);

drop policy if exists "public can read visible report images" on storage.objects;
create policy "public can read visible report images"
on storage.objects for select to anon, authenticated using (
  bucket_id = 'report-images'
  and exists (
    select 1 from public.reports
    where (
        -- New layout: complaints/{reportUUID}/{photo}.jpg
        ((storage.foldername(name))[1] = 'complaints'
          and reports.id::text = lower((storage.foldername(name))[2]))
        -- Legacy layout: {reportUUID}/{photo}.jpg (read-only compat)
        or reports.id::text = lower((storage.foldername(name))[1])
      )
      and (
        (reports.visibility = 'public' and reports.moderation_state = 'approved')
        or reports.author_id = auth.uid()
      )
  )
);
