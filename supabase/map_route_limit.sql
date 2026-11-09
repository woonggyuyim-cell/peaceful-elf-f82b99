create table public.map_route_usage (
  month_start date primary key,
  requests integer not null check (requests between 0 and 4999)
);
alter table public.map_route_usage enable row level security;
revoke all on public.map_route_usage from public, anon, authenticated;
grant select, insert, update on public.map_route_usage to service_role;
create policy map_route_service_only on public.map_route_usage for all to service_role using (true) with check (true);
-- Initial allowance includes the 9 observed requests plus 41 safety reservations.
insert into public.map_route_usage values(date_trunc('month',now() at time zone 'America/Los_Angeles')::date,50);
create function public.reserve_map_route() returns jsonb
language plpgsql security invoker set search_path = '' as $$
declare bucket date := date_trunc('month', now() at time zone 'America/Los_Angeles')::date;
used integer;
begin
  insert into public.map_route_usage(month_start,requests) values(bucket,1)
  on conflict(month_start) do update set requests=public.map_route_usage.requests+1
  where public.map_route_usage.requests < 4999
  returning requests into used;
  if used is null then
    return jsonb_build_object('allowed',false,'used',4999,'limit',4999);
  end if;
  return jsonb_build_object('allowed',true,'used',used,'limit',4999);
end;
$$;
revoke all on function public.reserve_map_route() from public, anon, authenticated;
grant execute on function public.reserve_map_route() to service_role;