---
name: aramb-metadata
description: Generate or update aramb.toml configuration file by analyzing docker-compose files or codebase. Use this skill when you need to create project metadata, service configurations, or environment setup for aramb-orchestrated projects.
category: development
tags: [metadata, configuration, docker, devops, analysis, toml]
license: MIT
---

# Aramb Metadata Generator

Analyze project structure and generate aramb.toml configuration with service definitions only. Uses APPLICATION_ID from environment variable.

## Inputs

- `requirements`: What metadata to generate or update
- `project_path`: Root directory to analyze (defaults to current directory)
- `validation_criteria`: Self-validation criteria (critical, expected, nice_to_have)

## Prerequisites

**CRITICAL**: APPLICATION_ID environment variable MUST be set:

```bash
if [ -z "$APPLICATION_ID" ]; then
  echo "ERROR: APPLICATION_ID environment variable not set"
  echo "Set it with: export APPLICATION_ID=your-app-id"
  exit 1
fi
```

## CRITICAL RULE: Build Service Separation

**When backend code needs to be built, you MUST create TWO services:**

### 1. Build Service (type="build") - Backend Only
- **Settings**: `repoUrl`, `buildPath`, `targetBranches`, `installationId = "123456789"` (dummy value)
- **Outputs**: `outputs.IMAGE_URL` (Docker images)
- **Excludes**: `image`, `cmd`, `commandPort`, `publicNet`, vars, secrets

### 2. Runtime Service (type="backend")
- **Settings**: `image` = `${buildServiceId.outputs.IMAGE_URL}`
- **Settings**: `cmd`, `commandPort`, `publicNet`
- **Includes**: vars, secrets as needed
- **Excludes**: `repoUrl`, `buildPath`, `targetBranches`, `installationId`

### Exceptions
- **Databases** (postgres, redis, mongodb) use `image` directly without build service
- **Pre-built containers** use `image` directly without build service
- **Frontend services** are created as single services (type="frontend") with static build configuration, NO separate build service

## Workflow

### 0. Validate APPLICATION_ID (CRITICAL FIRST STEP)

```bash
if [ -z "$APPLICATION_ID" ]; then
  echo "ERROR: APPLICATION_ID environment variable not set"
  echo "Set it with: export APPLICATION_ID=your-app-id"
  exit 1
fi

echo "Using APPLICATION_ID: $APPLICATION_ID"
```

### 1. Discover Services

**Docker Compose Analysis**:
- Search for docker-compose.yml, docker-compose.yaml, compose.yml
- Extract services, ports, environment variables, volumes, dependencies
- Identify database images (postgres:15, redis:7, mongo:6)

**Codebase Analysis** (ALWAYS required):
- **Environment files**: .env, .env.example, .env.production
- **Config files**: config.js, settings.py, application.yml, config.toml
- **Package files**: package.json, go.mod, requirements.txt, Cargo.toml
- **Source code**: Search for `process.env`, `os.Getenv()`, `os.environ`
- **Framework detection**: Express, FastAPI, Gin, Django, React, Vue, Angular, Next.js
- **Build files**: Dockerfile, Makefile, build scripts

### 2. Map Service Types

| Detected Pattern | Services to Create | Output |
|-----------------|-------------------|--------|
| Backend framework (Express, FastAPI, Gin, Django, etc.) | Build service (type="build")<br>Backend service (type="backend") | `outputs.IMAGE_URL` |
| Frontend framework (React, Vue, Angular, Next.js, etc.) | Single frontend service (type="frontend") | N/A |
| Microservice with Dockerfile | Build service (type="build")<br>Backend/template service | `outputs.IMAGE_URL` |
| Aramb agent code | Build service (type="build")<br>Aramb-agent service (type="aramb-agent") | `outputs.IMAGE_URL` |
| Database (postgres, redis, mongodb) | Single service with `image` field | N/A |
| Pre-built container | Single service with `image` field | N/A |

**Rules**:
- **Backend code to build**: TWO services (build + runtime)
- **Frontend code**: Single service (type="frontend") with static build configuration
- **Databases**: Single service with `image` only
- **Pre-built containers**: Single service with `image` only
- **Build service ID < Runtime service ID** (sequential ordering for backends)
- **Build services**: Auto-generate `installationId = "123456789"` (dummy value)

### 3. Extract Configuration

**Vars (Non-sensitive)**:
- Database: POSTGRES_DB, POSTGRES_USER, DB_HOST, DB_PORT
- Application: PORT, NODE_ENV, ENVIRONMENT, DEBUG, API_URL
- Configuration: TIMEOUT, MAX_CONNECTIONS, feature flags

**Secrets (Sensitive - leave empty)**:
- Passwords: POSTGRES_PASSWORD, DB_PASSWORD, MYSQL_PASSWORD
- Tokens: API_KEY, AUTH_TOKEN, JWT_SECRET, SECRET_KEY
- Credentials: PRIVATE_KEY, OAUTH_CLIENT_SECRET, SESSION_SECRET

**Secret Detection Keywords** (case-insensitive):
- Classify as **secret**: PASSWORD, PASSWD, PWD, SECRET, TOKEN, API_KEY, PRIVATE, CREDENTIAL, JWT, OAUTH
- Classify as **var**: HOST, PORT, URL, ENDPOINT, DATABASE, DB_NAME, DB_USER, ENVIRONMENT, DEBUG

**Service References**:
- Vars: `${uniqueIdentifier.vars.KEY}`
- Secrets: `${uniqueIdentifier.secrets.KEY}`
- Build outputs: `${uniqueIdentifier.outputs.IMAGE_URL}` or `${uniqueIdentifier.outputs.PATH}`

### 4. Generate TOML Structure

**CRITICAL**: Only create services. Do NOT create project or application sections.

**Build Services**: Always set `installationId = "123456789"` (dummy value for all build services)

```toml
# Example: Database Service (pre-built image)
[[services]]
uniqueIdentifier = 100
name = "postgres-db"
type = "postgres"
applicationID = "{applicationID}"  # From APPLICATION_ID env var

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

# Example: Backend Build Service
[[services]]
uniqueIdentifier = 101
name = "backend-build"
type = "build"
applicationID = "{applicationID}"  # From APPLICATION_ID env var

[services.configuration.settings]
repoUrl = "https://github.com/user/repo"
buildPath = "."
targetBranches = ["main"]
installationId = "123456789"  # Dummy value - auto-generated
# Outputs: outputs.IMAGE_URL

# Example: Backend Runtime Service
[[services]]
uniqueIdentifier = 102
name = "backend-api"
type = "backend"
applicationID = "{applicationID}"  # From APPLICATION_ID env var

[services.configuration.settings]
image = "${101.outputs.IMAGE_URL}"
cmd = "npm start"
commandPort = 8080
publicNet = true

[[services.configuration.vars]]
key = "PORT"
value = "8080"

[[services.configuration.vars]]
key = "DB_HOST"
value = "localhost"

[[services.configuration.vars]]
key = "DATABASE_URL"
value = "postgres://${100.vars.POSTGRES_USER}:${100.secrets.POSTGRES_PASSWORD}@localhost:5432/${100.vars.POSTGRES_DB}"

[[services.configuration.secrets]]
key = "JWT_SECRET"
value = ""

[[services.configuration.secrets]]
key = "DB_PASSWORD"
value = "${100.secrets.POSTGRES_PASSWORD}"

# Example: Frontend Service (Single Service - No Build Service)
[[services]]
uniqueIdentifier = 103
name = "frontend-web"
type = "frontend"
applicationID = "{applicationID}"  # From APPLICATION_ID env var

[services.configuration.settings]
staticPath = "./frontend/dist"  # Local build output directory
cmd = "npx http-server"
commandPort = 8080
publicNet = true

[[services.configuration.vars]]
key = "API_URL"
value = "http://localhost:8080"

[config_status]
status = "incomplete"
completed = []
incomplete = [100, 101, 102, 103]
message = "Build service (101) outputs IMAGE_URL for runtime service (102). Frontend (103) uses local static files. Fill in secrets (POSTGRES_PASSWORD, JWT_SECRET)."
```

### 5. Update Existing TOML

If aramb.toml exists:
- Read existing configuration
- Merge new services (avoid duplicates)
- Preserve existing uniqueIdentifiers
- Update config_status
- Mark incomplete if missing required secrets or installationId

## Constraints

### uniqueIdentifiers
- **Services**: 100, 101, 102, ... (sequential, no gaps, no duplicates)
- **Build service ID < Runtime service ID**

### APPLICATION_ID
- **MUST** be set in environment variable
- **MUST** exit with error if not found
- **MUST** use `applicationID = "{applicationID}"` in all services (replaced with actual APPLICATION_ID value)

### Service Types
- Supported: aramb-agent, backend, build, frontend, mongodb, onboarding, postgres, redis, template
- **Build service**: Always type="build"
- **Runtime service**: backend, frontend, aramb-agent, onboarding, template
- **Database**: postgres, redis, mongodb

### Settings Validation

**Build Service (type="build")** - Backend Only:
- **MUST have**: `repoUrl`, `buildPath`, `targetBranches`, `installationId = "123456789"` (auto-generated dummy value)
- **MUST NOT have**: `image`, `cmd`, `commandPort`, `publicNet`, vars, secrets

**Backend Runtime Service (type="backend")**:
- **MUST have**: `image` (reference to build output, e.g., `${101.outputs.IMAGE_URL}`)
- **MUST have**: `cmd`, `commandPort`
- **MUST NOT have**: `repoUrl`, `buildPath`, `targetBranches`, `installationId`
- **MUST have**: Corresponding build service with lower uniqueIdentifier

**Frontend Service (type="frontend")** - Single Service:
- **MUST have**: `staticPath` (local path to build output, e.g., "./frontend/dist")
- **MUST have**: `cmd`, `commandPort`
- **MUST NOT have**: `repoUrl`, `buildPath`, `targetBranches`, `installationId`, `image`
- **NO build service required** - frontend builds happen locally

**Database Service (postgres, redis, mongodb)**:
- **MUST have**: `image` (direct, e.g., "postgres:15")
- **MUST NOT have**: `repoUrl`, `buildPath`, `targetBranches`, `installationId`

**Pre-built Container Service**:
- **MUST have**: `image` (direct, e.g., "myorg/app:latest")
- **MUST NOT have**: `repoUrl`, `buildPath`, `targetBranches`, `installationId`

**NEVER**: Both `image` (direct) and `repoUrl` in same service

### Vars & Secrets
- Extract from codebase analysis (env files, config files, source code)
- Never hardcode sensitive values
- Leave secrets with empty values (`""`)
- Use service references to avoid duplication
- Services ordered by dependency (higher IDs depend on lower IDs)

## Self-Validation

**Critical checks** (MUST pass):
1. APPLICATION_ID environment variable is set
2. TOML syntax is valid
3. Structure complete: Only services (100+), NO project or application sections
4. Service types valid: aramb-agent, backend, build, frontend, mongodb, onboarding, postgres, redis, template
5. uniqueIdentifiers sequential: 100, 101, 102, ...
6. Required fields present (service: name, type, applicationID)
7. All services use `applicationID = "{applicationID}"` (literal string, will be replaced at runtime)
8. Build service pattern followed for backends:
   - Build services (type="build") have `repoUrl`, no `cmd`
   - Backend runtime services reference build outputs, no `repoUrl`
   - Build service ID < Backend runtime service ID
9. Frontend services (type="frontend"):
   - Have `staticPath` pointing to local build directory
   - NO separate build service required
   - Have `cmd` and `commandPort`
10. Database services have `image`, no `repoUrl`
11. Vars and secrets extracted from codebase (not empty)
12. Service references valid (`${N.vars.KEY}` points to existing service)
13. Secrets empty or use references (never hardcoded)

## Error Handling

- No services detected → Create minimal template with config_status="incomplete"
- Unknown service type → Use "template" as default
- Circular dependencies → Log warning, break cycle
- Docker-compose parsing fails → Fall back to codebase analysis

## Output

Return JSON summary:
```json
{
  "file_created": "aramb.toml",
  "application_id": "app-xyz789",
  "structure": {
    "services": 4
  },
  "services_detected": [
    {"uniqueIdentifier": 100, "name": "postgres-db", "type": "postgres", "applicationID": "{applicationID}"},
    {"uniqueIdentifier": 101, "name": "backend-build", "type": "build", "applicationID": "{applicationID}"},
    {"uniqueIdentifier": 102, "name": "backend-api", "type": "backend", "applicationID": "{applicationID}"},
    {"uniqueIdentifier": 103, "name": "frontend-web", "type": "frontend", "applicationID": "{applicationID}"}
  ],
  "build_outputs": {
    "101": "outputs.IMAGE_URL → service 102"
  },
  "frontend_static_builds": {
    "103": "staticPath: ./frontend/dist (local build)"
  },
  "vars_extracted": {
    "100": ["POSTGRES_DB", "POSTGRES_USER"],
    "102": ["PORT", "NODE_ENV", "DB_HOST", "DATABASE_URL"],
    "103": ["API_URL"]
  },
  "secrets_identified": {
    "100": ["POSTGRES_PASSWORD"],
    "102": ["JWT_SECRET", "DB_PASSWORD"]
  },
  "service_references": [
    "102 → 100 (DB vars/secrets)",
    "102 → 101 (IMAGE_URL)"
  ],
  "config_status": {
    "status": "incomplete",
    "incomplete_services": [100, 101, 102, 103],
    "reason": "Fill secrets: POSTGRES_PASSWORD, JWT_SECRET. Frontend (103) builds locally. Build service (101) has dummy installationId."
  },
  "validation_passed": true
}
```
