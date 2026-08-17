-- Run once in Supabase SQL Editor before adding light-novel records.
-- It replaces only CHECK constraints that validate the media_type column.

do $$
declare
  target_table text;
  constraint_record record;
begin
  foreach target_table in array array['favorites', 'favorite_categories']
  loop
    for constraint_record in
      select conname
      from pg_constraint
      where conrelid = format('public.%I', target_table)::regclass
        and contype = 'c'
        and pg_get_constraintdef(oid) ilike '%media_type%'
    loop
      execute format('alter table public.%I drop constraint %I', target_table, constraint_record.conname);
    end loop;
    execute format(
      'alter table public.%I add constraint %I check (media_type in (''anime'', ''manga'', ''light_novel''))',
      target_table,
      target_table || '_media_type_check'
    );
  end loop;
end;
$$;
