-- School homepage field; existing table policies and grants are preserved.
alter table public.map_places add column if not exists school_website text;
alter table public.map_places drop constraint if exists map_places_school_website_check;
alter table public.map_places add constraint map_places_school_website_check
  check (school_website is null or (char_length(school_website)<=2048 and school_website ~ '^https?://[^[:space:]]+$'));
