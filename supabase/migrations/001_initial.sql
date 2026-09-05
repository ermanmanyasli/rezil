create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'REZİL kullanıcısı',
  avatar_path text,
  home_city text,
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
  moderation_state public.moderation_state not null default 'pending'
);

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', 'REZİL kullanıcısı'))
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.refresh_report_counts() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    update public.reports set support_count = (select count(*) from public.report_support where report_id = old.report_id and support_type = 'seen'), updated_at = now() where id = old.report_id;
  else
    update public.reports set support_count = (select count(*) from public.report_support where report_id = new.report_id and support_type = 'seen'), updated_at = now() where id = new.report_id;
  end if;
  return coalesce(new, old);
end;
$$;

create trigger report_support_counts after insert or delete on public.report_support for each row execute procedure public.refresh_report_counts();

create or replace function public.refresh_comment_counts() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    update public.reports set comment_count = (select count(*) from public.comments where report_id = old.report_id and deleted_at is null), updated_at = now() where id = old.report_id;
  else
    update public.reports set comment_count = (select count(*) from public.comments where report_id = new.report_id and deleted_at is null), updated_at = now() where id = new.report_id;
  end if;
  return coalesce(new, old);
end;
$$;

create trigger comments_count after insert or delete on public.comments for each row execute procedure public.refresh_comment_counts();

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.reports enable row level security;
alter table public.report_media enable row level security;
alter table public.report_support enable row level security;
alter table public.comments enable row level security;

create policy "public can read active categories" on public.categories for select using (active = true);
create policy "authenticated users read visible reports" on public.reports for select to authenticated using (visibility = 'public' and moderation_state = 'approved' or author_id = auth.uid());
create policy "users create their own reports" on public.reports for insert to authenticated with check (author_id = auth.uid());
create policy "users read profiles" on public.profiles for select to authenticated using (true);
create policy "users update their profile" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy "users read visible media" on public.report_media for select to authenticated using (exists (select 1 from public.reports where id = report_id and visibility = 'public' and moderation_state = 'approved'));
create policy "users upload media for their reports" on public.report_media for insert to authenticated with check (uploader_id = auth.uid() and exists (select 1 from public.reports where id = report_id and author_id = auth.uid()));
create policy "users read supports" on public.report_support for select to authenticated using (true);
create policy "users add their own support" on public.report_support for insert to authenticated with check (user_id = auth.uid());
create policy "users remove their own support" on public.report_support for delete to authenticated using (user_id = auth.uid());
create policy "users read comments" on public.comments for select to authenticated using (true);
create policy "users add their own comments" on public.comments for insert to authenticated with check (author_id = auth.uid());

insert into storage.buckets (id, name, public) values ('report-images', 'report-images', false) on conflict (id) do nothing;
create policy "authenticated users upload report images" on storage.objects for insert to authenticated with check (bucket_id = 'report-images' and (storage.foldername(name))[1] in (select id::text from public.reports where author_id = auth.uid()));
create policy "authenticated users read report images" on storage.objects for select to authenticated using (bucket_id = 'report-images');
