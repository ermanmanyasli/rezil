-- Persist comment likes with one row per user/comment pair.
alter table public.comments add column if not exists like_count integer not null default 0;

create table if not exists public.comment_likes (
  comment_id uuid not null references public.comments(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);

create index if not exists comment_likes_user_id_idx on public.comment_likes(user_id);

alter table public.comment_likes enable row level security;

drop policy if exists "users read comment likes" on public.comment_likes;
create policy "users read comment likes"
on public.comment_likes for select to authenticated using (true);

drop policy if exists "users like comments" on public.comment_likes;
create policy "users like comments"
on public.comment_likes for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists "users unlike comments" on public.comment_likes;
create policy "users unlike comments"
on public.comment_likes for delete to authenticated
using (user_id = auth.uid());

create or replace function public.refresh_comment_like_counts() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    update public.comments set like_count = (select count(*) from public.comment_likes where comment_id = old.comment_id) where id = old.comment_id;
  else
    update public.comments set like_count = (select count(*) from public.comment_likes where comment_id = new.comment_id) where id = new.comment_id;
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists comment_like_counts on public.comment_likes;
create trigger comment_like_counts
after insert or delete on public.comment_likes
for each row execute procedure public.refresh_comment_like_counts();
