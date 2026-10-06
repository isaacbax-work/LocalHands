-- When a gathering happens (optional), and moderation state
alter table posts add column starts_at timestamptz;
alter table posts add column hidden boolean not null default false;
grant select (starts_at) on posts to anon; -- signed-out visitors read posts column by column

-- Members only choose a post's content: never its owner, timestamps or moderation fields
revoke insert, update on posts from authenticated;
grant insert (type, title, descr, price, contact, lat, lng, mode, km, route, starts_at) on posts to authenticated;

-- A route must be a list of [lat, lng] pairs; one malformed route would otherwise break the map for everyone
alter table posts drop constraint posts_route_check;
alter table posts add constraint posts_route_shape check (
  route is null or (
    jsonb_typeof(route) = 'array' and jsonb_array_length(route) between 2 and 5000
    and not jsonb_path_exists(route, 'strict $[*] ? (@.type() != "array" || @.size() != 2)')
    and not jsonb_path_exists(route, 'strict $[*][*] ? (@.type() != "number")')
    and not jsonb_path_exists(route, 'strict $[*][0] ? (@ < -90 || @ > 90)')
    and not jsonb_path_exists(route, 'strict $[*][1] ? (@ < -180 || @ > 180)')
  )
);
alter table posts add constraint posts_route_mode check ((route is null) = (mode is null) and (route is null) = (km is null));
alter table posts add constraint posts_km_range check (km is null or km between 0 and 1000);

-- Stop one account flooding the map and everyone's notifications
create index on posts (user_id, created_at);
create function posts_rate_limit() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from posts where user_id = new.user_id and created_at > now() - interval '1 hour') >= 10 then
    raise exception 'You can make up to 10 posts an hour. Try again later.';
  end if;
  return new;
end $$;
create trigger posts_rate_limit before insert on posts for each row execute function posts_rate_limit();

-- Reported posts: three reports from different members hides a post.
-- Review in the dashboard's posts table; set hidden = false to restore one.
drop policy "anyone reads posts" on posts;
create policy "anyone reads visible posts" on posts for select using (not hidden or user_id = auth.uid());

create table reports (
  post_id uuid not null references posts on delete cascade,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
alter table reports enable row level security;
create policy "members report as themselves" on reports for insert to authenticated with check (user_id = auth.uid());

create function hide_reported_post() returns trigger language plpgsql security definer set search_path = public as $$
begin
  update posts set hidden = true
  where id = new.post_id and (select count(*) from reports where post_id = new.post_id) >= 3;
  return new;
end $$;
create trigger hide_reported_post after insert on reports for each row execute function hide_reported_post();

-- Register this browser for push. A shared device moves to whoever turned notifications on last,
-- which a plain upsert can't do because the old row belongs to someone else.
create function register_device(p_endpoint text, p_p256dh text, p_auth text) returns void
language sql security definer set search_path = public as $$
  insert into push_subscriptions (endpoint, user_id, p256dh, auth)
  values (p_endpoint, auth.uid(), p_p256dh, p_auth)
  on conflict (endpoint) do update set user_id = excluded.user_id, p256dh = excluded.p256dh, auth = excluded.auth;
$$;
revoke execute on function register_device from public, anon;
grant execute on function register_device to authenticated;
