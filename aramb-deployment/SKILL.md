---
name: aramb-deployment
description: Build and deploy applications using aramb-cli. Covers aramb-cli installation, deployment mode detection, env var/secret filling, service creation, local Docker builds, and deployment orchestration. Use for all deployment tasks. TOML generation is handled by the aramb-toml skill.
---

# Aramb Deployment

Build and deploy applications using `aramb` CLI. Follow this workflow strictly. If any step fails, EXIT immediately with a clear error message. Do NOT attempt to debug or fix aramb-cli issues.

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

- `ARAMB_API_TOKEN` — Authentication for all aramb operations
- `JUMBO_URL` — Jumbo platform URL for service creation and deployment (base URL only, e.g., `http://jumbo:8080`)
- `APPLICATION_ID` — Application identifier; passed to the aramb-toml skill and used in all service definitions
- `BUILDKIT_HOST` — Remote BuildKit server for Docker image builds (required for no-git local builds only)

Optional:
- `DOCKER_REGISTRY` — Custom Docker registry URL (default: aramb's built-in registry)
- `DOCKER_REGISTRY_USER` — Registry username for custom registry push
- `DOCKER_REGISTRY_PASSWORD` — Registry password for custom registry push

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

The skill will scan the codebase and write `aramb.toml` with build + runtime service pairs for own-codebase services. Do NOT write TOML yourself — delegate entirely to the skill.

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

```bash
# Ignore config update errors — only fail if service creation itself fails
aramb services create --from-toml 2>&1 | tee /tmp/services_create.log
grep -i "error" /tmp/services_create.log | grep -iv "config" && { echo "ERROR: Service creation failed"; exit 1; } || true
```

---

### Step 4: Deploy All Services from TOML

```bash
aramb deploy --from-toml --yes || { echo "ERROR: Deploy failed"; exit 1; }
```

---

### Step 5: Validate and Return Outputs

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

Use when the project directory has no remote git repository. Services are created from TOML, images are built and pushed locally, then deployed.

### Step 1: Generate aramb.toml

Invoke the **aramb-toml** skill with:
- `mode = "no-git"`

The skill will write `aramb.toml` with runtime-only services (no build services) and `image = ""` placeholders for own-codebase services.

---

### Step 2: Fill Env Vars and Secrets

Same as Path A Step 2.

---

### Step 3: Create Services from TOML

```bash
# Ignore config update errors — only fail if service creation itself fails
aramb services create --from-toml 2>&1 | tee /tmp/services_create.log
grep -i "error" /tmp/services_create.log | grep -iv "config" && { echo "ERROR: Service creation failed"; exit 1; } || true
```

---

### Step 4: Build and Push Images Locally

Always use `--push`. The CLI uses its built-in registry by default — no registry-conditional logic needed.

After `services create --from-toml`, the TOML has actual `slug` values written back. Read those slugs and the corresponding build paths, then build each own-codebase service. Skip database and public-image services (those with a non-empty `image` already set).

```bash
[ -n "$BUILDKIT_HOST" ] || { echo "ERROR: BUILDKIT_HOST not set"; exit 1; }

# Read own-codebase service slugs and build paths from aramb.toml
# For each service with image = "" (own-codebase), extract its slug and build path
# then run aramb build pointing at that service's source directory

# Example — replace SERVICE_SLUG and BUILD_PATH with values read from aramb.toml:
IMAGE_URL=$(aramb build {BUILD_PATH} --service {SERVICE_SLUG} --push \
  | jq -r '.IMAGE_URL') || { echo "ERROR: Build failed for {SERVICE_SLUG}"; exit 1; }
```

Where:
- `{BUILD_PATH}` — the local directory containing the Dockerfile for this service (read from codebase analysis, e.g. `./backend`, `./frontend`)
- `{SERVICE_SLUG}` — the `slug` field written into aramb.toml by `services create --from-toml` for the runtime service (not the build service)

---

### Step 5: Update aramb.toml with Built Image URLs

For each service built in Step 4, replace its `image = ""` placeholder using the slug to scope the replacement:

```bash
# Use the service slug (from aramb.toml) to scope the sed replacement
SERVICE_SLUG={slug from aramb.toml}
IMAGE_URL={IMAGE_URL from aramb build output}

sed -i "/slug = \"${SERVICE_SLUG}\"/,/\[\[/ s|image = \"\"|image = \"${IMAGE_URL}\"|" aramb.toml

# After all services are updated, verify no placeholders remain
grep 'image = ""' aramb.toml && { echo "ERROR: Some service images not updated"; exit 1; } || true
```

---

### Step 6: Deploy All Services from TOML

```bash
aramb deploy --from-toml --yes || { echo "ERROR: Deploy failed"; exit 1; }
```

---

### Step 7: Validate and Return Outputs

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

## Error Handling

### Error Message Format

```
ERROR: {specific error message}
Step: {step number and name}
Details: {relevant context}
```

### Error Policy

- Any error at any step → EXIT immediately with clear error message
- Do NOT retry failed builds
- Do NOT attempt to debug or fix aramb-cli issues
- Do NOT attempt to login or authenticate manually
- `aramb services create --from-toml`: ignore config update errors, EXIT only if service creation fails
- If `aramb deploy --from-toml` fails → check TOML validity before retrying

### Service Creation Failures

If `aramb services create --from-toml` fails on service creation:
- Check for name conflicts with existing services
- Try a different service name (service may persist after failure — no automatic cleanup)

### Build Failures

If `aramb build` fails: log the service slug and build path, EXIT without deploying.

---

## Common Scenarios

### Scenario 1: Full-Stack App with Database (Git-Connected)

```
Backend: Express in ./backend | Frontend: React+Vite in ./frontend | DB: postgres
Git remote: YES

aramb.toml services (generated by aramb-toml skill):
  postgres-db      (type=postgres, image=postgres:15)
  backend-build    (type=build,    buildPath=./backend)
  backend-api      (type=backend,  image=${101.outputs.IMAGE_URL})
  frontend-build   (type=build,    buildPath=./frontend)
  frontend-web     (type=frontend, image=${103.outputs.IMAGE_URL}, API_URL=${102.outputs.PRIVATE_URL})

→ aramb deploy --from-toml --yes
```

### Scenario 2: Full-Stack App (No Git Remote)

```
Backend: Express in ./api | Frontend: React+Vite in ./web
Git remote: NO

aramb.toml services (generated by aramb-toml skill):
  backend-api   (type=backend,  image="")
  frontend-web  (type=frontend, image="", API_URL=${101.outputs.PRIVATE_URL})

→ aramb services create --from-toml
→ aramb build ./api --service backend-api --push   → update image in TOML
→ aramb build ./web --service frontend-web --push   → update image in TOML
→ aramb deploy --from-toml --yes
```

### Scenario 3: Frontend-Only

```
Git-connected:
  frontend-build  (type=build,    buildPath=.)
  frontend-web    (type=frontend, image=${100.outputs.IMAGE_URL})
→ aramb deploy --from-toml --yes

No-git:
  frontend-web  (type=frontend, image="")
→ aramb services create --from-toml
→ aramb build . --service frontend-web --push
→ update TOML → aramb deploy --from-toml --yes
```

### Scenario 4: Pre-Built/Third-Party Backend

```
Uses public API image + own frontend codebase. Git remote: YES

  public-api      (type=backend,  image="myorg/api:v2")  ← no build service
  frontend-build  (type=build,    buildPath=./frontend)
  frontend-web    (type=frontend, image=${102.outputs.IMAGE_URL}, API_URL=${101.outputs.PRIVATE_URL})

→ aramb deploy --from-toml --yes
```
