-- WillPower / HabitTracker — initial schema for sync.
-- Apply via Supabase SQL editor or `supabase db push`.
-- Every table is scoped to auth.uid() via RLS so users only see their own rows.

create extension if not exists "uuid-ossp";

-- Goals -----------------------------------------------------------------
create table if not exists public.goals (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
    title text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz
);
create index if not exists goals_user_updated_idx on public.goals (user_id, updated_at);

-- Projects --------------------------------------------------------------
create table if not exists public.projects (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
    goal_id uuid references public.goals(id) on delete cascade,
    title text not null,
    updated_at timestamptz not null default now(),
    deleted_at timestamptz
);
create index if not exists projects_user_updated_idx on public.projects (user_id, updated_at);

-- Milestones ------------------------------------------------------------
create table if not exists public.milestones (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
    project_id uuid references public.projects(id) on delete cascade,
    title text not null,
    is_completed boolean not null default false,
    completed_at timestamptz,
    "order" integer not null default 0,
    updated_at timestamptz not null default now(),
    deleted_at timestamptz
);
create index if not exists milestones_user_updated_idx on public.milestones (user_id, updated_at);

-- Habits ----------------------------------------------------------------
create table if not exists public.habits (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
    project_id uuid references public.projects(id) on delete cascade,
    title text not null,
    energy_raw integer not null default 1,
    estimated_minutes integer not null default 30,
    "order" integer not null default 0,
    updated_at timestamptz not null default now(),
    deleted_at timestamptz
);
create index if not exists habits_user_updated_idx on public.habits (user_id, updated_at);

-- Daily logs ------------------------------------------------------------
create table if not exists public.daily_logs (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
    habit_id uuid references public.habits(id) on delete cascade,
    date timestamptz not null default now(),
    duration_minutes integer not null,
    updated_at timestamptz not null default now(),
    deleted_at timestamptz
);
create index if not exists daily_logs_user_updated_idx on public.daily_logs (user_id, updated_at);

-- RLS ------------------------------------------------------------------
alter table public.goals enable row level security;
alter table public.projects enable row level security;
alter table public.milestones enable row level security;
alter table public.habits enable row level security;
alter table public.daily_logs enable row level security;

do $$
declare t text;
begin
    foreach t in array array['goals','projects','milestones','habits','daily_logs'] loop
        execute format($f$
            drop policy if exists owner_select on public.%I;
            drop policy if exists owner_modify on public.%I;
            create policy owner_select on public.%I
                for select using (user_id = auth.uid());
            create policy owner_modify on public.%I
                for all using (user_id = auth.uid())
                with check (user_id = auth.uid());
        $f$, t, t, t, t);
    end loop;
end$$;
