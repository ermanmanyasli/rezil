-- ============================================================================
-- REZIL — full reset and rebuild.
-- Drops every app table/type/function/trigger/policy/bucket and recreates
-- the final schema consolidated from migrations 001–009.
--
--   * profiles has NO home_city / home_country (per 009)
--   * comments has like_count, comment_likes table exists (per 008)
--   * public map/media read access (per 007), avatar lower() fix (per 006)
--
-- Run once in Supabase Dashboard → SQL Editor.
-- WARNING: destroys all data in these tables and both storage buckets.
-- ============================================================================

-- --------------------------------------------------------------------------
-- 0. TEARDOWN
-- --------------------------------------------------------------------------

-- App triggers / functions
drop trigger if exists on_auth_user_created on auth.users;
drop trigger if exists report_support_counts on public.report_support;
drop trigger if exists comments_count on public.comments;
drop trigger if exists comment_like_counts on public.comment_likes;
drop function if exists public.handle_new_user() cascade;
drop function if exists public.refresh_report_counts() cascade;
drop function if exists public.refresh_comment_counts() cascade;
drop function if exists public.refresh_comment_like_counts() cascade;
drop function if exists public.user_owns_report(uuid) cascade;

-- Storage policies (all known names, old and new)
drop policy if exists "authenticated users upload report images" on storage.objects;
drop policy if exists "authenticated users read report images" on storage.objects;
drop policy if exists "public can read visible report images" on storage.objects;
drop policy if exists "users upload their own avatar" on storage.objects;
drop policy if exists "users update their own avatar" on storage.objects;
drop policy if exists "users read their own avatar objects" on storage.objects;

-- NOTE: Supabase blocks direct DELETEs on storage.objects (protect_delete trigger).
-- To empty the buckets, use Dashboard → Storage → open each bucket → select all → Delete.
-- Or leave old files in place: they become harmless orphans (new uploads use new UUID
-- paths) and section 4 below recreates the buckets/policies idempotently.

-- App tables (CASCADE clears FK dependencies in any order)
drop table if exists public.comment_likes cascade;
drop table if exists public.comments cascade;
drop table if exists public.report_support cascade;
drop table if exists public.report_media cascade;
drop table if exists public.reports cascade;
drop table if exists public.profiles cascade;
drop table if exists public.categories cascade;

-- App enums
drop type if exists public.report_status cascade;
drop type if exists public.visibility_level cascade;
drop type if exists public.moderation_state cascade;

-- --------------------------------------------------------------------------
-- 1. SCHEMA
-- --------------------------------------------------------------------------

create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'REZİL kullanıcısı',
  avatar_path text,
  reputation_score integer not null default 0,
  created_at timestamptz not null default now(),
  suspended_at timestamptz
);

create table public.categories (
  slug text primary key,
  display_name_tr text not null,
  icon text not null,
  active boolean not null default true
);

insert into public.categories (slug, display_name_tr, icon) values
  ('Yol', 'Yol', 'car.fill'),
  ('Kaldırım', 'Kaldırım', 'figure.walk'),
  ('Çöp', 'Çöp', 'trash.fill'),
  ('Aydınlatma', 'Aydınlatma', 'lightbulb.fill'),
  ('Erişilebilirlik', 'Erişilebilirlik', 'figure.roll'),
  ('Diğer', 'Diğer', 'exclamationmark.bubble.fill')
on conflict (slug) do nothing;

create type public.report_status as enum ('open', 'acknowledged', 'in_progress', 'resolved', 'rejected', 'archived');
create type public.visibility_level as enum ('public', 'limited', 'hidden');
create type public.moderation_state as enum ('pending', 'approved', 'flagged', 'removed');

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  description text not null check (char_length(description) between 1 and 240),
  category_id text not null references public.categories(slug),
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  public_location_label text not null default '',
  status public.report_status not null default 'open',
  visibility public.visibility_level not null default 'public',
  support_count integer not null default 0,
  comment_count integer not null default 0,
  evidence_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz,
  moderation_state public.moderation_state not null default 'approved'
);

create table public.report_media (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete cascade,
  uploader_id uuid not null references public.profiles(id) on delete cascade,
  storage_path text not null,
  media_type text not null default 'image/jpeg',
  captured_at timestamptz,
  created_at timestamptz not null default now(),
  moderation_state public.moderation_state not null default 'pending'
);

create table public.report_support (
  report_id uuid not null references public.reports(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  support_type text not null default 'seen',
  created_at timestamptz not null default now(),
  primary key (report_id, user_id, support_type)
);

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz,
  moderation_state public.moderation_state not null default 'pending',
  like_count integer not null default 0
);

create table public.comment_likes (
  comment_id uuid not null references public.comments(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);
create index if not exists comment_likes_user_id_idx on public.comment_likes(user_id);

-- Backfill profile rows for auth users that already exist
-- (the signup trigger below only fires for NEW users).
insert into public.profiles (id)
select id from auth.users
on conflict (id) do nothing;

-- --------------------------------------------------------------------------
-- 2. FUNCTIONS + TRIGGERS
-- --------------------------------------------------------------------------

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', 'REZİL kullanıcısı'))
  on conflict (id) do nothing;
  return new;
end;
$$;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.refresh_report_counts() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    update public.reports set support_count = (select count(*) from public.report_support where report_id = old.report_id and support_type = 'seen'), updated_at = now() where id = old.report_id;
  else
    update public.reports set support_count = (select count(*) from public.report_support where report_id = new.report_id and support_type = 'seen'), updated_at = now() where id = new.report_id;
  end if;
  return coalesce(new, old);
end;
$$;
create trigger report_support_counts after insert or delete on public.report_support
for each row execute procedure public.refresh_report_counts();

create or replace function public.refresh_comment_counts() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    update public.reports set comment_count = (select count(*) from public.comments where report_id = old.report_id and deleted_at is null), updated_at = now() where id = old.report_id;
  else
    update public.reports set comment_count = (select count(*) from public.comments where report_id = new.report_id and deleted_at is null), updated_at = now() where id = new.report_id;
  end if;
  return coalesce(new, old);
end;
$$;
create trigger comments_count after insert or update of deleted_at or delete on public.comments
for each row execute procedure public.refresh_comment_counts();

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
create trigger comment_like_counts after insert or delete on public.comment_likes
for each row execute procedure public.refresh_comment_like_counts();

create or replace function public.user_owns_report(report_uuid uuid)
returns boolean language sql security definer set search_path = public as $$
  select exists (select 1 from public.reports where id = report_uuid and author_id = auth.uid());
$$;
revoke all on function public.user_owns_report(uuid) from public;
grant execute on function public.user_owns_report(uuid) to authenticated;

-- --------------------------------------------------------------------------
-- 3. ROW LEVEL SECURITY
-- --------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.reports enable row level security;
alter table public.report_media enable row level security;
alter table public.report_support enable row level security;
alter table public.comments enable row level security;
alter table public.comment_likes enable row level security;

-- categories
create policy "public can read active categories"
on public.categories for select using (active = true);

-- profiles
create policy "users read profiles"
on public.profiles for select to authenticated using (true);
create policy "users update their profile"
on public.profiles for update to authenticated
using (id = auth.uid()) with check (id = auth.uid());

-- reports
create policy "public can read visible reports"
on public.reports for select to anon, authenticated using (
  (visibility = 'public' and moderation_state = 'approved') or author_id = auth.uid());
create policy "users create their own reports"
on public.reports for insert to authenticated
with check (auth.uid() is not null and author_id = auth.uid());
create policy "users update their own reports"
on public.reports for update to authenticated
using (author_id = auth.uid()) with check (author_id = auth.uid());
create policy "users delete their own reports"
on public.reports for delete to authenticated using (author_id = auth.uid());

-- report_media
create policy "public can read visible report media"
on public.report_media for select to anon, authenticated using (
  exists (select 1 from public.reports where reports.id = report_media.report_id
    and ((reports.visibility = 'public' and reports.moderation_state = 'approved')
      or reports.author_id = auth.uid())));
create policy "users upload media for their reports"
on public.report_media for insert to authenticated with check (
  auth.uid() is not null and uploader_id = auth.uid()
  and public.user_owns_report(report_id));

-- report_support
create policy "users read supports"
on public.report_support for select to authenticated using (true);
create policy "users add their own support"
on public.report_support for insert to authenticated
with check (auth.uid() is not null and user_id = auth.uid());
create policy "users remove their own support"
on public.report_support for delete to authenticated using (user_id = auth.uid());

-- comments
create policy "users read comments"
on public.comments for select to authenticated using (true);
create policy "users add their own comments"
on public.comments for insert to authenticated with check (author_id = auth.uid());
create policy "users update their own comments"
on public.comments for update to authenticated
using (author_id = auth.uid()) with check (author_id = auth.uid());
create policy "users delete their own comments"
on public.comments for delete to authenticated using (author_id = auth.uid());

-- comment_likes
create policy "users read comment likes"
on public.comment_likes for select to authenticated using (true);
create policy "users like comments"
on public.comment_likes for insert to authenticated with check (user_id = auth.uid());
create policy "users unlike comments"
on public.comment_likes for delete to authenticated using (user_id = auth.uid());

-- --------------------------------------------------------------------------
-- 4. STORAGE
-- --------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('report-images', 'report-images', true), ('avatars', 'avatars', true)
on conflict (id) do nothing;
update storage.buckets set public = true where id in ('avatars', 'report-images');

create policy "authenticated users upload report images"
on storage.objects for insert to authenticated with check (
  bucket_id = 'report-images'
  and public.user_owns_report(((storage.foldername(name))[1])::uuid));

create policy "public can read visible report images"
on storage.objects for select to anon, authenticated using (
  bucket_id = 'report-images'
  and exists (select 1 from public.reports
    where reports.id::text = (storage.foldername(name))[1]
    and ((reports.visibility = 'public' and reports.moderation_state = 'approved')
      or reports.author_id = auth.uid())));

create policy "users read their own avatar objects"
on storage.objects for select to authenticated using (
  bucket_id = 'avatars'
  and lower((storage.foldername(name))[1]) = lower(auth.uid()::text));

create policy "users upload their own avatar"
on storage.objects for insert to authenticated with check (
  bucket_id = 'avatars'
  and lower((storage.foldername(name))[1]) = lower(auth.uid()::text));

create policy "users update their own avatar"
on storage.objects for update to authenticated
using (bucket_id = 'avatars' and lower((storage.foldername(name))[1]) = lower(auth.uid()::text))
with check (bucket_id = 'avatars' and lower((storage.foldername(name))[1]) = lower(auth.uid()::text));
