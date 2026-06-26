# WillPower / HabitTracker — developer + Supabase ops.
#
# One-time setup (user-interactive, browser-based):
#   make supabase-login            # opens browser for OAuth
#   make supabase-link REF=abcdef  # links this repo to your project
#
# After that, the rest can run unattended (including by the AI agent):
#   make db-push                   # apply SQL migrations
#   make functions-deploy          # deploy all Edge Functions
#   make functions-deploy FN=progress-report
#   make test
#   make build

PROJECT      := HabitTracker
SCHEME       := $(PROJECT)
DESTINATION  := platform=iOS Simulator,name=iPhone 17

# ----- Build / test -----

.PHONY: gen
gen:
	xcodegen generate

.PHONY: build
build: gen
	xcodebuild -scheme $(SCHEME) -destination '$(DESTINATION)' build

.PHONY: test
test: gen
	xcrun simctl shutdown all >/dev/null 2>&1 || true
	xcodebuild test -scheme $(SCHEME) -destination '$(DESTINATION)'

.PHONY: clean
clean:
	xcodebuild clean -scheme $(SCHEME)
	rm -rf $(PROJECT).xcodeproj

# ----- Supabase ops -----

.PHONY: supabase-install
supabase-install:
	@command -v supabase >/dev/null 2>&1 || brew install supabase/tap/supabase

.PHONY: supabase-login
supabase-login: supabase-install
	supabase login

.PHONY: supabase-link
supabase-link: supabase-install
	@if [ -z "$(REF)" ]; then echo "usage: make supabase-link REF=<project-ref>"; exit 1; fi
	supabase link --project-ref $(REF)

.PHONY: supabase-status
supabase-status:
	supabase status

# Apply SQL migrations under supabase/migrations to the linked remote project.
.PHONY: db-push
db-push: supabase-install
	supabase db push

# Generate a new migration from a local diff.
.PHONY: db-diff
db-diff:
	@if [ -z "$(NAME)" ]; then echo "usage: make db-diff NAME=add_streaks"; exit 1; fi
	supabase db diff -f $(NAME)

# Deploy a single Edge Function (FN=name) or all of them.
.PHONY: functions-deploy
functions-deploy: supabase-install
	@if [ -n "$(FN)" ]; then \
	    supabase functions deploy $(FN); \
	else \
	    for d in supabase/functions/*/; do \
	        name=$$(basename $$d); \
	        echo "==> deploying $$name"; \
	        supabase functions deploy $$name || exit 1; \
	    done; \
	fi

# Upload card-background assets (supabase/storage/backgrounds/**) to the public
# `backgrounds` bucket. Run `make db-push` first so the bucket + policy exist.
# Add stock images under supabase/storage/backgrounds/stock/ before running.
.PHONY: backgrounds-upload
backgrounds-upload: supabase-install
	supabase storage cp --experimental \
	    supabase/storage/backgrounds/colors.json ss:///backgrounds/colors.json
	supabase storage cp --recursive --experimental \
	    supabase/storage/backgrounds/stock ss:///backgrounds

# Run a function locally with hot reload at http://127.0.0.1:54321/functions/v1/$FN
.PHONY: functions-serve
functions-serve:
	@if [ -z "$(FN)" ]; then echo "usage: make functions-serve FN=progress-report"; exit 1; fi
	supabase functions serve $(FN) --no-verify-jwt

# Generate Postgres types into Swift (optional; not wired yet).
.PHONY: db-types
db-types:
	supabase gen types swift --local > Sources/HabitTracker/Supabase/GeneratedTypes.swift
