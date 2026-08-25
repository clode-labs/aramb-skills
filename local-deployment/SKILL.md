---
name: local-deployment
description: >
  Full local deployment protocol — expose ALL HTTP services (frontend + backends) via aramb
  expose FIRST to collect public URLs, inject those URLs as runtime env var overrides into
  docker compose (no file edits), then start the stack. Deliverable: verified public URLs for
  every exposed service, with inter-service URLs wired so the browser-side frontend hits the
  exposed backend. Use when: deploying an application locally for preview or end-to-end
  validation. NOT for: production deployments, code development, or testing.
---

# Local Deployment

## Overview

This skill covers the complete workflow for deploying an application locally and exposing all HTTP services via aramb expose tunnels.

**The local deployer never edits any files.** It reads the project to understand the stack, exposes services, and injects public URLs as runtime environment variable overrides when starting docker compose. Whether the app correctly consumes those env vars (for API URLs, CORS origins, etc.) is the developer's responsibility — the deployer wires what's already there.

**Critical order of operations:**

```
1. Read the stack (docker-compose.yml) — read only
2. Detect ALL HTTP services to expose (frontend + backend APIs)
3. Run aramb expose FIRST → collect all public URLs
   (services don't need to be running yet — tunnel assigns URLs immediately)
4. Build env var overrides from the public URLs
5. Start docker compose with those env vars injected at runtime
6. Wait for healthy
7. Verify all public URLs
8. Report — deliver primary URL as a URL-kind artifact (chip)
9. Offer cloud deployment via ask_question (separate row, options as buttons)
```

Why expose first: the tunnel infrastructure assigns public URLs regardless of whether local services are up. Starting the tunnel before `docker compose up` gives you the real public URLs to inject as env vars, so every container boots with the correct inter-service addresses from the first start.

---

## Step 1: Read the Stack

Read `docker-compose.yml` and understand:
- All services, their ports, and their build contexts
- Any existing `environment:` sections and what env vars each service already reads
- Which services are frontend, backend/API, or infrastructure (databases, queues)

```bash
cat docker-compose.yml
```

Pay particular attention to env var references like `${VITE_API_URL}`, `${NEXT_PUBLIC_API_URL}`, `${ALLOWED_ORIGINS}`, `${CORS_ORIGIN}` — these are the injection points you'll use in Step 4. Note them down.

---

## Step 2: Detect ALL Services to Expose

### Frontend Detection

Check in order of reliability:

```bash
# Service name patterns
docker compose config --services | grep -iE "^(web|frontend|client|ui|app|next|nuxt|vite)$|react|vue|angular|svelte"

# Dockerfile content signals
for service in $(docker compose config --services); do
  context=$(docker compose config | yq ".services.${service}.build.context // \".\"")
  dockerfile=$(docker compose config | yq ".services.${service}.build.dockerfile // \"Dockerfile\"")
  if [ -f "${context}/${dockerfile}" ]; then
    grep -qiE "npm run build|yarn build|vite|next|nuxt|webpack|react-scripts|nginx|serve|http-server|caddy" \
      "${context}/${dockerfile}" && echo "FRONTEND CANDIDATE: $service"
  fi
done

# Port signals (when name/Dockerfile signals are ambiguous)
# 3000 = React/Next.js, 5173/5174 = Vite, 8080 = Vue CLI, 4200 = Angular, 80/443 = Nginx
docker compose config | yq '.services | to_entries[] | select(.value.ports) | .key + ": " + (.value.ports | join(", "))'
```

### Backend/API Detection

Look for services that are NOT the frontend and NOT a database/cache:

```bash
for service in $(docker compose config --services); do
  image=$(docker compose config | yq ".services.${service}.image // \"\"")
  # Skip known databases
  echo "$image" | grep -qiE "postgres|mysql|mariadb|redis|mongo|elasticsearch|cassandra|rabbitmq|kafka" && continue
  # Check for backend signals in Dockerfile
  context=$(docker compose config | yq ".services.${service}.build.context // \".\"")
  dockerfile=$(docker compose config | yq ".services.${service}.build.dockerfile // \"Dockerfile\"")
  if [ -f "${context}/${dockerfile}" ]; then
    grep -qiE "uvicorn|gunicorn|flask|django|express|fastify|gin|echo|fiber|rails|spring|dotnet|cargo run|bun run|deno run" \
      "${context}/${dockerfile}" && echo "BACKEND CANDIDATE: $service"
  fi
done
```

**Never expose:** databases (Postgres, MySQL, Redis, Mongo), message queues, or admin interfaces.

### Service Inventory

Before proceeding, establish:

```
FRONTEND_SERVICE=<service-name>
FRONTEND_PORT=<host-port>

BACKEND_SERVICES=(<service1> <service2> ...)  # array — may be empty
BACKEND_PORTS=(<port1> <port2> ...)           # matching array
```

---

## Step 3: Run Aramb Expose FIRST

Expose all HTTP services before starting the stack. URLs are assigned by the tunnel infrastructure immediately — no local service needs to be running.

### 3a — Build the services and public lists

```bash
APP_SLUG="<app-slug>"   # from the platform task context

# Always include the frontend
SERVICES_ARG="frontend=http://localhost:${FRONTEND_PORT}"
PUBLIC_ARG="frontend"

# Add each backend
for i in "${!BACKEND_SERVICES[@]}"; do
  svc="${BACKEND_SERVICES[$i]}"
  port="${BACKEND_PORTS[$i]}"
  SERVICES_ARG="${SERVICES_ARG},${svc}=http://localhost:${port}"
  PUBLIC_ARG="${PUBLIC_ARG},${svc}"
done
```

### 3b — Create or update the named client

```bash
EXISTING=$(aramb expose list -o json 2>/dev/null \
  | jq -r --arg name "$APP_SLUG" '.[] | select(.name == $name) | .name' 2>/dev/null)

if [ -z "$EXISTING" ]; then
  aramb expose create \
    --name "$APP_SLUG" \
    --services "$SERVICES_ARG" \
    --public "$PUBLIC_ARG"
else
  # Always pass full desired state on update
  aramb expose update "$APP_SLUG" \
    --services "$SERVICES_ARG" \
    --public "$PUBLIC_ARG"
fi
```

### 3c — Run the tunnel and collect all public URLs

```bash
EXPOSE_LOG="/tmp/aramb-expose-${APP_SLUG}.log"

aramb expose run "$APP_SLUG" > "$EXPOSE_LOG" 2>&1 &
EXPOSE_PID=$!

echo "Tunnel started (PID: $EXPOSE_PID) — waiting for public URLs..."

EXPECTED_COUNT=$(echo "$PUBLIC_ARG" | tr ',' '\n' | wc -l)
timeout=30
elapsed=0

while [ $elapsed -lt $timeout ]; do
  FOUND=$(grep -c 'Public URL assigned' "$EXPOSE_LOG" 2>/dev/null || echo 0)
  [ "$FOUND" -ge "$EXPECTED_COUNT" ] && break
  sleep 2
  elapsed=$((elapsed + 2))
done

if [ "$FOUND" -lt "$EXPECTED_COUNT" ]; then
  echo "ERROR: Only $FOUND/$EXPECTED_COUNT URLs appeared after ${timeout}s"
  cat "$EXPOSE_LOG"
  kill $EXPOSE_PID 2>/dev/null
  exit 1
fi

# Extract public URLs
FRONTEND_URL=$(grep 'service=frontend' "$EXPOSE_LOG" \
  | grep -oE 'https://[a-z0-9-]+\.proxy\.clode\.space' | head -1)

for svc in "${BACKEND_SERVICES[@]}"; do
  url=$(grep "service=${svc}" "$EXPOSE_LOG" \
    | grep -oE 'https://[a-z0-9-]+\.proxy\.clode\.space' | head -1)
  eval "BACKEND_URL_$(echo "$svc" | tr '-' '_')=${url}"
  echo "  ${svc} → ${url}"
done

echo "  frontend → $FRONTEND_URL"
```

---

## Step 4: Build Env Var Overrides

Read the `environment:` sections of docker-compose.yml to find which env vars each service already supports. Match those to the public URLs collected in Step 3. Do NOT edit any files — pass these as runtime overrides only.

### Mapping logic

Read the compose file to find env var names the services already reference:

```bash
# Find frontend env vars that reference API/backend URLs
docker compose config | yq ".services.${FRONTEND_SERVICE}.environment // []"
# Look for: VITE_API_URL, NEXT_PUBLIC_API_URL, REACT_APP_API_URL, API_URL, BACKEND_URL, etc.

# Find backend env vars that reference CORS origins
for svc in "${BACKEND_SERVICES[@]}"; do
  docker compose config | yq ".services.${svc}.environment // []"
  # Look for: ALLOWED_ORIGINS, CORS_ORIGIN, CORS_ORIGINS, CORS_ALLOWED_ORIGINS, etc.
done
```

Build a set of env var overrides:

```bash
# Example — adjust var names to match what the compose file actually uses
DEPLOY_ENV=(
  "VITE_API_URL=${BACKEND_URL_api}"         # frontend → backend public URL
  "NEXT_PUBLIC_API_URL=${BACKEND_URL_api}"  # Next.js variant
  "REACT_APP_API_URL=${BACKEND_URL_api}"    # CRA variant
  "ALLOWED_ORIGINS=${FRONTEND_URL}"         # backend CORS → frontend public URL
  "CORS_ORIGIN=${FRONTEND_URL}"             # alternate CORS env var name
)
```

Only include env vars that the compose file (or service Dockerfiles) already reference. Do not invent new ones — they won't be consumed.

### Write to temp env file (NOT in the codebase)

```bash
DEPLOY_ENV_FILE="/tmp/deploy-${APP_SLUG}.env"

# Clear and write
> "$DEPLOY_ENV_FILE"
for pair in "${DEPLOY_ENV[@]}"; do
  echo "$pair" >> "$DEPLOY_ENV_FILE"
done

echo "Env overrides written to $DEPLOY_ENV_FILE:"
cat "$DEPLOY_ENV_FILE"
```

This file is in `/tmp/` — it never touches the project directory.

---

## Step 5: Start the Stack

Start docker compose with the env file injected. Docker compose uses this file for variable substitution in the YAML AND, for env vars listed without a value in `environment:` sections, inherits from the env file.

```bash
docker compose --env-file "$DEPLOY_ENV_FILE" up -d --build
```

Wait for ALL services to be healthy:

```bash
timeout=180
elapsed=0
while [ $elapsed -lt $timeout ]; do
  unhealthy=$(docker compose ps --format json \
    | jq -r 'select(.Health == "starting" or .State != "running") | .Service' 2>/dev/null)
  if [ -z "$unhealthy" ]; then
    echo "All services healthy"
    break
  fi
  echo "Waiting for: $unhealthy"
  sleep 5
  elapsed=$((elapsed + 5))
done

if [ $elapsed -ge $timeout ]; then
  echo "TIMEOUT: Services not healthy after ${timeout}s"
  docker compose logs --tail=50
fi
```

Verify the frontend responds locally:

```bash
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${FRONTEND_PORT}")
if ! echo "$HTTP_STATUS" | grep -qE "^(200|301|302)$"; then
  echo "ERROR: Frontend not responding locally (HTTP $HTTP_STATUS)"
  docker compose logs "${FRONTEND_SERVICE}" --tail=30
fi
```

---

## Step 6: Verify ALL Public URLs

**MANDATORY: Verify every public URL — not just the frontend. Never report an unverified URL.**

The tunnel was running since Step 3. Now that the stack is up, verify each URL serves real application content (not a gateway error page — those can return HTTP 200 with error HTML).

```bash
verify_url() {
  local URL="$1"
  local LABEL="$2"
  local verified=false

  for attempt in 1 2 3 4 5; do
    RESPONSE=$(curl -s -L --max-time 15 -w "\n%{http_code}" "$URL")
    HTTP_STATUS=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    # Gateway/proxy errors — retry
    if echo "$HTTP_STATUS" | grep -qE "^(502|503|520|521|522|523|524|530)$"; then
      echo "[$LABEL] Attempt $attempt: HTTP $HTTP_STATUS — retrying in 10s"
      sleep 10
      continue
    fi

    # Successful status — verify body has real content
    if echo "$HTTP_STATUS" | grep -qE "^(200|301|302|304)$"; then
      BODY_LENGTH=$(echo "$BODY" | wc -c | tr -d ' ')
      if [ "$BODY_LENGTH" -gt 100 ]; then
        echo "[$LABEL] VERIFIED: $URL (HTTP $HTTP_STATUS, ${BODY_LENGTH} bytes)"
        verified=true
        break
      else
        echo "[$LABEL] Attempt $attempt: HTTP $HTTP_STATUS but body too small — retrying"
        sleep 10
        continue
      fi
    fi

    echo "[$LABEL] Attempt $attempt: HTTP $HTTP_STATUS — retrying in 10s"
    sleep 10
  done

  if [ "$verified" = false ]; then
    echo "[$LABEL] FAILED: $URL not serving real content after 5 attempts"
    echo "  Last HTTP status: $HTTP_STATUS"
    echo "  Tunnel: $(kill -0 $EXPOSE_PID 2>/dev/null && echo "running" || echo "DEAD")"
    echo "  Expose log tail:"
    tail -20 "$EXPOSE_LOG"
    return 1
  fi
}

verify_url "$FRONTEND_URL" "frontend"

for svc in "${BACKEND_SERVICES[@]}"; do
  url_var="BACKEND_URL_$(echo "$svc" | tr '-' '_')"
  verify_url "${!url_var}" "$svc"
done
```

---

## Step 7: Diagnose If Verification Fails

**Do not escalate immediately — diagnose first.**

### "Blocked request" / Host check error (Vite, webpack)

The framework is rejecting the `*.proxy.clode.space` Host header. This is a code-level configuration problem. The local deployer cannot fix it — escalate to the developer agent with:

```
Frontend host check is blocking proxy.clode.space requests.
Fix needed: add allowedHosts: ['.proxy.clode.space'] to vite.config.ts (or equivalent for the framework).
```

### Frontend API calls fail / CORS error in browser

The frontend is calling `localhost` or a Docker-internal hostname instead of the exposed backend URL. Diagnose:

1. Check what API URL the frontend is actually using (look in browser network tab or frontend logs)
2. Check if the compose file has an env var for the API URL that the `--env-file` should have set
3. If the env var isn't referenced in the compose file, the app isn't set up for env-driven API URLs — escalate to the developer agent

### Backend returns "Origin not allowed"

The backend CORS config doesn't allow the frontend's public domain. Check if the compose file has an `ALLOWED_ORIGINS` (or equivalent) env var that the `--env-file` should have set. If not, escalate to the developer agent.

### 502 Bad Gateway

Service hasn't started or crashed. Check:
```bash
docker compose ps
docker compose logs <service> --tail=30
```

---

## Step 8: Report

Once ALL URLs are verified, surface the primary frontend URL as a URL-kind artifact. Which tool depends on the dispatch context:

### Team mode — closing a task

The chip emit, preview-URL state registration, and task close all happen in ONE call.

```
npx mcporter call aramb_mcp.tasks_update project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="done" \
  summary="✅ App live (tunnel PID: $EXPOSE_PID):
- frontend: $FRONTEND_URL
- api: $API_URL (if applicable)
Env overrides injected: $DEPLOY_ENV_FILE" \
  artifacts='[{"kind":"url","url":"'"$FRONTEND_URL"'","title":"Preview URL","environment":"deployed"}]'
```

### Solo mode / no task to close

When the deploy was kicked off directly in a chat (no `task_id` in your `## Current Context`), use `aramb_mcp.chat_deliver_artifacts` — same artifact shape, no task transition. The platform still auto-registers the preview-URL state from the URL-kind entry.

```
npx mcporter call aramb_mcp.chat_deliver_artifacts \
  project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" \
  artifacts='[{"kind":"url","url":"'"$FRONTEND_URL"'","title":"Preview URL","environment":"deployed"}]' \
  summary="✅ App live: $FRONTEND_URL (api: $API_URL if applicable)"
```

### Rules for preview URLs (apply to both paths above)

- The rule fires whenever this skill produced any URL the user can reach (frontend, API, tunnel, public proxy).
- A URL-kind artifact is **mandatory** for the primary frontend URL — on `aramb_mcp.tasks_update.artifacts` in team mode, or on `aramb_mcp.chat_deliver_artifacts.artifacts` in solo mode. The platform auto-registers preview-URL state from it — no separate call.
- Mentioning the URL only in chat prose is forbidden — the chip pipeline cannot reconstruct chips from prose after the fact, and the workbench browser/preview tab won't open from prose.
- For aramb-expose tunnels the `environment` field is `"deployed"` (the URL is a public proxy.clode.space hostname reachable outside the agent's container).
- The chip is for the *primary* frontend URL only. Secondary backend / API URLs can stay in the `summary` text — one URL chip per chat row is plenty.

---

## Step 9: Offer cloud deployment

After the local URL artifact is delivered (Step 8), ask the user whether they also want a cloud deployment. **Always a separate call** — the URL belongs on its own chip in the previous chat row, and the question is a fresh row underneath it with action buttons. Do NOT embed the URL inside the question text — the chip pipeline cannot reconstruct it from prose, and Slack will render a duplicate link instead of a clean preview.

```bash
npx mcporter call aramb_mcp.chat_ask_question \
  project_id="<PROJECT_ID>" \
  application_id="<APPLICATION_ID>" \
  question="Want me to deploy this to cloud as well? Local tunnel URLs die when the tunnel restarts; a cloud deployment is durable." \
  options='["Yes, deploy to cloud","Not now","Skip — I will deploy myself"]'
```

Rules:
- **One question per deployment** — fire this exactly once, immediately after the Step 8 artifact call. Do not re-prompt on the same deploy.
- **Options stay in the `options` array**, not in the question prose. The Slack/web renderer turns each option into a button (the chat toolkit's `QuestionBlocks` emits one button per option; any N up to ~5 renders cleanly).
- **`chat_location` is forced to `"main"`** by the platform for every `ask_question` call — the question always surfaces in the user's main chat, even if you were dispatched from inside a task. The `task_id` (if any) is auto-carried via question metadata so the answer routes back into your session.
- **Blocking** — the run pauses until the user picks. The answer arrives as your next dispatch with the user's selection; do not poll.
- **If the user picks the "Yes…" option**, hand off to the cloud-deploy skill with the same app slug. If they pick "Not now" or "Skip", end the session — do NOT kill the local tunnel (see "Keep the tunnel alive" below).

---

## Rules

### The local deployer NEVER edits files

- Does NOT edit `vite.config.ts`, `next.config.js`, `webpack.config.js`
- Does NOT edit `docker-compose.yml` or any compose override file
- Does NOT edit `.env`, `.env.local`, or any project env file
- Does NOT edit application source code, CORS configs, or API URL constants
- Does NOT write any file into the project directory

It only reads files and writes to `/tmp/`.

If the app is not configured for env-driven API URLs or CORS, the local deployer reports what's missing and escalates to the developer agent. It does not attempt fixes.

### Never expose databases

Never expose ports 5432, 3306, 27017, 6379, or any database/cache service.

### One named client per app

Reuse the named client across deployments. Update it rather than creating a new one.

### Tunnel URLs change on restart

Each `aramb expose run` restart produces new URLs. Update the `DEPLOY_ENV_FILE` and restart the stack with the new URLs if the tunnel dies.

### Keep the tunnel alive

**Do NOT kill the tunnel or tear down the stack on task completion.** The user needs the URLs to stay live.

---

## Cleanup (only when explicitly superseded)

```bash
kill $EXPOSE_PID 2>/dev/null
wait $EXPOSE_PID 2>/dev/null
rm -f "$EXPOSE_LOG" "$DEPLOY_ENV_FILE"
docker compose down -v
```

Named clients persist — do not delete them unless explicitly asked:
```bash
aramb expose delete "$APP_SLUG"
```
