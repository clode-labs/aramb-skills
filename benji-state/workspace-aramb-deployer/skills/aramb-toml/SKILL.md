---
name: aramb-toml
description: Generate and update aramb.toml configuration files for deploying applications on aramb. Covers codebase analysis, service type mapping, variable/secret classification, TOML structure, and validation. Use this skill whenever aramb.toml needs to be created or updated.
---

# Aramb TOML Generation

Analyze the project codebase and produce a valid `aramb.toml`. Follow these rules exactly.

---

## Prerequisites

`APPLICATION_ID` environment variable MUST be set. Exit immediately if not:

```bash
[ -n "$APPLICATION_ID" ] || { echo "ERROR: APPLICATION_ID not set"; exit 1; }
```

The `applicationId` field in every `[[services]]` block is always set to this value. **Do NOT create an `[[application]]` block in the TOML** — the application already exists on the platform.

---

## Caller-Provided Context

The caller (deployment skill) passes:

| Parameter | Values | Meaning |
|-----------|--------|---------|
| `mode` | `git` | Project has a remote git repo — create `type="build"` services for own codebase |
| `mode` | `no-git` | No remote git repo — images are built locally; use `image = ""` placeholders |
| `repoUrl` | `https://github.com/...` | Git remote URL (git mode only) — set as `repoUrl` in all build services |

---

## Step 1: Codebase Analysis

Scan the project for:
- **Docker Compose files**: extract services, ports, env vars, volumes, database images
- **Environment files** (`.env`, `.env.example`): extract KEY=VALUE pairs, classify as vars or secrets
- **Package files** (`package.json`, `go.mod`, `requirements.txt`): detect frameworks
- **Framework markers**: `next.config.js/mjs`, `vite.config.ts/js`, `angular.json`, `vue.config.js`
- **Dockerfiles and build scripts**: detect build context paths and base images

---

## Step 2: Service Type Mapping

### Git Mode

Create TWO services (build + runtime) for every service whose codebase you own. Use ONE service for public/third-party images.

| Detected Pattern | Services to Create | Notes |
|---------|-------------------|-------|
| Backend framework (Express, FastAPI, Gin, Django, etc.) | TWO: `type="build"` + `type="backend"` | Build ID < Runtime ID |
| Server-side frontend (Next.js, Nuxt, SvelteKit) | TWO: `type="build"` + `type="backend"` | Runs a Node server — NOT static |
| Static frontend (React/Vite SPA, CRA, Angular) | TWO: `type="build"` + `type="frontend"` | Build ID < Runtime ID |
| Microservice with Dockerfile | TWO: `type="build"` + `type="backend"` or `type="template"` | |
| Aramb agent code | TWO: `type="build"` + `type="aramb-agent"` | |
| Database (postgres, redis, mongodb) — public image | ONE: direct `image` | No build service |
| Pre-built/third-party container | ONE: direct `image` | No build service |

### No-Git Mode

Create ONE runtime service per own-codebase service (no build services). Public images are the same as git mode.

| Detected Pattern | Services to Create | Notes |
|---------|-------------------|-------|
| Own codebase (any framework) | ONE runtime service | `image = ""` placeholder, filled after local build |
| Database / public image | ONE: direct `image` | Same as git mode |

---

## Step 3: Generate aramb.toml

### Git Mode Template

```toml
# === DATABASE — public image, no build service ===

[[services]]
uniqueIdentifier = 100
name = "postgres-db"
type = "postgres"
description = "PostgreSQL database for application data"
applicationId = "$APPLICATION_ID"

[services.configuration.settings]
image = "postgres:15"
commandPort = 5432
publicNet = false

[[services.configuration.vars]]
key = "POSTGRES_DB"
value = "myapp"

[[services.configuration.vars]]
key = "POSTGRES_USER"
value = "postgres"

[[services.configuration.secrets]]
key = "POSTGRES_PASSWORD"
value = ""

# === BACKEND — own codebase ===
# Build uniqueIdentifier MUST be less than runtime uniqueIdentifier

[[services]]
uniqueIdentifier = 101
name = "backend-build"
type = "build"
description = "Build service that produces the backend API Docker image"
applicationId = "$APPLICATION_ID"

[services.configuration.settings]
repoUrl = "<repoUrl from caller>"
buildPath = "./backend"
targetBranches = ["main"]
installationId = "123456789"

[[services]]
uniqueIdentifier = 102
name = "backend-api"
type = "backend"
description = "Backend API service handling business logic and data persistence"
applicationId = "$APPLICATION_ID"

[services.configuration.settings]
image = "${101.outputs.IMAGE_URL}"
commandPort = 8080
publicNet = true

[[services.configuration.vars]]
key = "PORT"
value = "8080"

[[services.configuration.secrets]]
key = "DATABASE_URL"
value = "postgres://${100.vars.POSTGRES_USER}:${100.secrets.POSTGRES_PASSWORD}@${100.outputs.PRIVATE_URL}:5432/${100.vars.POSTGRES_DB}"

[[services.configuration.secrets]]
key = "JWT_SECRET"
value = ""

# === FRONTEND — own codebase ===

[[services]]
uniqueIdentifier = 103
name = "frontend-build"
type = "build"
description = "Build service that produces the frontend web application Docker image"
applicationId = "$APPLICATION_ID"

[services.configuration.settings]
repoUrl = "<repoUrl from caller>"
buildPath = "./frontend"
targetBranches = ["main"]
installationId = "123456789"

[[services]]
uniqueIdentifier = 104
name = "frontend-web"
type = "frontend"
description = "Frontend web application serving the React/Vue/Angular UI"
applicationId = "$APPLICATION_ID"

[services.configuration.settings]
image = "${103.outputs.IMAGE_URL}"
staticPath = "./frontend/dist"
cmd = "npx http-server"
commandPort = 8080
publicNet = true

[[services.configuration.vars]]
key = "API_URL"
value = "${102.outputs.PRIVATE_URL}"
```

### No-Git Mode Template

Same structure but:
- No `type="build"` services
- No `repoUrl`, `buildPath`, `targetBranches`, `installationId` fields
- `image = ""` for own-codebase runtime services (filled after `aramb build`)

```toml
[[services]]
uniqueIdentifier = 100
name = "postgres-db"
type = "postgres"
description = "PostgreSQL database for application data"
applicationId = "$APPLICATION_ID"

[services.configuration.settings]
image = "postgres:15"
commandPort = 5432
publicNet = false

[[services.configuration.vars]]
key = "POSTGRES_DB"
value = "myapp"

[[services.configuration.vars]]
key = "POSTGRES_USER"
value = "postgres"

[[services.configuration.secrets]]
key = "POSTGRES_PASSWORD"
value = ""

[[services]]
uniqueIdentifier = 101
name = "backend-api"
type = "backend"
description = "Backend API service handling business logic and data persistence"
applicationId = "$APPLICATION_ID"

[services.configuration.settings]
image = ""  # filled after: aramb build ./backend --service {slug} --push
commandPort = 8080
publicNet = true

[[services.configuration.vars]]
key = "PORT"
value = "8080"

[[services.configuration.secrets]]
key = "DATABASE_URL"
value = "postgres://${100.vars.POSTGRES_USER}:${100.secrets.POSTGRES_PASSWORD}@${100.outputs.PRIVATE_URL}/${100.vars.POSTGRES_DB}"

[[services.configuration.secrets]]
key = "JWT_SECRET"
value = ""

[[services]]
uniqueIdentifier = 102
name = "frontend-web"
type = "frontend"
description = "Frontend web application serving the React/Vue/Angular UI"
applicationId = "$APPLICATION_ID"

[services.configuration.settings]
image = ""  # filled after: aramb build ./frontend --service {slug} --push
staticPath = "./frontend/dist"
commandPort = 8080
publicNet = true

[[services.configuration.vars]]
key = "API_URL"
value = "${101.outputs.PRIVATE_URL}"
```

---

## Reference: Supported Service Types

`aramb-agent`, `backend`, `build`, `frontend`, `mongodb`, `onboarding`, `postgres`, `redis`, `template`

---

## Reference: Variable References

| Syntax | Resolves To |
|--------|-------------|
| `${N.vars.KEY}` | Var value from service N |
| `${N.secrets.KEY}` | Secret value from service N |
| `${N.outputs.IMAGE_URL}` | Docker image URL produced by build service N |
| `${N.outputs.PRIVATE_URL}` | Internal network URL of service N — use for backend URL in frontend config |

---

## Reference: Backend Service Rules (CRITICAL)

### Never set `cmd` for backend services

The platform splits `cmd` strings by spaces and passes tokens directly as Kubernetes `command`/`args` — **no shell wrapper is applied**. A cmd like:

```
cmd = "sh -c 'flask db upgrade && gunicorn -b 0.0.0.0:5000 src.app:create_app()'"
```

becomes:

```json
"command": ["sh"],
"args": ["-c", "flask db upgrade && gunicorn -b 0.0.0.0:5000 src.app:create_app()"]
```

...which breaks any `&&` chaining. Flask/gunicorn sees `-b` as an unrecognised option and crashes.

**Rule: Do NOT set `cmd` in `type="backend"` service blocks.** Let the Dockerfile's `CMD` handle execution. If the Dockerfile needs a startup chain, it must already use shell form:

```dockerfile
CMD ["sh", "-c", "flask db upgrade && gunicorn -b 0.0.0.0:$PORT 'src.app:create_app()'"]
```

Remove `cmd` from any backend service block in the TOML:

```toml
# WRONG — never do this for backend services
[services.configuration.settings]
cmd = "sh -c 'flask db upgrade && gunicorn -b 0.0.0.0:5000 src.app:create_app()'"

# CORRECT — omit cmd entirely, trust the Dockerfile CMD
[services.configuration.settings]
image = "${101.outputs.IMAGE_URL}"
commandPort = 5000
publicNet = true
```

### `commandPort` must match the container's actual bind port

`commandPort` in aramb.toml must exactly match the port the process inside the container binds to. Mismatch = service starts but never receives traffic.

| Dockerfile CMD | Correct `commandPort` |
|---|---|
| `gunicorn -b 0.0.0.0:5000 ...` | `5000` |
| `gunicorn -b 0.0.0.0:$PORT ...` with `PORT=8080` | `8080` |
| `node server.js` with `app.listen(3000)` | `3000` |

**Rule: Read the Dockerfile CMD or app source to confirm the bind port before setting `commandPort`. Never assume 8080.**

---

## Reference: Vars vs Secrets Classification

**Classify as var** (set actual value): hosts, ports, URLs, database names, usernames, environment flags, feature toggles, timeouts

**Classify as secret** — two categories:

**Internal secrets** (app creates and owns them — generate a test value so the service starts):

| Key pattern | Generated value |
|---|---|
| `POSTGRES_PASSWORD`, `DB_PASSWORD` | `"postgres"` |
| `JWT_SECRET`, `JWT_SIGNING_KEY` | `"super-secret-jwt-key-change-in-production"` |
| `SESSION_SECRET`, `COOKIE_SECRET` | `"session-secret-change-in-production"` |
| `APP_SECRET`, `SECRET_KEY`, `SIGNING_KEY` | `"app-secret-key-change-in-production"` |

**External secrets** (third-party or external system — leave `value = ""`):
- Third-party API keys: `STRIPE_SECRET_KEY`, `SENDGRID_API_KEY`, `TWILIO_AUTH_TOKEN`
- OAuth credentials: `GOOGLE_CLIENT_SECRET`, `GITHUB_CLIENT_SECRET`
- External service credentials: `SMTP_PASSWORD`, webhook secrets

**Keyword detection — secret** if key contains (case-insensitive):
`PASSWORD`, `PASSWD`, `PWD`, `SECRET`, `TOKEN`, `API_KEY`, `PRIVATE`, `CREDENTIAL`, `JWT`, `OAUTH`, `SESSION_SECRET`

**Keyword detection — var** if key contains:
`HOST`, `PORT`, `URL`, `ENDPOINT`, `DATABASE`, `DB_NAME`, `DB_USER`, `ENVIRONMENT`, `DEBUG`

**CRITICAL**: Any value that references `${N.secrets.KEY}` MUST be placed in `[[secrets]]`, never `[[vars]]`.

---

## Reference: uniqueIdentifier Rules

- Start at 100, increment by 1: 100, 101, 102, ...
- No gaps, no duplicates across the entire file
- Build service ID must be **less than** its corresponding runtime service ID
- Order services by dependency — lower IDs are dependencies of higher IDs

---

## Updating Existing aramb.toml

If `aramb.toml` already exists:
1. Read the existing file
2. Merge new services — skip any service whose `name` already exists
3. Preserve all existing `uniqueIdentifier`, `id`, and `slug` values exactly
4. Do NOT modify any service that already has `id` or `slug` set (it is already deployed)
5. Continue the `uniqueIdentifier` sequence from the highest existing value + 1

---

## Validation Checklist

Run through this before finishing:

1. `APPLICATION_ID` is set — exit if not
2. No `[[application]]` block exists in the file
3. Every `[[services]]` block has `applicationId = "$APPLICATION_ID"`
4. Every service has `name`, `type`, `description`, `application`
5. All `type` values are from the supported list
6. `uniqueIdentifier` values are sequential, no gaps, no duplicates
7. Every build service ID is less than its corresponding runtime service ID
8. All `${N.vars.KEY}`, `${N.secrets.KEY}`, `${N.outputs.KEY}` references point to real services and keys
9. No circular dependencies
10. Any value referencing `${N.secrets.KEY}` is in `[[secrets]]`, not `[[vars]]`
11. No hardcoded sensitive values in secrets (must be `""` or a `${...}` reference)
12. Frontend `API_URL` var uses `${backend-runtime-id.outputs.PRIVATE_URL}`
13. In no-git mode: all own-codebase services have `image = ""` (not a real image URL)
14. In git mode: all build services have `repoUrl`, `buildPath`, `targetBranches`, `installationId`

**Error fallbacks:**
- No services detected → create minimal template: one postgres + one backend
- Unknown framework/type → use `type = "template"`
- Circular dependency → log warning, break the cycle
- Docker Compose parsing fails → fall back to codebase-only analysis
