-- Phase 19: Stop control logs partial completions. Add stopped_early flag so
-- a session completed-but-stopped-early survives a sync round-trip.
alter table public.daily_sessions
    add column if not exists stopped_early boolean not null default false;
