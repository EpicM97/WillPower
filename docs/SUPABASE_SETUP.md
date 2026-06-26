# Supabase setup

The Supabase CLI is installed (`brew install supabase/tap/supabase`, currently 2.101.0).
After two one-time interactive steps below, the AI agent can drive all subsequent ops via `make` without manual paste-in.

## One-time (you, interactive)

1. **Log in.** Opens your browser for OAuth:
   ```
   make supabase-login
   ```
2. **Link this repo to your project.** Grab `<ref>` from the dashboard URL (`https://supabase.com/dashboard/project/<ref>`):
   ```
   make supabase-link REF=<ref>
   ```
   This writes a `.temp/` token to `supabase/.branches` and is gitignored.

3. **Paste credentials.** Put your project URL + anon key into the gitignored `Sources/HabitTracker/Supabase/Supabase.xcconfig`.

## Autonomous (AI or you, unattended)

After the steps above, the agent can run:

| Command | What it does |
| --- | --- |
| `make db-push` | Applies SQL under `supabase/migrations/` to the linked project. |
| `make db-diff NAME=foo` | Captures local schema diff into a new timestamped migration. |
| `make functions-deploy` | Deploys every function under `supabase/functions/`. |
| `make functions-deploy FN=progress-report` | Deploys one. |
| `make functions-serve FN=progress-report` | Local hot-reload server. |
| `make build` / `make test` | Xcode build & test (preflight sims shutdown automatically). |

## What still requires you

- **Apple Developer portal toggles** — Sign in with Apple capability, App Groups registration on a paid account, Push capability (if added later).
- **Initial OAuth login + link** — token can't be issued non-interactively without a service-role secret you shouldn't share with the agent.
- **Pasting secrets** into `Supabase.xcconfig`.

Everything else is now agent-drivable.
