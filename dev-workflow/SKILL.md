---
name: dev-workflow
description: >
  Development workflow protocol — branching, committing, project structure, and
  docker-compose conventions. Use when: (1) starting a new project or feature,
  (2) making commits, (3) setting up project structure with docker-compose,
  (4) completing a development task. NOT for: deployment, CI/CD pipeline
  configuration, or infrastructure changes.
---

# Dev Workflow

## Receiving Tasks

Every task arrives with context from the orchestrator:
- `project_id` — the platform project this belongs to
- `application_id` — the specific app/service being built (used in branch names)
- `acceptance_criteria` — what "done" looks like (verify every criterion before reporting)

Read the full task description before writing any code. Identify: what to build, what stack to use, what the deliverables are.

## Git Branching

Create a branch from the default branch before starting work.

**Branch naming:**
- Features: `feat/<app_id>/<short-description>` — e.g., `feat/auth-service/jwt-login`
- Bug fixes: `fix/<app_id>/<short-description>` — e.g., `fix/auth-service/token-expiry`
- Refactors: `refactor/<app_id>/<short-description>`
- Tests: `test/<app_id>/<short-description>`

Rules:
- Lowercase, hyphens only (no underscores, no spaces)
- `<app_id>` matches the `application_id` from the task
- `<short-description>` is 2-4 words max
- One branch per task — don't mix unrelated changes

## Conventional Commits

Every commit message follows the format: `<type>(<scope>): <description>`

**Types:**
- `feat` — new feature or capability
- `fix` — bug fix
- `refactor` — code restructuring without behavior change
- `test` — adding or updating tests
- `docs` — documentation only
- `chore` — build config, dependencies, tooling
- `style` — formatting, whitespace (no logic change)

**Scope:** the module, service, or component affected — e.g., `auth`, `api`, `docker`, `db`

**Examples:**
```
feat(auth): add JWT login endpoint with rate limiting
fix(api): handle null user in profile lookup
test(auth): add unit tests for token validation
refactor(db): extract connection pool to shared module
docs(readme): add setup instructions and env vars
chore(docker): add health check to api service
```

**Rules:**
- One concern per commit — don't bundle unrelated changes
- Description is imperative mood ("add", "fix", "update" — not "added", "fixes")
- Keep the first line under 72 characters
- Add a body (blank line + details) for non-trivial changes

## Project Structure

Every runnable project must include this baseline:

```
project-root/
├── docker-compose.yml      # required — the deliverable
├── Dockerfile              # one per service (or in service subdirs)
├── .env.example            # required — document all env vars with safe defaults
├── .gitignore              # appropriate for the stack
├── README.md               # setup instructions, architecture overview
├── src/                    # application source code
│   └── ...                 # organized by the conventions of the chosen stack
└── tests/                  # test files
    └── ...                 # mirrors src/ structure where appropriate
```

For multi-service projects:
```
project-root/
├── docker-compose.yml
├── .env.example
├── services/
│   ├── api/
│   │   ├── Dockerfile
│   │   ├── src/
│   │   └── tests/
│   └── web/
│       ├── Dockerfile
│       ├── src/
│       └── tests/
└── shared/                 # shared libraries, types, configs
```

## Tunnel-Ready Builds

Every app must be built so it can be exposed via public tunnels (proxy.clode.space) without code changes. The local-deployer agent will inject public URLs at runtime via env vars — your job is to ensure those env vars are wired up from day one.

### Frontend — API base URL must be env-driven

The frontend must read its backend API URL from an environment variable. Never hardcode `localhost` or any hostname.

| Framework | Env var | How to read it |
|-----------|---------|----------------|
| Vite (React, Vue, Svelte) | `VITE_API_URL` | `import.meta.env.VITE_API_URL` |
| Next.js | `NEXT_PUBLIC_API_URL` | `process.env.NEXT_PUBLIC_API_URL` |
| CRA | `REACT_APP_API_URL` | `process.env.REACT_APP_API_URL` |
| Angular | `API_URL` | `environment.apiUrl` from `environment.ts` |

Example pattern (Vite):
```typescript
// src/config.ts
export const API_URL = import.meta.env.VITE_API_URL ?? "http://localhost:8080";
```

### Backend — CORS allowed origins must be env-driven (with proxy wildcard)

Every backend reads its CORS allowed origins from the `ALLOWED_ORIGINS` env var (comma-separated). The value is always supplied with `https://*.proxy.clode.space` included — any subdomain of `proxy.clode.space` must be accepted. Because most CORS middlewares treat the list as exact strings, match wildcards via regex in code.

```js
// Express (cors)
import cors from "cors";
const patterns = (process.env.ALLOWED_ORIGINS || "http://localhost:3000,https://*.proxy.clode.space")
  .split(",").map(s => new RegExp("^" + s.trim().replace(/\./g, "\\.").replace(/\*/g, ".*") + "$"));
app.use(cors({ origin: (origin, cb) => cb(null, !origin || patterns.some(re => re.test(origin))) }));
```

```python
# FastAPI / Starlette
import os, re
from fastapi.middleware.cors import CORSMiddleware
patterns = (os.getenv("ALLOWED_ORIGINS", "http://localhost:3000,https://*.proxy.clode.space")).split(",")
allow_origin_regex = "|".join("^" + p.strip().replace(".", r"\.").replace("*", ".*") + "$" for p in patterns)
app.add_middleware(CORSMiddleware, allow_origin_regex=allow_origin_regex, allow_credentials=True,
                   allow_methods=["*"], allow_headers=["*"])

# Django (django-cors-headers)
CORS_ALLOWED_ORIGIN_REGEXES = [
    "^" + p.strip().replace(".", r"\.").replace("*", ".*") + "$"
    for p in os.environ.get("ALLOWED_ORIGINS", "http://localhost:3000,https://*.proxy.clode.space").split(",")
]
```

```go
// Go (gin + gin-contrib/cors)
patterns := strings.Split(getenv("ALLOWED_ORIGINS", "http://localhost:3000,https://*.proxy.clode.space"), ",")
res := make([]*regexp.Regexp, 0, len(patterns))
for _, p := range patterns {
    res = append(res, regexp.MustCompile("^"+strings.ReplaceAll(strings.ReplaceAll(strings.TrimSpace(p), ".", `\.`), "*", ".*")+"$"))
}
router.Use(cors.New(cors.Config{
    AllowOriginFunc: func(origin string) bool { for _, r := range res { if r.MatchString(origin) { return true } }; return false },
}))
```

The localhost entry covers local development; the `https://*.proxy.clode.space` entry covers every tunnel-exposed origin. Both must be present in the default.

### Dev-server — accept `*.proxy.clode.space` host (env-driven)

Dev servers with a host whitelist reject the tunnel's Host header and return 403 unless the wildcard is registered. The host list reads from the same `ALLOWED_ORIGINS` env var as the backend CORS list — the framework config extracts the hostnames at startup. Every config emits `.proxy.clode.space` as the baseline so the wildcard is honored even before the env var is populated.

```js
// vite.config.{js,ts}  (React, Vue, Svelte)
import { defineConfig } from "vite";
const hosts = (process.env.ALLOWED_ORIGINS || "http://localhost:3000,https://*.proxy.clode.space")
  .split(",").map(s => { try { return new URL(s.trim()).hostname.replace(/^\*\./, "."); } catch { return s.trim(); } });
export default defineConfig({
  server:  { host: true, allowedHosts: hosts },
  preview: { host: true, allowedHosts: hosts },
});
```

```js
// next.config.{js,mjs}  (Next.js ≥14, dev mode)
const origins = (process.env.ALLOWED_ORIGINS || "http://localhost:3000,https://*.proxy.clode.space").split(",").map(s => s.trim());
export default { experimental: { allowedDevOrigins: origins.map(o => { try { return new URL(o).host; } catch { return o; } }) } };
```

| Other framework | Config (reads `ALLOWED_ORIGINS` the same way) |
|---|---|
| Webpack dev-server | `devServer.allowedHosts` ← hostnames extracted from `ALLOWED_ORIGINS` |
| Django | `ALLOWED_HOSTS = [urlparse(o).hostname.lstrip("*.") or o for o in os.environ["ALLOWED_ORIGINS"].split(",")]` |
| Rails | `ENV.fetch("ALLOWED_ORIGINS").split(",").each { |o| config.hosts << URI(o).host }` |

This rule applies to every dev server exposed via the tunnel — every full-stack / frontend task in this environment. The config above lands at build time; the env var override at runtime expands or replaces the list without code changes.

### docker-compose.yml — env vars must be listed bare (no value)

List the tunnel env vars without values in the `environment:` section. Docker compose will inherit them from the `--env-file` the local-deployer passes at runtime.

```yaml
services:
  frontend:
    environment:
      - VITE_API_URL          # injected by local-deployer at runtime
      - NODE_ENV=development  # static values still allowed
  api:
    environment:
      - ALLOWED_ORIGINS       # injected by local-deployer at runtime
      - DATABASE_URL          # can come from .env file
```

### .env.example — document with localhost defaults

```env
# Tunnel wiring — local-deployer overrides these with public proxy URLs at runtime.
# ALLOWED_ORIGINS always includes the proxy wildcard so any subdomain of
# proxy.clode.space can reach the service through the tunnel.
VITE_API_URL=http://localhost:8080
ALLOWED_ORIGINS=http://localhost:3000,https://*.proxy.clode.space
```

**Rule:** If any service in the project makes cross-origin HTTP calls from a browser, these env vars are mandatory. No exceptions.

---

## Datasource Connections

Every datasource (postgres, mysql, redis, mongodb, elasticsearch, kafka, rabbitmq, object stores) is wired into the service through a single env var named `<DATASOURCE>_HOST_URL` — `POSTGRES_HOST_URL`, `REDIS_HOST_URL`, `MONGO_HOST_URL`, etc.

The value arrives in HTTP form: `http://<host>:<port>`. Drivers expect their own scheme (`postgres://`, `redis://`, …) or raw host + port, so the service **must** parse the URL at startup and pass `hostname` + `port` to the driver. This step is mandatory for every datasource — there is no opt-out.

Centralize the parsing in one module per service (`src/db.js`, `app/db.py`, `internal/db/db.go`). All other code imports the configured client from there.

```js
// src/db.js
import { Pool } from "pg";
const u = new URL(process.env.POSTGRES_HOST_URL);
export const db = new Pool({
  host: u.hostname,
  port: Number(u.port),
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
  database: process.env.POSTGRES_DB,
});
```

```python
# app/db.py
import os, psycopg2
from urllib.parse import urlparse
u = urlparse(os.environ["POSTGRES_HOST_URL"])
db = psycopg2.connect(
    host=u.hostname, port=u.port,
    user=os.environ["POSTGRES_USER"],
    password=os.environ["POSTGRES_PASSWORD"],
    dbname=os.environ["POSTGRES_DB"],
)
```

```go
// internal/db/db.go
u, _ := url.Parse(os.Getenv("POSTGRES_HOST_URL"))
dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
    u.Hostname(), u.Port(),
    os.Getenv("POSTGRES_USER"),
    os.Getenv("POSTGRES_PASSWORD"),
    os.Getenv("POSTGRES_DB"))
```

The same pattern applies to every datasource the service depends on — caches, search indexes, message queues, object stores.

---

## Docker Compose Requirements

The `docker-compose.yml` is how your work gets validated. It must be complete and runnable.

**Required elements:**

1. **Health checks** on every service:
   ```yaml
   healthcheck:
     test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
     interval: 30s
     timeout: 10s
     retries: 3
     start_period: 10s
   ```

2. **Environment variables** via `.env` file:
   ```yaml
   env_file:
     - .env
   ```
   Never hardcode secrets or config values in `docker-compose.yml`.

3. **Named volumes** for persistent data:
   ```yaml
   volumes:
     postgres-data:
       driver: local
   ```
   Don't use anonymous volumes or bind mounts for data persistence.

4. **Port exposure** — explicit and documented:
   ```yaml
   ports:
     - "${API_PORT:-3000}:3000"
   ```
   Use env vars with defaults for host ports.

5. **Dependency ordering** with health conditions:
   ```yaml
   depends_on:
     db:
       condition: service_healthy
   ```

6. **Restart policy:**
   ```yaml
   restart: unless-stopped
   ```

7. **Network isolation** — use a named network:
   ```yaml
   networks:
     app-network:
       driver: bridge
   ```

**The `.env.example` file** must document every variable:
```env
# Datasources — host URL arrives in http(s):// form; code parses it
# (see "Datasource Connections"). One <NAME>_HOST_URL per datasource.
POSTGRES_HOST_URL=http://localhost:5432
POSTGRES_USER=app
POSTGRES_PASSWORD=changeme
POSTGRES_DB=appdb
# REDIS_HOST_URL=http://localhost:6379
# MONGO_HOST_URL=http://localhost:27017

# CORS / dev-server host whitelist — proxy wildcard is always included.
ALLOWED_ORIGINS=http://localhost:3000,https://*.proxy.clode.space

# API
API_PORT=3000
NODE_ENV=development
JWT_SECRET=changeme-in-production
```

## Task Completion Checklist

Before reporting a task as done, verify each item:

1. **Compilation/build** — code compiles or builds without errors
2. **Tests** — all tests run and pass (or failures are documented with reasons)
3. **Docker compose** — `docker compose up --build` starts all services successfully
4. **Health checks** — all services report healthy after startup
5. **Acceptance criteria** — every criterion from the task is met and verified
6. **Clean commits** — all changes committed with conventional commit messages
7. **Knowledge writes** — gotchas, patterns, or insights stored before completion
8. **Branch** — all work is on the correct feature/fix branch

Then report:
```
npx mcporter call aramb_tasks.update project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="done" summary="<what was built, what was verified>"
```
