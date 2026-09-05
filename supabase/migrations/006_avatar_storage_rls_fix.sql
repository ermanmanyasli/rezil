-- Supabase Storage upsert checks the existing object before replacing it.
-- Compare UUID folder names case-insensitively because UUID.uuidString on iOS
-- can contain uppercase hexadecimal characters.
update storage.buckets set public = true where id = 'avatars';

drop policy if exists "users read their own avatar objects" on storage.objects;
drop policy if exists "users upload their own avatar" on storage.objects;
drop policy if exists "users update their own avatar" on storage.objects;

create policy "users read their own avatar objects"
on storage.objects for select to authenticated
using (
  bucket_id = 'avatars'
  and lower((storage.foldername(name))[1]) = lower(auth.uid()::text)
);

create policy "users upload their own avatar"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'avatars'
  and lower((storage.foldername(name))[1]) = lower(auth.uid()::text)
);

create policy "users update their own avatar"
on storage.objects for update to authenticated
using (
  bucket_id = 'avatars'
  and lower((storage.foldername(name))[1]) = lower(auth.uid()::text)
)
with check (
  bucket_id = 'avatars'
  and lower((storage.foldername(name))[1]) = lower(auth.uid()::text)
);
