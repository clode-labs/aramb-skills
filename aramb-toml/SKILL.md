---
name: aramb-toml
description: Generate and update aramb.toml configuration files for deploying applications on aramb. Covers codebase analysis, service type mapping, variable/secret classification, TOML structure, and validation. Use this skill whenever aramb.toml needs to be created or updated.
---

# Aramb TOML Generation

Analyze the project codebase and produce a valid `aramb.toml`.

## Prerequisites

`APPLICATION_ID` must be set:

```bash
[ -n "$APPLICATION_ID" ] || { echo "ERROR: APPLICATION_ID not set"; exit 1; }
```

Every `[[services]]` block sets `applicationId = "$APPLICATION_ID"`. The application already exists on the platform — no `[[application]]` block goes in the TOML.

## Caller-Provided Context

The deployment skill passes:

| Parameter | Values | Meaning |
|---|---|---|
| `mode` | `git` / `no-git` | `git` creates `type="build"` services for own backend code; `no-git` uses local-build placeholders. |
| `repoUrl` | `https://github.com/…` | Set as `repoUrl` in every build service (git mode only). |

## Step 1: Codebase Analysis

Scan for:
- **Docker Compose**: services, ports, env vars, volumes, database images
- **Env files** (`.env`, `.env.example`): KEY=VALUE pairs → vars or secrets
- **Package files** (`package.json`, `go.mod`, `requirements.txt`, `pom.xml`, `Gemfile`): frameworks
- **Framework markers**: `next.config.*`, `vite.config.*`, `angular.json`, `nuxt.config.*`
- **Dockerfiles**: build context paths, base images, CMD bind ports

## Step 2: Service Type Mapping

| Detected Pattern | Service(s) | Build service `targetType` |
|---|---|---|
| Backend framework (Express, FastAPI, Gin, Django, Rails, …) | git: `build` + `backend` · no-git: `backend` only | `"backend"` |
| Server-side frontend (Next.js, Nuxt, SvelteKit) | same as backend | `"backend"` |
| Static frontend (React/Vite, CRA, Angular, plain HTML) | git: `build` + `frontend` · no-git: `frontend` only | `"frontend"` (+ `staticOutDir`) |
| Aramb agent code | `build` + `aramb-agent` | `"aramb-agent"` |
| Database (postgres, redis, mongodb) | direct `image` | n/a (no build service) |
| Pre-built / third-party container | direct `image` | n/a (no build service) |

Supported service types: `aramb-agent`, `backend`, `build`, `frontend`, `mongodb`, `onboarding`, `postgres`, `redis`, `template`.

## Step 3: TOML Structure Rules

### uniqueIdentifier
- Start at 100, increment by 1. No gaps, no duplicates.
- Build service ID is **less than** its runtime service ID.
- Order services by dependency: lower IDs are dependencies of higher IDs.

### Build services declare `targetType`
Every `type="build"` service sets `targetType` to the runtime type that consumes its `outputs.IMAGE_URL` (`"backend"`, `"frontend"`, `"aramb-agent"`, or `"template"`). The build worker forwards this to `aramb build --type …`, taking the matching path deterministically (static OCI artifact for frontend; Docker/Railpack image for backend) regardless of any Dockerfile in the build path. The platform validates that the consuming runtime service's `type` matches the build's `targetType`.

When `targetType="frontend"`, also set `staticOutDir` to the framework's build-output directory (`"./dist"` for Vite, `"./build"` for CRA, `"./out"` for Next static export, `"./dist/<app>"` for Angular).

### Backend `cmd` is never set
The platform passes `cmd` as raw argv to Kubernetes with no shell wrapper, so `&&` chaining and shell interpolation break. Backend services rely on the Dockerfile `CMD` (use shell form there for startup chains: `CMD ["sh","-c","flask db upgrade && gunicorn -b 0.0.0.0:$PORT app:create_app()"]`).

### `commandPort` matches the in-container bind port
Read the Dockerfile `CMD` or app source — set `commandPort` to whatever port the process binds inside the container (`gunicorn -b 0.0.0.0:5000` → `5000`; `app.listen(3000)` → `3000`). Mismatch = service starts but never receives traffic.

### Variable references

| Syntax | Resolves To |
|---|---|
| `${N.vars.KEY}` / `${N.secrets.KEY}` | Var / secret of service N |
| `${N.outputs.IMAGE_URL}` | Image URL from build service N (Docker image or static OCI artifact) |
| `${N.outputs.PRIVATE_URL}` | In-cluster URL of service N — `http://<slug>.clode.internal:<port>` |
| `${N.outputs.PUBLIC_URL}` | Public URL of service N — `https://<slug>.proxy.clode.space` |

Pick the URL by caller:
- **In-cluster → in-cluster** (backend → backend, backend → db, SSR frontend → backend): `PRIVATE_URL`
- **Static frontend → backend** (the browser fetches the API): `PUBLIC_URL`
- **Anything user-facing** (OAuth callbacks, links, redirects): `PUBLIC_URL`

`PRIVATE_URL` / `PUBLIC_URL` always include the scheme and (for `PRIVATE_URL`) the port. Consumers parse the URL in code — see the `dev-workflow` skill's "Datasource Connections" section.

### Vars vs secrets classification

**Var** (set actual value): hosts, ports, URLs, database names, usernames, env flags, feature toggles, timeouts.

**Internal secret** (app owns it — generate a placeholder so the service starts):

| Key pattern | Default value |
|---|---|
| `*PASSWORD`, `*PASSWD`, `*PWD` | `"postgres"` for DB, `"change-me"` otherwise |
| `JWT_*`, `*SIGNING_KEY` | `"super-secret-jwt-key-change-in-production"` |
| `SESSION_*`, `COOKIE_*` | `"session-secret-change-in-production"` |
| `APP_SECRET`, `SECRET_KEY` | `"app-secret-key-change-in-production"` |

**External secret** (third-party / OAuth — leave `value = ""`): `STRIPE_SECRET_KEY`, `SENDGRID_API_KEY`, `GOOGLE_CLIENT_SECRET`, `SMTP_PASSWORD`, webhook secrets, etc.

Keyword cues — secret if key contains: `PASSWORD`, `PASSWD`, `PWD`, `SECRET`, `TOKEN`, `API_KEY`, `PRIVATE`, `CREDENTIAL`, `JWT`, `OAUTH`. Var if it contains: `HOST`, `PORT`, `URL`, `ENDPOINT`, `DATABASE`, `DB_NAME`, `DB_USER`, `ENVIRONMENT`, `DEBUG`.

Any value referencing `${N.secrets.KEY}` lives in `[[secrets]]`, not `[[vars]]`.

### `ALLOWED_ORIGINS`
Every backend and every frontend service includes:

```toml
[[services.configuration.vars]]
key = "ALLOWED_ORIGINS"
value = "https://*.proxy.clode.space"
```

Comma-append more origins when needed; the proxy wildcard is always present. The recipient (CORS middleware, Vite host whitelist, etc.) reads it from env — see the `dev-workflow` skill.

## Step 4: TOML Template — Git Mode

```toml
# === DATABASE — public image ===
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

# === BACKEND — own codebase (build + runtime) ===
[[services]]
uniqueIdentifier = 101
name = "backend-build"
type = "build"
description = "Build service that produces the backend API image"
applicationId = "$APPLICATION_ID"
[services.configuration.settings]
repoUrl = "<repoUrl from caller>"
buildPath = "./backend"
targetBranches = ["main"]
installationId = "123456789"
targetType = "backend"

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
[[services.configuration.vars]]
key = "ALLOWED_ORIGINS"
value = "https://*.proxy.clode.space"
[[services.configuration.vars]]
key = "POSTGRES_HOST_URL"
value = "${100.outputs.PRIVATE_URL}"
[[services.configuration.vars]]
key = "POSTGRES_USER"
value = "${100.vars.POSTGRES_USER}"
[[services.configuration.vars]]
key = "POSTGRES_DB"
value = "${100.vars.POSTGRES_DB}"
[[services.configuration.secrets]]
key = "POSTGRES_PASSWORD"
value = "${100.secrets.POSTGRES_PASSWORD}"
[[services.configuration.secrets]]
key = "JWT_SECRET"
value = ""

# === FRONTEND — static assets (build + runtime) ===
# targetType="frontend" + staticOutDir tell the build worker to
# invoke `aramb build --type frontend --static-outdir <staticOutDir>`,
# producing a static.tgz OCI artifact regardless of any Dockerfile in the
# build path. Dockerfiles for local docker-compose previews stay intact.
[[services]]
uniqueIdentifier = 103
name = "frontend-build"
type = "build"
description = "Build service that produces the frontend static OCI artifact"
applicationId = "$APPLICATION_ID"
[services.configuration.settings]
repoUrl = "<repoUrl from caller>"
buildPath = "./frontend"
targetBranches = ["main"]
installationId = "123456789"
targetType = "frontend"
staticOutDir = "./frontend/dist"

[[services]]
uniqueIdentifier = 104
name = "frontend-web"
type = "frontend"
description = "Frontend web application serving the React/Vue/Angular UI"
applicationId = "$APPLICATION_ID"
[services.configuration.settings]
image = "${103.outputs.IMAGE_URL}"
staticPath = "./frontend/dist"
[[services.configuration.vars]]
key = "API_URL"
value = "${102.outputs.PUBLIC_URL}"
[[services.configuration.vars]]
key = "ALLOWED_ORIGINS"
value = "https://*.proxy.clode.space"
```

### No-Git Mode — delta from above

Apply these changes to the git-mode template; everything else stays identical:
- Drop the `backend-build` and `frontend-build` blocks (all `type="build"` services).
- In the backend runtime block, replace `image = "${101.outputs.IMAGE_URL}"` with `image = ""` (filled locally by `aramb build ./backend --type backend --service {slug} --push`).
- In the frontend runtime block, replace `image = "${103.outputs.IMAGE_URL}"` with `image = ""` (filled locally by `aramb build ./frontend --type frontend --static-outdir ./frontend/dist --service {slug} --push`).
- Renumber `uniqueIdentifier` to stay sequential without the build services (backend becomes 101, frontend becomes 102).
- Update the frontend's `API_URL` reference to the new backend ID (`${101.outputs.PUBLIC_URL}`).

## Updating an Existing aramb.toml

1. Read the file.
2. Skip any service whose `name` already exists.
3. Preserve existing `uniqueIdentifier`, `id`, and `slug` values exactly.
4. Don't modify any service that already has `id` or `slug` set — it is already deployed.
5. Continue the `uniqueIdentifier` sequence from the highest existing value + 1.

## Validation Checklist

1. `APPLICATION_ID` is set; no `[[application]]` block in the file.
2. Every `[[services]]` block has `applicationId = "$APPLICATION_ID"`, `name`, `type`, `description`.
3. All `type` values are from the supported list.
4. `uniqueIdentifier` is sequential, no gaps, no duplicates; every build ID is less than its runtime ID.
5. All `${N.vars.KEY}` / `${N.secrets.KEY}` / `${N.outputs.KEY}` references point to real services and keys. No circular dependencies.
6. Any value referencing `${N.secrets.KEY}` lives in `[[secrets]]`; no hardcoded sensitive values (`""` or a `${…}` reference only).
7. Backend services omit `cmd` and have `commandPort` matching the Dockerfile bind port.
8. Static frontends (`type="frontend"`) have `image = ""` and `staticPath` set; image is filled by a local `--static-outdir` build.
9. Static frontends reference backends via `${backend-id.outputs.PUBLIC_URL}`; SSR frontends (`type="backend"`) and other backends reference in-cluster services via `${N.outputs.PRIVATE_URL}`.
10. Every backend and every frontend service has an `ALLOWED_ORIGINS` var that includes `https://*.proxy.clode.space`.
11. Every `type="build"` service declares `targetType` matching its consuming runtime (`"backend"`, `"frontend"`, `"aramb-agent"`, or `"template"`). When `targetType="frontend"`, `staticOutDir` is also set.
12. Git mode: every build service has `repoUrl`, `buildPath`, `targetBranches`, `installationId`. No-git mode: all own-codebase services have `image = ""`.

**Error fallbacks**: no services detected → minimal template (one postgres + one backend); unknown framework → `type = "template"`; circular dependency → break the cycle; Docker Compose parse failure → fall back to codebase-only analysis.
