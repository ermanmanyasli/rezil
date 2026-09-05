-- Browsing the map is public; authors can always see their own reports.
drop policy if exists "public can read visible reports" on public.reports;
create policy "public can read visible reports"
on public.reports for select
to anon, authenticated
using (
  (visibility = 'public' and moderation_state = 'approved')
  or author_id = auth.uid()
);

drop policy if exists "public can read visible report media" on public.report_media;
create policy "public can read visible report media"
on public.report_media for select
to anon, authenticated
using (
  exists (
    select 1 from public.reports
    where reports.id = report_media.report_id
      and (
        (reports.visibility = 'public' and reports.moderation_state = 'approved')
        or reports.author_id = auth.uid()
      )
  )
);

drop policy if exists "public can read visible report images" on storage.objects;
create policy "public can read visible report images"
on storage.objects for select
to anon, authenticated
using (
  bucket_id = 'report-images'
  and exists (
    select 1 from public.reports
    where reports.id::text = (storage.foldername(name))[1]
      and (
        (reports.visibility = 'public' and reports.moderation_state = 'approved')
        or reports.author_id = auth.uid()
      )
  )
);
