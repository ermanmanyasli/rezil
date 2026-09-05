-- Apply this migration to an existing Supabase project created from 001_initial.sql.

create or replace function public.refresh_comment_counts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    update public.reports
    set comment_count = (
      select count(*)
      from public.comments
      where report_id = old.report_id and deleted_at is null
    ), updated_at = now()
    where id = old.report_id;
  else
    update public.reports
    set comment_count = (
      select count(*)
      from public.comments
      where report_id = new.report_id and deleted_at is null
    ), updated_at = now()
    where id = new.report_id;
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists comments_count on public.comments;
create trigger comments_count
after insert or delete on public.comments
for each row execute procedure public.refresh_comment_counts();

drop policy if exists "users read comments" on public.comments;
create policy "users read comments"
on public.comments for select to authenticated using (true);

drop policy if exists "users add their own comments" on public.comments;
create policy "users add their own comments"
on public.comments for insert to authenticated
with check (author_id = auth.uid());

