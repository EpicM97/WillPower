-- Phase 20.10: Injected interruptions carry their own energy level (they have
-- no underlying habit). Add energy_raw so the chosen energy survives sync.
-- 0 = low, 1 = mid, 2 = high. Defaults to mid for existing/legacy rows.
alter table public.daily_sessions
    add column if not exists energy_raw integer not null default 1;
