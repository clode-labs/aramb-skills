---
name: aramb-deployment
description: Build and deploy applications using aramb-cli. Covers aramb-cli installation, deployment mode detection, env var/secret filling, service creation, local Docker builds, and deployment orchestration. Use for all deployment tasks. TOML generation is handled by the aramb-toml skill.
---

# Aramb Deployment

Build and deploy applications using the `aramb` CLI. **Follow this workflow exactly. Do NOT improvise. Do NOT debug the CLI, the registry, the build host, or networking.** If any step fails, EXIT immediately with a clear error message.

The fixed flow is:

```
generate TOML → fill secrets → services create --from-toml
              → build --push for local-built services (all type="frontend"; in no-git mode also type="backend") → update TOML
              → deploy --from-toml --yes → poll deploy status → done
```

`services create --from-toml` resolves/creates services only — it does NOT push configuration.
`deploy --from-toml --yes` pushes the merged configuration AND triggers the deployment in one step.

---

## Session Continuity

Your session persists. You may be started fresh OR resumed with new context.

### Trigger Types

| Trigger | Meaning |
|---------|---------|
| `start` | Normal task execution (first time) |
| `resume` | User provided additional context |
| `task_chat` | Direct message from task chat UI |

### Resume Handling

When resumed, you receive:
```
## Task Resumed
The user has provided additional context:
<user's message>
Your previous status: <completed/failed>
```

| Previous Status | User Intent | Action |
|-----------------|-------------|--------|
| `failed` | Providing fix info | Retry with new context |
| `completed` | Wants redeployment | Redeploy or update |
| `completed` | Asking question | Answer from your context |
| `in_progress` | Adding context | Incorporate and continue |

### Q&A Mode

If resumed with `mode="qa"`:
- Only answer questions from your existing context
- Do NOT perform new deployments
- Use `TaskChatResponse` to reply

---

## Required Environment Variables

- `ARAMB_API_TOKEN` — Authentication for all aramb operations (also authenticates against the built-in registry)
- `JUMBO_URL` — Jumbo platform URL (base URL only, e.g., `http://jumbo:8080`)
- `APPLICATION_ID` — Application identifier; passed to the aramb-toml skill and used in all service definitions
- `BUILDKIT_HOST` — *Optional.* Remote BuildKit endpoint. When unset (or unreachable), `aramb build` falls back to `docker build` against the local Docker daemon. The aramb CLI runs in a docker-in-docker environment, so this fallback is the expected path.

The CLI's built-in registry is `registry.clode.space`. It is **private** and authenticates automatically through `ARAMB_API_TOKEN` during `aramb build --push`. Do NOT probe, curl, `docker pull`, or otherwise inspect this registry directly — anonymous requests are rejected and tell you nothing about the build.

Validate before starting:

```bash
[ -n "$ARAMB_API_TOKEN" ] || { echo "ERROR: ARAMB_API_TOKEN not set"; exit 1; }
[ -n "$JUMBO_URL" ] || { echo "ERROR: JUMBO_URL not set"; exit 1; }
[ -n "$APPLICATION_ID" ] || { echo "ERROR: APPLICATION_ID not set"; exit 1; }
```

---

## Step 0: Install aramb-cli

If aramb-cli is not installed, install it. If installation fails, EXIT immediately. Do NOT debug.

```bash
if ! command -v aramb &> /dev/null; then
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m)
  [ "$ARCH" = "x86_64" ] && ARCH="amd64"
  [ "$ARCH" = "aarch64" ] && ARCH="arm64"
  BINARY="aramb-${OS}-${ARCH}"
  curl -LO "https://github.com/aramb-ai/release-beta/releases/latest/download/${BINARY}" || { echo "ERROR: Download failed"; exit 1; }
  chmod +x "${BINARY}"
  sudo mv "${BINARY}" /usr/local/bin/aramb || { echo "ERROR: Install failed"; exit 1; }
fi
```

---

## Deployment Mode Detection

```bash
if git remote get-url origin &> /dev/null 2>&1; then
  DEPLOY_MODE="git"
  REPO_URL=$(git remote get-url origin)
else
  DEPLOY_MODE="no-git"
  REPO_URL=""
fi
```

```
DEPLOY_MODE=git   → Path A: Git-Connected Deployment
DEPLOY_MODE=no-git → Path B: No-Git Local Build Deployment
```

---

## Path A: Git-Connected Deployment

### Step 1: Generate aramb.toml

Invoke the **aramb-toml** skill with:
- `mode = "git"`
- `repoUrl = $REPO_URL`

The skill writes `aramb.toml` with build + runtime service pairs for own-codebase services. Do NOT write TOML yourself — delegate entirely to the skill.

---

### Step 2: Fill Env Vars and Secrets

**Internal values** — fill yourself in aramb.toml before deploying:
- DB credentials (username, DB name, port)
- JWT secrets, session secrets
- Service-to-service URLs via `${uniqueIdentifier.outputs.PRIVATE_URL}`

**External values** — ask the user before continuing:
- Third-party API keys (Stripe, SendGrid, Twilio, etc.)
- OAuth client secrets
- External service URLs not resolvable at deploy time

---

### Step 3: Create Services from TOML

This resolves project/application/service references and creates any missing services. It does NOT push configuration — that happens in Step 5.

```bash
aramb services create --from-toml || { echo "ERROR: Service creation failed"; exit 1; }
```

After this step the TOML has actual `slug` and `id` values written back for each service. Use those slugs in Step 4.

---

### Step 4: Build and Push Static Frontends Locally

`type="frontend"` services build their static assets locally and push them as an OCI artifact. This runs even in git mode so the static build path is taken regardless of any Dockerfile in the frontend directory (Dockerfiles are kept for local docker-compose previews).

For each `type="frontend"` service in aramb.toml, read its `slug` and `staticPath`, then build:

```bash
IMAGE_URL=$(aramb build {BUILD_PATH} --static-outdir {STATIC_PATH} --service {SERVICE_SLUG} --push \
  | jq -r '.IMAGE_URL') || { echo "ERROR: Frontend build failed for {SERVICE_SLUG}"; exit 1; }
```

Where:
- `{BUILD_PATH}` — the frontend source directory (`./frontend`, `./web`, `.`, etc.)
- `{STATIC_PATH}` — the build output directory matching `staticPath` in the TOML (`./frontend/dist`, `./frontend/build`, etc.)
- `{SERVICE_SLUG}` — the `slug` of the `type="frontend"` runtime service

Replace its `image = ""` placeholder using the slug to scope the replacement:

```bash
sed -i "/slug = \"${SERVICE_SLUG}\"/,/\[\[/ s|image = \"\"|image = \"${IMAGE_URL}\"|" aramb.toml
```

Backend services (`type="backend"`, including SSR frontends like Next.js / Nuxt / SvelteKit) are built and deployed by the platform from `repoUrl` + `buildPath` — no local build step is needed for them in git mode.

---

### Step 5: Deploy All Services from TOML

This merges and pushes the configuration AND triggers deployment in a single call.

```bash
aramb deploy --from-toml --yes || { echo "ERROR: Deploy failed"; exit 1; }
```

---

### Step 6: Poll Deploy Status

**The only source of truth for "is the deployment done" is `aramb deploy status`.** Do NOT use `aramb logs`, `aramb services logs`, `aramb logs history`, `curl`, `wget`, `docker logs`, or any other tool to determine deployment health. They are not part of this flow.

```bash
SERVICE_SLUGS=$(aramb services list --application "$APPLICATION_ID" --output json \
  | jq -r '.[] | select(.type != "build") | .slug')

declare -A URLS
for SERVICE_SLUG in $SERVICE_SLUGS; do
  echo "Waiting for $SERVICE_SLUG..."
  aramb deploy status --service "$SERVICE_SLUG" --loop --interval 5

  RESULT=$(aramb deploy status --service "$SERVICE_SLUG" --output json)
  STATUS=$(echo "$RESULT" | jq -r '.status')

  if [ "$STATUS" = "completed" ]; then
    PUBLIC_URL=$(echo "$RESULT" | jq -r '.outputs.PUBLIC_URL // empty')
    [ -n "$PUBLIC_URL" ] && URLS[$SERVICE_SLUG]="$PUBLIC_URL" && echo "$SERVICE_SLUG live at: $PUBLIC_URL"
  else
    echo "ERROR: $SERVICE_SLUG deploy status: $STATUS"
    exit 1
  fi
done
```

`--loop --interval 5` blocks until the deployment reaches a terminal state. The follow-up `--output json` call reads the final state. Nothing else is needed — no log polling, no HTTP probes.

Set structured outputs before completing (CRITICAL — planner uses these to answer questions without resuming you):

```json
{
  "status": "success",
  "deploy_mode": "git",
  "backend": {
    "public_url": "https://backend-api.aramb.dev",
    "private_url": "http://backend-api:8080",
    "service_slug": "backend-api",
    "status": "completed"
  },
  "frontend": {
    "url": "https://frontend-web.aramb.dev",
    "service_slug": "frontend-web",
    "status": "completed"
  },
  "application_id": "$APPLICATION_ID",
  "services_deployed": ["postgres-db", "backend-api", "frontend-web"],
  "all_completed": true
}
```

---

## Path B: No-Git Local Build Deployment

Use when the project directory has no remote git repository. Services are created from TOML, images are built and pushed locally, then the TOML is updated with image URLs and deployed.

### Step 1: Generate aramb.toml

Invoke the **aramb-toml** skill with `mode = "no-git"`. The skill writes `aramb.toml` with runtime-only services (no `[[services]]` of `type=build`) and `image = ""` placeholders for own-codebase services.

---

### Step 2: Fill Env Vars and Secrets

Same as Path A Step 2.

---

### Step 3: Create Services from TOML

```bash
aramb services create --from-toml || { echo "ERROR: Service creation failed"; exit 1; }
```

After this step the TOML has actual `slug` and `id` values written back for each service. Use those slugs in Step 4 — do not invent slugs or use names.

---

### Step 4: Build and Push Images Locally

Always use `--push`. The CLI's built-in registry handles authentication automatically through `ARAMB_API_TOKEN`. There is no separate registry login step.

The CLI picks its build backend automatically:
- If `BUILDKIT_HOST` is set and reachable → BuildKit
- Otherwise → falls back to `docker build` against the local Docker daemon (the expected path in the docker-in-docker environment)

You do not need to set, check, or probe `BUILDKIT_HOST`. Just run `aramb build`.

The build invocation depends on the runtime service type. Iterate over every own-codebase service in aramb.toml (those with `image = ""`) and pick the matching command. Services that already have a non-empty image (postgres, redis, public-image services) are skipped.

**For `type="backend"` (and SSR frontends typed as backend — Next.js, Nuxt, SvelteKit, plus any service with a Dockerfile):**

```bash
IMAGE_URL=$(aramb build {BUILD_PATH} --service {SERVICE_SLUG} --push \
  | jq -r '.IMAGE_URL') || { echo "ERROR: Build failed for {SERVICE_SLUG}"; exit 1; }
```

**For `type="frontend"` (static SPAs — React/Vite, CRA, Angular, plain HTML):**

```bash
IMAGE_URL=$(aramb build {BUILD_PATH} --static-outdir {STATIC_PATH} --service {SERVICE_SLUG} --push \
  | jq -r '.IMAGE_URL') || { echo "ERROR: Frontend build failed for {SERVICE_SLUG}"; exit 1; }
```

`--static-outdir` instructs the CLI to take the static-build path: run the framework build, archive the output directory as a `static.tgz` OCI artifact (files under a `static/` prefix), and push it to the registry. This path is taken regardless of any Dockerfile present in the build path, so local docker-compose previews keep their Dockerfile untouched.

Where:
- `{BUILD_PATH}` — the local source directory for this service (`./backend`, `./frontend`, `./services/auth-service`, etc.)
- `{STATIC_PATH}` — for frontend services, the framework's build output directory (`./frontend/dist` for Vite, `./frontend/build` for CRA, `./frontend/.next` for static-export Next.js, etc.); this matches the `staticPath` field in aramb.toml
- `{SERVICE_SLUG}` — the `slug` field written into aramb.toml by `services create --from-toml` for the runtime service

**If `aramb build` fails → EXIT.** Log the slug and path and exit with the CLI's error message verbatim.

---

### Step 5: Update aramb.toml with Built Image URLs

For each service built in Step 4, replace its `image = ""` placeholder using the slug to scope the replacement:

```bash
SERVICE_SLUG={slug from aramb.toml}
IMAGE_URL={IMAGE_URL from aramb build output}

sed -i "/slug = \"${SERVICE_SLUG}\"/,/\[\[/ s|image = \"\"|image = \"${IMAGE_URL}\"|" aramb.toml
```

After all services are updated, verify no placeholders remain:

```bash
grep 'image = ""' aramb.toml && { echo "ERROR: Some service images not updated"; exit 1; } || true
```

---

### Step 6: Deploy All Services from TOML

```bash
aramb deploy --from-toml --yes || { echo "ERROR: Deploy failed"; exit 1; }
```

---

### Step 7: Poll Deploy Status

Same as Path A Step 6 — use `aramb deploy status --loop` and `--output json`, nothing else.

Same output format as Path A. Set `"deploy_mode": "no-git"` and include a `"build"` object:

```json
"build": {
  "mode": "local",
  "images_built": 2,
  "backend_image": "...",
  "frontend_image": "..."
}
```

---

## Forbidden Actions

Past task traces show agents wasting 30–80 tool calls on the items below. **Do not do any of these.** If you find yourself reaching for them, you are deviating from the flow — EXIT instead.

| Don't do this | Why |
|---|---|
| Probe `registry.clode.space` via `curl`, `docker pull`, `docker login`, etc. | It is a private registry. Anonymous access is rejected. `aramb build --push` handles auth. |
| Set `BUILDKIT_HOST` yourself via `docker inspect buildkitd`, DNS lookups, `/etc/hosts` parsing | Not needed. `aramb build` falls back to `docker build` automatically. |
| Start the Docker daemon (`sudo dockerd`, `systemctl start docker`, etc.) | The DinD environment manages this. If Docker is unavailable, EXIT — not yours to fix. |
| Use `aramb services create -n NAME -t TYPE -p ... -a ...` (without `--from-toml`) | Creates orphan services that won't match the TOML. Always use `--from-toml`. |
| `cd /tmp` before running `aramb` commands | The workspace directory contains `aramb.toml`. Stay there. |
| Run `aramb logs`, `aramb services logs`, `aramb logs history` | None of these are part of the deployment flow. `aramb deploy status` is the only check. |
| `curl`/`wget` public URLs to verify the deployment | A non-2xx response is not your signal. `deploy status: completed` is authoritative. |
| Debug TOML schema by trial-and-error | The TOML is written by the aramb-toml skill. If you have to hand-author TOML, EXIT. |
| Try to fix `aramb` CLI bugs or work around them | EXIT with the CLI's error message verbatim. |

---

## Error Handling

### Error Message Format

```
ERROR: {specific error message}
Step: {step number and name}
Details: {relevant context}
```

### Error Policy

- Any error at any step → EXIT immediately with a clear error message.
- Do NOT retry. Do NOT debug. Do NOT improvise.
- Report the failing CLI command and its stderr/exit code verbatim — that is what the user needs to investigate.

### Service Creation Failures

If `aramb services create --from-toml` fails:
- Check for name conflicts with existing services in the application.
- Try a different service name in the TOML (services may persist after failure — there is no automatic cleanup).

### Build Failures

If `aramb build` fails: log the service slug, the build path, and the build's stderr. EXIT without deploying. Do not try alternate build methods.

### Deploy Status `failed`/`error`

If `aramb deploy status` reports a non-`completed` terminal state, report the JSON output verbatim and EXIT. Do not chase logs.

---

## Common Scenarios

### Scenario 1: Full-Stack App with Database (Git-Connected)

```
Backend: Express in ./backend | Frontend: React+Vite in ./frontend | DB: postgres
Git remote: YES

aramb.toml services (generated by aramb-toml skill):
  postgres-db    (type=postgres, image=postgres:15)
  backend-build  (type=build,    buildPath=./backend)
  backend-api    (type=backend,  image=${101.outputs.IMAGE_URL})
  frontend-web   (type=frontend, image="", staticPath="./frontend/dist",
                  API_URL=${102.outputs.PUBLIC_URL})

→ aramb services create --from-toml
→ aramb build ./frontend --static-outdir ./frontend/dist --service frontend-web --push
  → update image in TOML for frontend-web
→ aramb deploy --from-toml --yes
→ poll aramb deploy status for each non-build service
```

### Scenario 2: Full-Stack App (No Git Remote)

```
Backend: Express in ./api | Frontend: React+Vite in ./web
Git remote: NO

aramb.toml services (generated by aramb-toml skill):
  backend-api   (type=backend,  image="")
  frontend-web  (type=frontend, image="", staticPath="./web/dist",
                 API_URL=${101.outputs.PUBLIC_URL})

→ aramb services create --from-toml
→ aramb build ./api --service backend-api --push                            → update image in TOML
→ aramb build ./web --static-outdir ./web/dist --service frontend-web --push → update image in TOML
→ aramb deploy --from-toml --yes
→ poll aramb deploy status for each non-build service
```

### Scenario 3: Frontend-Only

```
Either git-connected or no-git (static frontends always build locally):
  frontend-web  (type=frontend, image="", staticPath="./dist")
→ aramb services create --from-toml
→ aramb build . --static-outdir ./dist --service frontend-web --push
  → update image in TOML
→ aramb deploy --from-toml --yes
→ poll deploy status

```

### Scenario 4: Pre-Built/Third-Party Backend

```
Uses public API image + own static frontend codebase. Git remote: YES or NO

  public-api    (type=backend,  image="myorg/api:v2")  ← no build service
  frontend-web  (type=frontend, image="", staticPath="./frontend/dist",
                 API_URL=${101.outputs.PUBLIC_URL})

→ aramb services create --from-toml
→ aramb build ./frontend --static-outdir ./frontend/dist --service frontend-web --push
  → update image in TOML
→ aramb deploy --from-toml --yes
→ poll deploy status
```
