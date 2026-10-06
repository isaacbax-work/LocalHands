-- Member profile: home suburb + notification preferences
create table profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text check (char_length(display_name) <= 60),
  suburb text check (char_length(suburb) <= 200),
  lat double precision check (lat between -90 and 90),
  lng double precision check (lng between -180 and 180),
  radius_km int not null default 5 check (radius_km between 1 and 50),
  notify boolean not null default false,
  notify_types text[] not null default '{sale,free,task,service,group}'
    check (notify_types <@ '{sale,free,task,service,group}')
);
alter table profiles enable row level security;
create policy "members manage own profile" on profiles for all to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

create table posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  type text not null check (type in ('sale','free','task','service','group')),
  title text not null check (char_length(title) between 1 and 80),
  descr text not null default '' check (char_length(descr) <= 400),
  price text not null default '' check (char_length(price) <= 30),
  contact text not null check (char_length(contact) between 1 and 80),
  lat double precision not null check (lat between -90 and 90),
  lng double precision not null check (lng between -180 and 180),
  mode text check (mode in ('foot','bike')),
  km numeric(6,1),
  route jsonb check (route is null or jsonb_array_length(route) <= 5000),
  created_at timestamptz not null default now(),
  notified_at timestamptz
);
create index on posts (created_at desc);
alter table posts enable row level security;
create policy "anyone reads posts" on posts for select using (true);
create policy "members post as themselves" on posts for insert to authenticated
  with check (user_id = auth.uid() and notified_at is null);
create policy "owners delete their posts" on posts for delete to authenticated
  using (user_id = auth.uid());

-- Signed-out visitors can browse, but contact details are for members only
revoke all on posts from anon;
grant select (id, user_id, type, title, descr, price, lat, lng, mode, km, route, created_at) on posts to anon;

-- Browser push endpoints, one per device
create table push_subscriptions (
  endpoint text primary key,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now()
);
alter table push_subscriptions enable row level security;
create policy "members manage own devices" on push_subscriptions for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
