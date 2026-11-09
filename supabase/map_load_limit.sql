create table public.map_load_usage (
  month_start date primary key,
  requests integer not null check (requests between 0 and 9999)
);
alter table public.map_load_usage enable row level security;
revoke all on public.map_load_usage from public, anon, authenticated;
grant select, insert, update on public.map_load_usage to service_role;
create policy map_load_service_only on public.map_load_usage for all to service_role using (true) with check (true);
-- Initial allowance includes the 116 observed requests plus 84 safety reservations.
insert into public.map_load_usage values(date_trunc('month',now() at time zone 'America/Los_Angeles')::date,200);
create function public.reserve_map_load() returns jsonb
language plpgsql security invoker set search_path = '' as $$
declare bucket date := date_trunc('month', now() at time zone 'America/Los_Angeles')::date;
used integer;
begin
  insert into public.map_load_usage(month_start,requests) values(bucket,1)
  on conflict(month_start) do update set requests=public.map_load_usage.requests+1
  where public.map_load_usage.requests < 9999
  returning requests into used;
  if used is null then
    return jsonb_build_object('allowed',false,'used',9999,'limit',9999);
  end if;
  return jsonb_build_object('allowed',true,'used',used,'limit',9999);
end;
$$;
revoke all on function public.reserve_map_load() from public, anon, authenticated;
grant execute on function public.reserve_map_load() to service_role;