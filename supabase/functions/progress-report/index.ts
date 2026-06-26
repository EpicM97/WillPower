// Supabase Edge Function: progress-report
//
// GET /functions/v1/progress-report?range=week|month
//
// Aggregates the caller's completed daily_sessions + milestones over the
// requested window. RLS scopes results to the caller via JWT.
//
// Phase 11 update: now queries daily_sessions (status=2 == completed) and
// uses base_minutes / actual_minutes for estimation accuracy.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Range = "week" | "month";

interface DayBucket { date: string; minutes: number; sessions: number; }
interface HabitBucket { habit_id: string; title: string; minutes: number; sessions: number; }
interface Report {
    range: Range;
    start: string;
    end: string;
    total_minutes: number;
    session_count: number;
    milestones_completed: number;
    estimation_accuracy: number | null;
    top_habits: HabitBucket[];
    by_day: DayBucket[];
}

function startOfRange(range: Range, now: Date): Date {
    const d = new Date(now);
    d.setUTCHours(0, 0, 0, 0);
    if (range === "week") d.setUTCDate(d.getUTCDate() - 6);
    else d.setUTCDate(d.getUTCDate() - 29);
    return d;
}

const dayKey = (iso: string) => iso.slice(0, 10);

serve(async (req) => {
    if (req.method !== "GET") return new Response("Method Not Allowed", { status: 405 });

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
        return new Response(JSON.stringify({ error: "missing Authorization header" }), {
            status: 401, headers: { "content-type": "application/json" },
        });
    }

    const url = new URL(req.url);
    const rangeParam = (url.searchParams.get("range") ?? "week") as Range;
    if (rangeParam !== "week" && rangeParam !== "month") {
        return new Response(JSON.stringify({ error: "range must be week|month" }), {
            status: 400, headers: { "content-type": "application/json" },
        });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabase = createClient(supabaseUrl, anonKey, {
        global: { headers: { Authorization: authHeader } },
    });

    const now = new Date();
    const start = startOfRange(rangeParam, now);
    const startIso = start.toISOString();
    const endIso = now.toISOString();

    const { data: sessions, error: sErr } = await supabase
        .from("daily_sessions")
        .select("habit_id, date, base_minutes, actual_minutes")
        .eq("status", 2) // completed
        .gte("date", startIso)
        .lte("date", endIso)
        .is("deleted_at", null);
    if (sErr) return new Response(JSON.stringify({ error: sErr.message }), { status: 500 });

    const habitIds = Array.from(new Set((sessions ?? []).map((s) => s.habit_id).filter(Boolean)));
    const habitTitles = new Map<string, string>();
    if (habitIds.length > 0) {
        const { data: habits } = await supabase
            .from("habits")
            .select("id, title")
            .in("id", habitIds);
        for (const h of habits ?? []) habitTitles.set(h.id, h.title);
    }

    const byDay = new Map<string, DayBucket>();
    const byHabit = new Map<string, HabitBucket>();
    let totalMinutes = 0;
    let sessionCount = 0;
    let accNumer = 0;
    let accDenom = 0;

    for (const s of sessions ?? []) {
        const actual: number = s.actual_minutes ?? 0;
        const base: number | null = s.base_minutes ?? null;
        totalMinutes += actual;
        sessionCount += 1;

        if (base != null && base > 0) {
            const score = Math.max(0, 1 - Math.abs(actual - base) / base);
            accNumer += score;
            accDenom += 1;
        }

        const key = dayKey(s.date);
        const db = byDay.get(key) ?? { date: key, minutes: 0, sessions: 0 };
        db.minutes += actual; db.sessions += 1;
        byDay.set(key, db);

        if (s.habit_id) {
            const hb = byHabit.get(s.habit_id) ?? {
                habit_id: s.habit_id,
                title: habitTitles.get(s.habit_id) ?? "Untitled",
                minutes: 0, sessions: 0,
            };
            hb.minutes += actual; hb.sessions += 1;
            byHabit.set(s.habit_id, hb);
        }
    }

    const { data: milestones, error: mErr } = await supabase
        .from("milestones")
        .select("id")
        .eq("is_completed", true)
        .gte("completed_at", startIso)
        .lte("completed_at", endIso)
        .is("deleted_at", null);
    if (mErr) return new Response(JSON.stringify({ error: mErr.message }), { status: 500 });

    const report: Report = {
        range: rangeParam,
        start: startIso,
        end: endIso,
        total_minutes: totalMinutes,
        session_count: sessionCount,
        milestones_completed: milestones?.length ?? 0,
        estimation_accuracy: accDenom > 0 ? accNumer / accDenom : null,
        top_habits: [...byHabit.values()].sort((a, b) => b.minutes - a.minutes).slice(0, 5),
        by_day: [...byDay.values()].sort((a, b) => (a.date < b.date ? -1 : 1)),
    };

    return new Response(JSON.stringify(report), {
        headers: { "content-type": "application/json" },
    });
});
