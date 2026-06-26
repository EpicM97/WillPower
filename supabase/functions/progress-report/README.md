# progress-report

Aggregates the caller's logs into a weekly or monthly summary.

## Deploy

```sh
supabase functions deploy progress-report
```

## Invoke

```sh
curl -H "Authorization: Bearer <USER_JWT>" \
  "https://<project>.supabase.co/functions/v1/progress-report?range=week"
```

`range` must be `week` (last 7 days) or `month` (last 30 days). Defaults to `week`.

## Response

```json
{
  "range": "week",
  "start": "2026-05-14T00:00:00.000Z",
  "end":   "2026-05-21T16:00:00.000Z",
  "total_minutes": 320,
  "session_count": 12,
  "milestones_completed": 1,
  "top_habits": [{ "habit_id": "...", "title": "Sprint", "minutes": 80, "sessions": 4 }],
  "by_day":     [{ "date": "2026-05-14", "minutes": 45, "sessions": 2 }]
}
```

RLS in the database scopes everything to `auth.uid()` — no service-role key required.
