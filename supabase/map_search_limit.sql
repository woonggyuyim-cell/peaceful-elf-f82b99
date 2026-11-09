create table public.map_search_usage (
  month_start date primary key,
  requests integer not null check (requests between 0 and 4999)
);
alter table public.map_search_usage enable row level security;
revoke all on public.map_search_usage from public, anon, authenticated;
grant select, insert, update on public.map_search_usage to service_role;
create function public.reserve_map_search() returns jsonb
language plpgsql security invoker set search_path = '' as $$
declare bucket date := date_trunc('month', now() at time zone 'America/Los_Angeles')::date;
used integer;
begin
  insert into public.map_search_usage(month_start,requests) values(bucket,1)
  on conflict(month_start) do update set requests=public.map_search_usage.requests+1
  where public.map_search_usage.requests < 4999
  returning requests into used;
  if used is null then
    return jsonb_build_object('allowed',false,'used',4999,'limit',4999);
  end if;
  return jsonb_build_object('allowed',true,'used',used,'limit',4999);
end;
$$;
revoke all on function public.reserve_map_search() from public, anon, authenticated;
grant execute on function public.reserve_map_search() to service_role;
create policy map_search_service_only on public.map_search_usage for all to service_role using (true) with check (true);
