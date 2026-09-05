-- Apply this migration to an existing Supabase project.
-- Report images use a unique path, so uploads only need INSERT permission.

drop policy if exists "users create their own reports" on public.reports;
create policy "users create their own reports"
on public.reports for insert to authenticated
with check (author_id = auth.uid());

drop policy if exists "users upload media for their reports" on public.report_media;
create policy "users upload media for their reports"
on public.report_media for insert to authenticated
with check (
  uploader_id = auth.uid()
  and exists (
    select 1
    from public.reports
    where reports.id = report_id
      and reports.author_id = auth.uid()
  )
);

drop policy if exists "authenticated users upload report images" on storage.objects;
create policy "authenticated users upload report images"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'report-images'
  and exists (
    select 1
    from public.reports
    where reports.id::text = (storage.foldername(name))[1]
      and reports.author_id = auth.uid()
  )
);

