-- Run this in Supabase SQL Editor after confirming the project owner email.
-- This script makes site content public-read and owner-write.

create or replace function public.is_site_owner()
returns boolean
language sql
stable
as $$
  select coalesce(auth.jwt() ->> 'email', '') = '2067229357@qq.com';
$$;

-- Remove legacy policies on the tables owned by this site, then recreate a
-- predictable policy set. This does not touch unrelated public tables.
do $$
declare
  target_table text;
  policy_record record;
begin
  foreach target_table in array array[
    'projects', 'playlists', 'songs', 'notes', 'comments', 'likes',
    'profiles', 'favorites', 'favorite_categories'
  ]
  loop
    for policy_record in
      select policyname
      from pg_policies
      where schemaname = 'public' and tablename = target_table
    loop
      execute format('drop policy if exists %I on public.%I', policy_record.policyname, target_table);
    end loop;
  end loop;
end;
$$;

alter table public.projects enable row level security;
alter table public.playlists enable row level security;
alter table public.songs enable row level security;
alter table public.notes enable row level security;
alter table public.comments enable row level security;
alter table public.likes enable row level security;
alter table public.profiles enable row level security;
alter table public.favorites enable row level security;
alter table public.favorite_categories enable row level security;

create policy "site_public_read_projects" on public.projects for select using (true);
create policy "site_owner_write_projects" on public.projects for all to authenticated using (public.is_site_owner()) with check (public.is_site_owner());
create policy "site_public_read_playlists" on public.playlists for select using (true);
create policy "site_owner_write_playlists" on public.playlists for all to authenticated using (public.is_site_owner()) with check (public.is_site_owner());
create policy "site_public_read_songs" on public.songs for select using (true);
create policy "site_owner_write_songs" on public.songs for all to authenticated using (public.is_site_owner()) with check (public.is_site_owner());
create policy "site_public_read_notes" on public.notes for select using (true);
create policy "site_owner_write_notes" on public.notes for all to authenticated using (public.is_site_owner()) with check (public.is_site_owner());
create policy "site_public_read_comments" on public.comments for select using (true);
create policy "site_owner_write_comments" on public.comments for all to authenticated using (public.is_site_owner()) with check (public.is_site_owner());
create policy "site_public_read_likes" on public.likes for select using (true);
create policy "site_owner_write_likes" on public.likes for all to authenticated using (public.is_site_owner()) with check (public.is_site_owner());
create policy "site_public_read_favorites" on public.favorites for select using (true);
create policy "site_owner_write_favorites" on public.favorites for all to authenticated using (public.is_site_owner()) with check (public.is_site_owner());
create policy "site_public_read_favorite_categories" on public.favorite_categories for select using (true);
create policy "site_owner_write_favorite_categories" on public.favorite_categories for all to authenticated using (public.is_site_owner()) with check (public.is_site_owner());

create policy "site_self_read_profile" on public.profiles for select to authenticated using (auth.uid() = id);
create policy "site_self_insert_profile" on public.profiles for insert to authenticated with check (auth.uid() = id);
create policy "site_self_update_profile" on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);
create policy "site_owner_read_profiles" on public.profiles for select to authenticated using (public.is_site_owner());

grant usage on schema public to anon, authenticated;
grant select on public.projects, public.playlists, public.songs, public.notes,
  public.comments, public.likes, public.favorites, public.favorite_categories to anon, authenticated;
grant select, insert, update on public.profiles to authenticated;
grant insert, update, delete on public.projects, public.playlists, public.songs,
  public.notes, public.comments, public.likes, public.favorites,
  public.favorite_categories to authenticated;

-- Keep the public, bounded list queries fast as content grows.
create index if not exists site_projects_created_at_idx on public.projects (created_at desc);
create index if not exists site_playlists_created_at_idx on public.playlists (created_at asc);
create index if not exists site_songs_playlist_created_at_idx on public.songs (playlist_id, created_at asc);
create index if not exists site_notes_created_at_idx on public.notes (created_at desc);
create index if not exists site_comments_note_created_at_idx on public.comments (note_id, created_at asc);
create index if not exists site_favorites_created_at_idx on public.favorites (created_at desc);
create index if not exists site_favorite_categories_sort_idx on public.favorite_categories (media_type, sort_order asc, name asc);

-- Storage policy audit. Review the output in the SQL Editor before replacing
-- existing storage policies, especially if this project has buckets other than
-- songs, photos, and wallpapers.
select policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'storage' and tablename = 'objects';

-- Next: delete old broad Storage policies in Dashboard > Storage > Policies,
-- then run supabase-storage-policies.sql.
