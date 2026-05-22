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
- `project_id` — the Brahmi project this belongs to
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

### Backend — CORS allowed origins must be env-driven

Every backend must read its CORS allowed origins from `ALLOWED_ORIGINS` env var. Never hardcode `localhost` or any origin.

| Framework | Example |
|-----------|---------|
| Express (cors) | `origin: process.env.ALLOWED_ORIGINS?.split(",") ?? ["http://localhost:3000"]` |
| FastAPI | `allow_origins=os.environ.get("ALLOWED_ORIGINS", "http://localhost:3000").split(",")` |
| Django | `CORS_ALLOWED_ORIGINS = os.environ.get("ALLOWED_ORIGINS", "http://localhost:3000").split(",")` |
| Go (gin/echo) | `strings.Split(os.Getenv("ALLOWED_ORIGINS"), ",")` with localhost fallback |
| Rails | `origins(*ENV.fetch("ALLOWED_ORIGINS", "http://localhost:3000").split(","))` |

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
# Tunnel wiring — local-deployer overrides these with public proxy URLs at runtime
VITE_API_URL=http://localhost:8080
ALLOWED_ORIGINS=http://localhost:3000
```

**Rule:** If any service in the project makes cross-origin HTTP calls from a browser, these env vars are mandatory. No exceptions.

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
# Database
POSTGRES_USER=app
POSTGRES_PASSWORD=changeme
POSTGRES_DB=appdb
DB_PORT=5432

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
7. **Juno writes** — gotchas, patterns, or insights stored before completion
8. **Branch** — all work is on the correct feature/fix branch

Then report:
```
npx mcporter call aramb_tasks.update project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="done" summary="<what was built, what was verified>"
```
