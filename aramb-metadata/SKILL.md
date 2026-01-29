---
name: aramb-metadata
description: Generate or update aramb.toml configuration file by analyzing docker-compose files or codebase. Use this skill when you need to create project metadata, service configurations, or environment setup for aramb-orchestrated projects.
category: development
tags: [metadata, configuration, docker, devops, analysis, toml]
license: MIT
---

# Aramb Metadata Generator

Analyze project structure and generate aramb.toml configuration with service definitions, environment variables, and dependencies.

## Inputs

- `requirements`: What metadata to generate or update
- `project_path`: Root directory to analyze (defaults to current directory)
- `validation_criteria`: Self-validation criteria (critical, expected, nice_to_have)

## CRITICAL RULE: Build Service Separation

**When ANY code needs to be built (backend, frontend, microservices), you MUST create TWO services:**

### 1. Build Service (type="build")
- **Settings**: `repoUrl`, `buildPath`, `targetBranches`, `installationId`
- **Outputs**: `outputs.IMAGE_URL` (Docker images) OR `outputs.PATH` (static files)
- **Excludes**: `image`, `cmd`, `commandPort`, `publicNet`, vars, secrets

### 2. Runtime Service (type="backend"/"frontend"/etc.)
- **Settings**: `image` = `${buildServiceId.outputs.IMAGE_URL}` OR `staticPath` = `${buildServiceId.outputs.PATH}`
- **Settings**: `cmd`, `commandPort`, `publicNet`
- **Includes**: vars, secrets as needed
- **Excludes**: `repoUrl`, `buildPath`, `targetBranches`, `installationId`

### Exception
**Only** databases (postgres, redis, mongodb) and pre-built containers use `image` directly without build service.

## Workflow

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
| Frontend framework (React, Vue, Angular, Next.js, etc.) | Build service (type="build")<br>Frontend service (type="frontend") | `outputs.PATH` |
| Microservice with Dockerfile | Build service (type="build")<br>Backend/template service | `outputs.IMAGE_URL` |
| Aramb agent code | Build service (type="build")<br>Aramb-agent service (type="aramb-agent") | `outputs.IMAGE_URL` |
| Database (postgres, redis, mongodb) | Single service with `image` field | N/A |
| Pre-built container | Single service with `image` field | N/A |

**Rules**:
- **Any code to build**: TWO services (build + runtime)
- **Databases**: Single service with `image` only
- **Pre-built containers**: Single service with `image` only
- **Build service ID < Runtime service ID** (sequential ordering)

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

```toml
# Project Definition
[[project]]
uniqueIdentifier = 1
name = "Project Name"
description = "Auto-detected project"
tags = []

# Application Definition
[[application]]
uniqueIdentifier = 10
name = "Application Name"
project = 1
description = "Auto-detected application"
tags = []

# Example: Database Service (pre-built image)
[[services]]
uniqueIdentifier = 100
name = "postgres-db"
type = "postgres"
application = 10

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
application = 10

[services.configuration.settings]
repoUrl = "https://github.com/user/repo"
buildPath = "."
targetBranches = ["main"]
installationId = "123456"
# Outputs: outputs.IMAGE_URL

# Example: Backend Runtime Service
[[services]]
uniqueIdentifier = 102
name = "backend-api"
type = "backend"
application = 10

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

# Example: Frontend Build Service
[[services]]
uniqueIdentifier = 103
name = "frontend-build"
type = "build"
application = 10

[services.configuration.settings]
repoUrl = "https://github.com/user/repo"
buildPath = "frontend"
targetBranches = ["main"]
installationId = "123456"
# Outputs: outputs.PATH

# Example: Frontend Runtime Service
[[services]]
uniqueIdentifier = 104
name = "frontend-web"
type = "frontend"
application = 10

[services.configuration.settings]
staticPath = "${103.outputs.PATH}"
cmd = "npx http-server"
commandPort = 8080
publicNet = true

[[services.configuration.vars]]
key = "API_URL"
value = "http://localhost:8080"

[config_status]
status = "incomplete"
completed = []
incomplete = [100, 101, 102, 103, 104]
message = "Build services (101, 103) output artifacts for runtime services (102, 104). Fill in secrets and installationId."
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
- **Project**: 1
- **Application**: 10
- **Services**: 100, 101, 102, ... (sequential, no gaps, no duplicates)
- **Build service ID < Runtime service ID**

### Service Types
- Supported: aramb-agent, backend, build, frontend, mongodb, onboarding, postgres, redis, template
- **Build service**: Always type="build"
- **Runtime service**: backend, frontend, aramb-agent, onboarding, template
- **Database**: postgres, redis, mongodb

### Settings Validation

**Build Service (type="build")**:
- **MUST have**: `repoUrl`, `buildPath`, `targetBranches`, `installationId`
- **MUST NOT have**: `image`, `cmd`, `commandPort`, `publicNet`, vars, secrets

**Runtime Service (backend, frontend, etc.)**:
- **MUST have**: `image` (reference to build output) OR `staticPath` (for frontend)
- **MUST have**: `cmd`, `commandPort`
- **MUST NOT have**: `repoUrl`, `buildPath`, `targetBranches`, `installationId`
- **MUST have**: Corresponding build service with lower uniqueIdentifier

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
1. TOML syntax is valid
2. Structure complete: One project (ID=1), one application (ID=10), services (100+)
3. Service types valid: aramb-agent, backend, build, frontend, mongodb, onboarding, postgres, redis, template
4. uniqueIdentifiers sequential: 1, 10, 100, 101, 102, ...
5. Required fields present (project: name; application: name, project; service: name, type, application)
6. Build service pattern followed:
   - Build services have `repoUrl`, no `cmd`
   - Runtime services reference build outputs, no `repoUrl`
   - Build service ID < Runtime service ID
7. Database services have `image`, no `repoUrl`
8. Vars and secrets extracted from codebase (not empty)
9. Service references valid (`${N.vars.KEY}` points to existing service)
10. Secrets empty or use references (never hardcoded)

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
  "structure": {
    "projects": 1,
    "applications": 1,
    "services": 5
  },
  "services_detected": [
    {"uniqueIdentifier": 100, "name": "postgres-db", "type": "postgres"},
    {"uniqueIdentifier": 101, "name": "backend-build", "type": "build"},
    {"uniqueIdentifier": 102, "name": "backend-api", "type": "backend"},
    {"uniqueIdentifier": 103, "name": "frontend-build", "type": "build"},
    {"uniqueIdentifier": 104, "name": "frontend-web", "type": "frontend"}
  ],
  "build_outputs": {
    "101": "outputs.IMAGE_URL → service 102",
    "103": "outputs.PATH → service 104"
  },
  "vars_extracted": {
    "100": ["POSTGRES_DB", "POSTGRES_USER"],
    "102": ["PORT", "NODE_ENV", "DB_HOST", "DATABASE_URL"],
    "104": ["API_URL"]
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
    "incomplete_services": [100, 101, 102, 103, 104],
    "reason": "Fill secrets: POSTGRES_PASSWORD, JWT_SECRET. Add installationId to build services."
  },
  "validation_passed": true
}
```
