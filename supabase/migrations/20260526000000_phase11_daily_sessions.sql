-- Phase 11: replace daily_logs with daily_sessions (template/instance split).
-- daily_logs is dropped; we're pre-PMF and breaking the schema cleanly.
-- Habit.priority added for compression-engine deferral ordering.

drop table if exists public.daily_logs cascade;

alter table public.habits
    add column if not exists priority integer not null default 1;

create table if not exists public.daily_sessions (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
    habit_id uuid references public.habits(id) on delete cascade,
    date timestamptz not null default now(),
    base_minutes integer not null,
    compressed_minutes integer not null,
    actual_minutes integer,
    status integer not null default 0, -- 0=pending 1=active 2=completed 3=deferred
    is_interruption boolean not null default false,
    order_hint integer not null default 0,
    started_at timestamptz,
    completed_at timestamptz,
    note text,
    updated_at timestamptz not null default now(),
    deleted_at timestamptz
);

create index if not exists daily_sessions_user_date_idx on public.daily_sessions (user_id, date);
create index if not exists daily_sessions_user_updated_idx on public.daily_sessions (user_id, updated_at);

alter table public.daily_sessions enable row level security;

drop policy if exists owner_select on public.daily_sessions;
drop policy if exists owner_modify on public.daily_sessions;
create policy owner_select on public.daily_sessions
    for select using (user_id = auth.uid());
create policy owner_modify on public.daily_sessions
    for all using (user_id = auth.uid())
    with check (user_id = auth.uid());
