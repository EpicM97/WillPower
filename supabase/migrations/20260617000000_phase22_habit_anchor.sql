-- Phase 22: anchored habits carry a clock time (minutes from midnight).
-- Additive + backward-compatible: nullable, no default needed (nil = unanchored).
-- Existing per-user RLS on public.habits already covers the new column.
alter table public.habits
    add column if not exists anchor_minute_of_day integer;
