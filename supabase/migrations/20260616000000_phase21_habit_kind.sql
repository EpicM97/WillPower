-- Phase 21: Habits have a time-shape (kind) so the budget/compression engine
-- can tell apart duration habits (consume budget), moment habits (~0 min), and
-- anchored fixed blocks (wake-up, 9-5). 0 = duration, 1 = moment, 2 = anchored.
-- Defaults to duration so existing rows keep their current budget behavior.
alter table public.habits
    add column if not exists kind_raw integer not null default 0;
