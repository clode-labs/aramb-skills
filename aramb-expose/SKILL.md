---
name: aramb-expose
description: >
  Expose local services publicly via aramb expose tunnels (proxy.clode.space URLs).
  Use when: making a local service accessible via a public URL for preview/demo purposes.
  Creates named tunnel clients that persist in the registry and can be reused across deployments.
  NOT for: production deployments or exposing databases/caches.
---

# Aramb Expose Tunnels

## MUST rules — read before anything else

1. **If this skill exposes a URL the user can reach, surface it as a URL-kind artifact** — either on `aramb_tasks.update_me` (when closing a task) or on `aramb_chat.deliver_artifacts` (solo / mid-task recall). Brahmi auto-registers the preview-URL state from that single call — no separate `update_preview_url` step. Mentioning the URL in chat prose is not a substitute — the chip pipeline cannot reconstruct chips from prose after the fact.
   - **Failure mode:** Putting the URL only in prose leaves the user with dead text — no clickable chip, no preview state, no in-app iframe wiring.

## Overview

`aramb expose` creates named tunnel clients that route public HTTPS URLs to local services.
Public URLs are in the format `https://<slug>.proxy.clode.space`.

- `--services` — registers all services you want to configure (name=http://localhost:port pairs)
- `--public` — selects which registered services actually get a public URL (comma-separated names)

Named clients persist in the registry (`aramb expose list`) and are reused across deployments of the same app.

---

## Full Flow

### Step 1 — List clients and check for the app slug

```bash
aramb expose list
```

Output columns: NAME, ID, SERVICES, PUBLIC.

Parse the row matching your `<app-slug>`:
- **No matching row** → create a new client (Step 2a).
- **Row exists, SERVICES and PUBLIC already match** → skip to Step 3 (run directly).
- **Row exists, SERVICES or PUBLIC differ** → update the client (Step 2b), then go to Step 3.

To get the exact current values for comparison, use JSON output:
```bash
aramb expose list -o json
```
This gives you structured `services` and `public` fields to diff against what you need.

### Step 2a — Create a new named client

```bash
aramb expose create \
  --name <app-slug> \
  --services "frontend=http://localhost:3000,api=http://localhost:8080" \
  --public "frontend,api"
```

- `--name`: the app slug — use exactly the slug Brahmi assigned to this application (available as `APP_SLUG` or derivable from the task context). Lowercase, hyphens only.
- `--services`: comma-separated `name=http://localhost:port` pairs. Register **all** services you want to configure, even ones not yet public.
- `--public`: comma-separated names from `--services` that should receive a public HTTPS URL. Only HTTP services can be made public.

### Step 2b — Update an existing client (config mismatch)

```bash
aramb expose update <app-slug> \
  --services "frontend=http://localhost:3000,api=http://localhost:8080" \
  --public "frontend,api"
```

Pass the full desired `--services` and `--public` values — not just the changed parts.

### Step 3 — Run the tunnel (long-running process)

```bash
APP_SLUG="<app-slug>"
EXPOSE_LOG="/tmp/aramb-expose-${APP_SLUG}.log"

aramb expose run "$APP_SLUG" > "$EXPOSE_LOG" 2>&1 &
EXPOSE_PID=$!

echo "Tunnel process started (PID: $EXPOSE_PID) — waiting for public URLs..."
```

The process must stay running for the tunnel to stay alive. Do not kill it on task completion.

### Step 4 — Collect ALL public URLs

Each service listed in `--public` gets its own `Public URL assigned` line in the output:
```
2026/04/14 13:30:16 Public URL assigned: service=frontend url=https://oval-peacock-connects.proxy.clode.space
2026/04/14 13:30:16 Public URL assigned: service=api url=https://lean-kite-carves.proxy.clode.space
```

Wait until URLs for **all** expected public services have appeared, then collect them all:

```bash
# Set PUBLIC_SERVICES to the comma-separated names you passed to --public
PUBLIC_SERVICES="frontend,api"
EXPECTED_COUNT=$(echo "$PUBLIC_SERVICES" | tr ',' '\n' | wc -l)

timeout=30
elapsed=0

while [ $elapsed -lt $timeout ]; do
  FOUND=$(grep -oE 'Public URL assigned: service=[^ ]+ url=https://[a-z0-9-]+\.proxy\.clode\.space' \
    "$EXPOSE_LOG" 2>/dev/null | wc -l)
  [ "$FOUND" -ge "$EXPECTED_COUNT" ] && break
  sleep 2
  elapsed=$((elapsed + 2))
done

if [ "$FOUND" -lt "$EXPECTED_COUNT" ]; then
  echo "ERROR: Only got $FOUND/$EXPECTED_COUNT URLs after ${timeout}s"
  cat "$EXPOSE_LOG"
  kill $EXPOSE_PID 2>/dev/null
  exit 1
fi

# Extract all service→URL pairs
grep -oE 'Public URL assigned: service=[^ ]+ url=https://[a-z0-9-]+\.proxy\.clode\.space' "$EXPOSE_LOG" \
  | while read -r line; do
      SVC=$(echo "$line" | grep -oE 'service=[^ ]+' | cut -d= -f2)
      URL=$(echo "$line" | grep -oE 'https://[a-z0-9-]+\.proxy\.clode\.space')
      echo "$SVC → $URL"
    done
```

Store each URL in a variable by service name for use in Steps 5 and 6:
```bash
FRONTEND_URL=$(grep 'service=frontend' "$EXPOSE_LOG" | grep -oE 'https://[a-z0-9-]+\.proxy\.clode\.space' | head -1)
API_URL=$(grep 'service=api' "$EXPOSE_LOG" | grep -oE 'https://[a-z0-9-]+\.proxy\.clode\.space' | head -1)
```

### Step 5 — Verify each public URL

Run this for every public URL. Retry up to 3 times with 10s intervals.

```bash
verify_url() {
  local URL="$1"
  local LABEL="$2"
  for attempt in 1 2 3; do
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
    if echo "$HTTP_STATUS" | grep -qE "^(200|301|302)$"; then
      echo "✅ $LABEL verified (attempt $attempt): $URL (HTTP $HTTP_STATUS)"
      return 0
    fi
    echo "⏳ $LABEL attempt $attempt: HTTP $HTTP_STATUS — retrying in 10s..."
    [ $attempt -lt 3 ] && sleep 10
  done
  echo "❌ $LABEL failed verification after 3 attempts: $URL"
  return 1
}

verify_url "$FRONTEND_URL" "frontend"
verify_url "$API_URL" "api"
```

### Step 6 — Report all URLs

Surface the primary frontend URL as a URL-kind artifact on your task close (in-task) or on a `aramb_chat.deliver_artifacts` call (solo). Brahmi auto-registers the preview-URL state. Secondary backend / API URLs go in the inline reply text alongside.

```bash
# In a task: chip + status close + preview state in ONE call
npx mcporter call aramb_tasks.update_me status="done" \
  summary="✅ Tunnels live (PID: $EXPOSE_PID):
- frontend: $FRONTEND_URL
- api: $API_URL" \
  artifacts='[{"kind":"url","url":"'"$FRONTEND_URL"'","title":"Preview URL","environment":"deployed"}]'

# Solo / mid-task recall: same artifact shape via aramb_chat.deliver_artifacts
npx mcporter call aramb_chat.deliver_artifacts \
  artifacts='[{"kind":"url","url":"'"$FRONTEND_URL"'","title":"Preview URL","environment":"deployed"}]' \
  summary="✅ Tunnels live (PID: $EXPOSE_PID):
- frontend: $FRONTEND_URL
- api: $API_URL"
```

Rules for preview URLs:
- The rule fires whenever this skill produced any URL the user can reach (frontend, API, tunnel, public proxy).
- A URL-kind artifact on `aramb_tasks.update_me.artifacts` (in-task) or `aramb_chat.deliver_artifacts.artifacts` (solo) is mandatory for the primary frontend URL.
- Mentioning the URL only in chat prose is forbidden — the chip pipeline cannot reconstruct chips from prose after the fact.
- For aramb-expose tunnels the `environment` field is `"deployed"` (the URL is a public proxy.clode.space hostname reachable outside the agent's container).
- The chip is for the *primary* frontend URL only. Secondary backend / API URLs can stay in the `summary` text — one chip per chat row is plenty.

---

## Cleanup

**Do NOT kill the tunnel on task completion.** Keep the process running — the user needs the URL to stay live.

Only clean up when explicitly superseded by a new deployment:

```bash
kill $EXPOSE_PID 2>/dev/null
wait $EXPOSE_PID 2>/dev/null
rm -f "$EXPOSE_LOG"
```

To delete a named client from the registry entirely (not usually needed — reuse is preferred):
```bash
aramb expose delete <app-slug>
```

---

## Safety Rules

- **Never expose database ports** (5432, 3306, 27017, 6379, etc.) — only frontend/API services
- **Never expose admin interfaces** unless explicitly requested
- **Prefer the frontend service** identified by the frontend-detection skill as the primary public target
- **One named client per app** — reuse across deployments rather than creating new ones each time
- Tunnel URLs are ephemeral — they change each time `aramb expose run` is restarted
