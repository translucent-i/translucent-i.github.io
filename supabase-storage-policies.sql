-- Run this only after reviewing and deleting old broad policies on storage.objects.
-- It assumes songs, photos, and wallpapers are the only buckets this site uses.

create policy "site_media_public_read"
on storage.objects for select
using (bucket_id in ('songs', 'photos', 'wallpapers'));

create policy "site_media_owner_insert"
on storage.objects for insert to authenticated
with check (bucket_id in ('songs', 'photos', 'wallpapers') and public.is_site_owner());

create policy "site_media_owner_update"
on storage.objects for update to authenticated
using (bucket_id in ('songs', 'photos', 'wallpapers') and public.is_site_owner())
with check (bucket_id in ('songs', 'photos', 'wallpapers') and public.is_site_owner());

create policy "site_media_owner_delete"
on storage.objects for delete to authenticated
using (bucket_id in ('songs', 'photos', 'wallpapers') and public.is_site_owner());
