-- Phase 9: expected vs actual duration on daily_logs + per-milestone weight.
-- Both additive — old clients keep working; new accuracy report ignores rows
-- with NULL expected_minutes.

alter table public.daily_logs
    add column if not exists expected_minutes integer;

alter table public.milestones
    add column if not exists weight double precision not null default 1.0;
