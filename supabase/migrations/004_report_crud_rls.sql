-- Apply this migration to an existing Supabase project.
-- Keeps ownership checks reliable when RLS evaluates nested report queries.

create or replace function public.user_owns_report(report_uuid uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.reports
    where id = report_uuid
      and author_id = auth.uid()
  );
$$;

revoke all on function public.user_owns_report(uuid) from public;
grant execute on function public.user_owns_report(uuid) to authenticated;

drop policy if exists "users create their own reports" on public.reports;
drop policy if exists "users add their own support" on public.report_support;
drop policy if exists "users upload media for their reports" on public.report_media;
drop policy if exists "authenticated users upload report images" on storage.objects;

create policy "users create their own reports"
on public.reports for insert to authenticated
with check (auth.uid() is not null and author_id = auth.uid());

create policy "users add their own support"
on public.report_support for insert to authenticated
with check (auth.uid() is not null and user_id = auth.uid());

create policy "users upload media for their reports"
on public.report_media for insert to authenticated
with check (
  auth.uid() is not null
  and uploader_id = auth.uid()
  and public.user_owns_report(report_id)
);

create policy "authenticated users upload report images"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'report-images'
  and public.user_owns_report(((storage.foldername(name))[1])::uuid)
);

