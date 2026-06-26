// Supabase Edge Function: task-ingest
//
// POST /functions/v1/task-ingest
//   { "text": "tomorrow I want to run 5k, also reply to investor emails ~20 min" }
//
// Forwards `text` to Gemini and returns a structured `IngestProposal` that the
// iOS client renders for confirmation before writing to the DB. Nothing is
// inserted server-side — the user always confirms.
//
// Approach mirrors Chippy's vlm-intake: Gemini API direct, key in Supabase
// secrets, JWT-scoped, never trust client model output without user confirm.
//
// Deploy: supabase functions deploy task-ingest
// Required env: supabase secrets set GEMINI_API_KEY=<from aistudio.google.com>

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";

interface ProposedHabit {
    title: string;
    energy: "high" | "mid" | "low";
    estimated_minutes: number;
    project_hint?: string;
}
interface ProposedMilestone {
    title: string;
    project_hint?: string;
}
interface IngestProposal {
    habits: ProposedHabit[];
    milestones: ProposedMilestone[];
    interruptions: { title: string; expected_minutes: number }[];
    raw_input: string;
    model_note?: string;
}

const SYSTEM_PROMPT = `You parse a user's free-form text dump into structured intent for a habit/project tracker called WillPower. The user is a builder — they think in habits, projects, milestones, and ad-hoc interruptions.

Output STRICT JSON matching this schema (no commentary, no markdown fence):
{
  "habits":       [{"title": str, "energy": "high"|"mid"|"low", "estimated_minutes": int, "project_hint": str?}],
  "milestones":   [{"title": str, "project_hint": str?}],
  "interruptions": [{"title": str, "expected_minutes": int}],
  "model_note":   str?
}

Rules:
- A "habit" is recurring work the user wants to do regularly (workout, deep work block, reading).
- A "milestone" is a one-off achievement tied to a project ("ship v1", "10k users").
- An "interruption" is a one-shot today-only task ("phone call with X", "fix laptop").
- Energy: 'high' for focus-heavy/physical, 'mid' for routine work, 'low' for admin/passive.
- Default estimated_minutes to 30 if unclear, never zero.
- Don't invent items not in the text. Empty arrays are fine.
- 'project_hint' is the user's casual reference ("the website", "marathon training"), not a UUID.
- 'model_note' is optional — use it to flag ambiguity ("treated 'gym' as habit").`;

function corsHeaders(req: Request): Record<string, string> {
    const origin = req.headers.get("origin") ?? "*";
    return {
        "access-control-allow-origin": origin,
        "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
        "access-control-allow-methods": "POST, OPTIONS",
    };
}

serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response(null, { status: 204, headers: corsHeaders(req) });
    }
    if (req.method !== "POST") {
        return new Response("Method Not Allowed", { status: 405, headers: corsHeaders(req) });
    }
    if (!req.headers.get("Authorization")) {
        return json({ error: "missing Authorization header" }, 401, req);
    }
    if (!GEMINI_API_KEY) {
        return json({ error: "GEMINI_API_KEY not configured on the function" }, 500, req);
    }

    let text: string;
    try {
        const body = await req.json();
        text = String(body.text ?? "").trim();
    } catch {
        return json({ error: "invalid JSON body" }, 400, req);
    }
    if (!text) {
        return json({ error: "field 'text' is required" }, 400, req);
    }
    if (text.length > 4000) {
        return json({ error: "text too long (max 4000 chars)" }, 413, req);
    }

    try {
        const proposal = await parseWithGemini(text);
        return json(proposal, 200, req);
    } catch (e) {
        const message = e instanceof Error ? e.message : String(e);
        return json({ error: `parse failed: ${message}` }, 502, req);
    }
});

async function parseWithGemini(text: string): Promise<IngestProposal> {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`;
    const body = {
        system_instruction: { parts: [{ text: SYSTEM_PROMPT }] },
        contents: [{ role: "user", parts: [{ text }] }],
        generationConfig: { temperature: 0.2, response_mime_type: "application/json" },
    };
    const res = await fetch(url, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(body),
    });
    if (!res.ok) {
        throw new Error(`Gemini ${res.status}: ${(await res.text()).slice(0, 300)}`);
    }
    const data = await res.json();
    const raw = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
    let parsed: Partial<IngestProposal> = {};
    try { parsed = JSON.parse(raw); } catch { /* swallow; return empty proposal */ }
    return {
        habits: Array.isArray(parsed.habits) ? parsed.habits.slice(0, 10) : [],
        milestones: Array.isArray(parsed.milestones) ? parsed.milestones.slice(0, 10) : [],
        interruptions: Array.isArray(parsed.interruptions) ? parsed.interruptions.slice(0, 10) : [],
        raw_input: text,
        model_note: typeof parsed.model_note === "string" ? parsed.model_note : undefined,
    };
}

function json(payload: unknown, status: number, req: Request): Response {
    return new Response(JSON.stringify(payload), {
        status,
        headers: { "content-type": "application/json", ...corsHeaders(req) },
    });
}
