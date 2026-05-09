-- ============================================================
-- bowbuilds — Supabase PostgreSQL Schema
-- ============================================================

-- Enable UUID generation
create extension if not exists "pgcrypto";

-- ============================================================
-- USERS (mirrors Supabase Auth; extended profile data)
-- ============================================================
create table if not exists public.users (
  id            uuid primary key references auth.users(id) on delete cascade,
  email         text not null,
  plan_tier     text not null default 'free' check (plan_tier in ('free', 'pro')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

alter table public.users enable row level security;

create policy "Users can view own profile"
  on public.users for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on public.users for update
  using (auth.uid() = id);

-- ============================================================
-- COMPONENT CATALOG (seed / admin-managed)
-- ============================================================
create table if not exists public.component_catalog (
  id              uuid primary key default gen_random_uuid(),
  category        text not null check (category in ('bow', 'cam', 'arrow', 'rest', 'sight', 'stabilizer', 'accessory')),
  brand           text not null,
  model           text not null,
  specs           jsonb not null default '{}',  -- flexible spec bag (ATA, brace height, IBO, etc.)
  compatible_with uuid[] default '{}',           -- array of catalog IDs this is compatible with
  is_active       boolean not null default true,
  created_at      timestamptz not null default now()
);

alter table public.component_catalog enable row level security;

create policy "Catalog is publicly readable"
  on public.component_catalog for select
  using (true);

create policy "Only service role can modify catalog"
  on public.component_catalog for all
  using (auth.role() = 'service_role');

-- ============================================================
-- BOW BUILDS
-- ============================================================
create table if not exists public.bow_builds (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.users(id) on delete cascade,
  name            text not null,
  bow_catalog_id  uuid references public.component_catalog(id) on delete set null,
  cam_type        text,                          -- e.g. 'single', 'binary', 'hybrid', 'twin'
  draw_length_in  numeric(4,1),                  -- inches
  draw_weight_lbs numeric(4,1),                  -- lbs
  notes           text,
  is_public       boolean not null default false,
  version         integer not null default 1,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

alter table public.bow_builds enable row level security;

create policy "Users can read own builds"
  on public.bow_builds for select
  using (auth.uid() = user_id or is_public = true);

create policy "Users can insert own builds"
  on public.bow_builds for insert
  with check (auth.uid() = user_id);

create policy "Users can update own builds"
  on public.bow_builds for update
  using (auth.uid() = user_id);

create policy "Users can delete own builds"
  on public.bow_builds for delete
  using (auth.uid() = user_id);

-- ============================================================
-- BUILD COMPONENTS (accessories linked to a bow build)
-- ============================================================
create table if not exists public.build_components (
  id               uuid primary key default gen_random_uuid(),
  bow_build_id     uuid not null references public.bow_builds(id) on delete cascade,
  component_id     uuid references public.component_catalog(id) on delete set null,
  component_type   text not null check (component_type in ('rest', 'sight', 'stabilizer', 'arrow', 'accessory')),
  custom_label     text,                          -- if user adds a component not in catalog
  custom_specs     jsonb default '{}',
  position         integer not null default 0,   -- ordering within a type
  created_at       timestamptz not null default now()
);

alter table public.build_components enable row level security;

create policy "Users can read own build components"
  on public.build_components for select
  using (
    exists (
      select 1 from public.bow_builds b
      where b.id = build_components.bow_build_id
        and (b.user_id = auth.uid() or b.is_public = true)
    )
  );

create policy "Users can insert own build components"
  on public.build_components for insert
  with check (
    exists (
      select 1 from public.bow_builds b
      where b.id = build_components.bow_build_id
        and b.user_id = auth.uid()
    )
  );

create policy "Users can update own build components"
  on public.build_components for update
  using (
    exists (
      select 1 from public.bow_builds b
      where b.id = build_components.bow_build_id
        and b.user_id = auth.uid()
    )
  );

create policy "Users can delete own build components"
  on public.build_components for delete
  using (
    exists (
      select 1 from public.bow_builds b
      where b.id = build_components.bow_build_id
        and b.user_id = auth.uid()
    )
  );

-- ============================================================
-- TUNING SESSIONS
-- ============================================================
create table if not exists public.tuning_sessions (
  id                    uuid primary key default gen_random_uuid(),
  bow_build_id          uuid not null references public.bow_builds(id) on delete cascade,
  user_id               uuid not null references public.users(id) on delete cascade,
  paper_tear_result     text check (paper_tear_result in ('perfect', 'high', 'low', 'left', 'right', 'high_left', 'high_right', 'low_left', 'low_right')),
  nocking_point_mm      numeric(5,2),             -- measured from berger hole
  tiller_top_mm         numeric(5,2),
  tiller_bottom_mm      numeric(5,2),
  cam_timing_note       text,
  recommended_fixes     jsonb not null default '[]', -- ordered array of fix step strings
  session_notes         text,
  completed_at          timestamptz,
  created_at            timestamptz not null default now()
);

alter table public.tuning_sessions enable row level security;

create policy "Users can read own tuning sessions"
  on public.tuning_sessions for select
  using (auth.uid() = user_id);

create policy "Users can insert own tuning sessions"
  on public.tuning_sessions for insert
  with check (auth.uid() = user_id);

create policy "Users can update own tuning sessions"
  on public.tuning_sessions for update
  using (auth.uid() = user_id);

create policy "Users can delete own tuning sessions"
  on public.tuning_sessions for delete
  using (auth.uid() = user_id);

-- ============================================================
-- SUBSCRIPTIONS (Stripe)
-- ============================================================
create table if not exists public.subscriptions (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references public.users(id) on delete cascade,
  stripe_customer_id    text unique,
  stripe_subscription_id text unique,
  plan_tier             text not null default 'free' check (plan_tier in ('free', 'pro')),
  status                text not null default 'inactive',  -- active | past_due | canceled | inactive
  current_period_start  timestamptz,
  current_period_end    timestamptz,
  cancel_at_period_end  boolean not null default false,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

alter table public.subscriptions enable row level security;

create policy "Users can read own subscription"
  on public.subscriptions for select
  using (auth.uid() = user_id);

create policy "Only service role can modify subscriptions"
  on public.subscriptions for all
  using (auth.role() = 'service_role');

-- ============================================================
-- WAITLIST
-- ============================================================
create table if not exists public.waitlist (
  id          uuid primary key default gen_random_uuid(),
  email       text not null unique,
  referrer    text,
  metadata    jsonb default '{}',
  created_at  timestamptz not null default now()
);

alter table public.waitlist enable row level security;

create policy "Anyone can join waitlist"
  on public.waitlist for insert
  with check (true);

create policy "Only service role can read waitlist"
  on public.waitlist for select
  using (auth.role() = 'service_role');

-- ============================================================
-- UTILITY: auto-update updated_at
-- ============================================================
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_users_updated_at
  before update on public.users
  for each row execute procedure public.set_updated_at();

create trigger trg_bow_builds_updated_at
  before update on public.bow_builds
  for each row execute procedure public.set_updated_at();

create trigger trg_subscriptions_updated_at
  before update on public.subscriptions
  for each row execute procedure public.set_updated_at();

-- ============================================================
-- INDEXES
-- ============================================================
create index if not exists idx_bow_builds_user_id       on public.bow_builds(user_id);
create index if not exists idx_build_components_build   on public.build_components(bow_build_id);
create index if not exists idx_tuning_sessions_build    on public.tuning_sessions(bow_build_id);
create index if not exists idx_tuning_sessions_user     on public.tuning_sessions(user_id);
create index if not exists idx_subscriptions_user       on public.subscriptions(user_id);
create index if not exists idx_component_catalog_cat    on public.component_catalog(category);