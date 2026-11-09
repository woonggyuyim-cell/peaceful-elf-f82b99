create table public.map_regions (
  name text primary key check (name = btrim(name) and char_length(name) between 2 and 40),
  created_at timestamptz not null default now()
);
create unique index map_regions_name_casefold on public.map_regions(lower(name));
alter table public.map_regions enable row level security;
revoke all on public.map_regions from public,anon,authenticated;
grant select(name),insert(name) on public.map_regions to anon,authenticated;
create policy map_regions_read on public.map_regions for select to anon,authenticated using (true);
create policy map_regions_add on public.map_regions for insert to anon,authenticated with check (true);
insert into public.map_regions(name) values ('Pesqueria');