create table public.map_comment_likes (
  comment_id uuid not null references public.map_place_comments(id) on delete cascade,
  visitor_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (comment_id,visitor_id)
);
alter table public.map_comment_likes enable row level security;
create policy "Read likes for visible comments" on public.map_comment_likes for select to anon,authenticated
using (exists(select 1 from public.map_place_comments c where c.id=comment_id and c.is_visible));
create policy "Like visible comments" on public.map_comment_likes for insert to anon,authenticated
with check (exists(select 1 from public.map_place_comments c where c.id=comment_id and c.is_visible));
revoke all on public.map_comment_likes from anon,authenticated;
grant select(comment_id),insert(comment_id,visitor_id) on public.map_comment_likes to anon,authenticated;
grant all on public.map_comment_likes to service_role;

create view public.map_comment_like_counts with (security_invoker=true) as
select comment_id,count(*) as like_count from public.map_comment_likes group by comment_id;
grant select on public.map_comment_like_counts to anon,authenticated,service_role;

create table public.map_comment_reports (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references public.map_place_comments(id) on delete cascade,
  visitor_id uuid not null,
  reason text not null check (char_length(btrim(reason)) between 1 and 1000),
  status text not null default 'pending' check (status in ('pending','reviewed','dismissed')),
  created_at timestamptz not null default now(),
  unique(comment_id,visitor_id)
);
alter table public.map_comment_reports enable row level security;
create policy "Report visible comments" on public.map_comment_reports for insert to anon,authenticated
with check (exists(select 1 from public.map_place_comments c where c.id=comment_id and c.is_visible));
revoke all on public.map_comment_reports from anon,authenticated;
grant insert(comment_id,visitor_id,reason) on public.map_comment_reports to anon,authenticated;
grant all on public.map_comment_reports to service_role;

-- Required by visibility checks; existing comments SELECT policy still hides non-visible rows.
grant select(is_visible) on public.map_place_comments to anon,authenticated;
