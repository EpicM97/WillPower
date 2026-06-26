-- Phase 15: end-of-day Journal snapshots (discipline score + counts + note).
-- One row per (user, date). Synced like the other tables.

create table if not exists public.journals (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
    date timestamptz not null,
    discipline_score double precision not null,
    completed_count integer not null default 0,
    deferred_count integer not null default 0,
    interruption_count integer not null default 0,
    total_minutes integer not null default 0,
    summary_note text,
    updated_at timestamptz not null default now(),
    deleted_at timestamptz,
    unique (user_id, date)
);

create index if not exists journals_user_updated_idx on public.journals (user_id, updated_at);

alter table public.journals enable row level security;

drop policy if exists owner_select on public.journals;
drop policy if exists owner_modify on public.journals;
create policy owner_select on public.journals
    for select using (user_id = auth.uid());
create policy owner_modify on public.journals
    for all using (user_id = auth.uid())
    with check (user_id = auth.uid());
