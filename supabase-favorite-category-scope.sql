-- Run once in Supabase SQL Editor.
-- Allow category names to repeat across media types while keeping each
-- media type free of duplicate category names.

do $$
declare
  constraint_record record;
  index_record record;
begin
  for constraint_record in
    select c.conname
    from pg_constraint c
    join pg_attribute a
      on a.attrelid = c.conrelid
      and a.attnum = c.conkey[1]
    where c.conrelid = 'public.favorite_categories'::regclass
      and c.contype = 'u'
      and array_length(c.conkey, 1) = 1
      and a.attname = 'name'
  loop
    execute format(
      'alter table public.favorite_categories drop constraint %I',
      constraint_record.conname
    );
  end loop;

  for index_record in
    select index_class.relname
    from pg_index i
    join pg_class index_class on index_class.oid = i.indexrelid
    where i.indrelid = 'public.favorite_categories'::regclass
      and i.indisunique
      and i.indnkeyatts = 1
      and i.indkey[0] = (
        select attnum
        from pg_attribute
        where attrelid = 'public.favorite_categories'::regclass
          and attname = 'name'
          and not attisdropped
      )
      and not exists (
        select 1
        from pg_constraint c
        where c.conindid = i.indexrelid
      )
  loop
    execute format('drop index public.%I', index_record.relname);
  end loop;
end;
$$;

create unique index if not exists favorite_categories_media_type_name_key
  on public.favorite_categories (media_type, name);
