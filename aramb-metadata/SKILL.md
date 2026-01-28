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
- `validation_criteria`: Self-validation criteria
  - `critical`: MUST pass before completing
  - `expected`: SHOULD pass (log warning if not)
  - `nice_to_have`: Optional improvements

## Responsibilities

- Analyze docker-compose files to identify services
- Extract service configurations, ports, environment variables
- Identify dependencies between services
- Generate or update aramb.toml with proper structure
- Map services to supported types: aramb-agent, backend, build, frontend, mongodb, onboarding, postgres, redis, template
- Handle both vars (non-sensitive) and secrets (sensitive) configuration

## Workflow

### 1. Discover Services

**Priority 1: Docker Compose Analysis**
- Search for docker-compose.yml, docker-compose.yaml, or compose.yml files
- Parse service definitions, ports, environment variables, volumes
- Identify service types from image names or build contexts
- Extract dependencies from `depends_on` directives

**Priority 2: Codebase Analysis (if no docker-compose)**
- Search for Dockerfile, package.json, go.mod, requirements.txt, etc.
- Identify backend frameworks (Express, FastAPI, Gin, etc.)
- Identify frontend frameworks (React, Vue, Next.js, etc.)
- Look for database connection strings or imports
- Check for test configurations or build scripts

### 2. Map Service Types

Map discovered services to supported types:

| Detected Pattern | Service Type |
|-----------------|--------------|
| postgres:* image, PostgreSQL | postgres |
| mongo:* image, MongoDB | mongodb |
| redis:* image, Redis | redis |
| Frontend framework (React, Vue) | frontend |
| Backend framework (Express, FastAPI, Gin) | backend |
| Dockerfile with build context | build |
| aramb-agent specific | aramb-agent |
| Onboarding/setup scripts | onboarding |
| Generic service | template |

### 3. Extract Configuration

For each service, extract:
- **Vars**: Non-sensitive configuration (HOST, PORT, DATABASE_NAME, etc.)
- **Secrets**: Sensitive data (PASSWORD, API_KEY, TOKEN, etc.)
- **Dependencies**: Services this depends on (using uniqueIdentifier references)
- **Detection source**: Files where service was detected

### 4. Generate TOML Structure

Create aramb.toml following this structure:

```toml
[[services]]
uniqueIdentifier = 1
name = "postgres-db"
type = "postgres"

[services.configuration]
[[services.configuration.vars]]
key = "POSTGRES_HOST"
value = "db"

[[services.configuration.vars]]
key = "POSTGRES_PORT"
value = "5432"

[[services.configuration.secrets]]
key = "POSTGRES_PASSWORD"
value = ""

[services.generated]
detected_from = ["docker-compose.yml", "Dockerfile"]
dependencies = []

[[services]]
uniqueIdentifier = 2
name = "api-backend"
type = "backend"

[services.configuration]
[[services.configuration.vars]]
key = "PORT"
value = "8080"

[[services.configuration.vars]]
key = "DB_HOST"
value = "${1.vars.POSTGRES_HOST}"

[[services.configuration.secrets]]
key = "DB_PASSWORD"
value = "${1.secrets.POSTGRES_PASSWORD}"

[services.generated]
detected_from = ["docker-compose.yml", "cmd/api/main.go"]
dependencies = [1]

[config_status]
status = "complete"
completed = [1, 2]
incomplete = []
message = "All services detected and configured successfully."
```

### 5. Handle Service References

Support cross-service references using `${uniqueIdentifier.type.KEY}` format:
- `${1.vars.POSTGRES_HOST}` - Reference var from service 1
- `${1.secrets.POSTGRES_PASSWORD}` - Reference secret from service 1
- Used for DB_HOST, DB_PASSWORD, and connection string construction

### 6. Update Existing TOML

If aramb.toml exists:
- Read existing configuration
- Merge new services (don't duplicate)
- Preserve existing uniqueIdentifiers
- Update config_status appropriately
- Mark new services as incomplete if missing required secrets

## Constraints

- NEVER hardcode sensitive values (passwords, API keys, tokens)
- Leave secrets with empty values for user to fill
- Use service references (${N.vars.KEY}) instead of duplicating values
- Assign sequential uniqueIdentifiers starting from 1
- Mark services as incomplete if they have empty secrets
- Only use supported service types
- Always include detected_from sources

## Best Practices

### Docker Compose Parsing

```python
# Example: Extract from docker-compose.yml
services:
  db:
    image: postgres:15
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${DB_PASSWORD}  # Secret
      POSTGRES_DB: myapp                 # Var
```

Maps to:
- name: "postgres-db" (or use service key "db")
- type: "postgres"
- vars: POSTGRES_USER, POSTGRES_DB
- secrets: POSTGRES_PASSWORD

### Dependency Detection

```python
# Service B depends on Service A if:
# 1. docker-compose depends_on: [service-a]
# 2. Environment vars reference service A (DB_HOST=postgres-db)
# 3. Network connections to service A's port
```

### Secret Detection

Classify as secret if key contains:
- PASSWORD, PASSWD, PWD
- SECRET, TOKEN, KEY
- API_KEY, AUTH_TOKEN
- PRIVATE, CREDENTIAL

### Connection String Construction

```toml
[[services.configuration.vars]]
key = "DB_DSN"
value = "postgres://${1.vars.POSTGRES_USER}:${1.secrets.POSTGRES_PASSWORD}@${1.vars.POSTGRES_HOST}:${1.vars.POSTGRES_PORT}/${1.vars.POSTGRES_DB}?sslmode=disable"
```

## Self-Validation

Before completing, verify critical criteria:
1. **TOML is valid** - Parse the generated TOML to ensure syntax correctness
2. **All services have valid types** - Check against supported service types
3. **No duplicate uniqueIdentifiers** - Each must be unique
4. **Service references are valid** - ${N.vars.KEY} points to existing service
5. **Dependencies are ordered** - Service N cannot depend on service M where M > N
6. **Required fields present** - Each service has name, type, configuration
7. **Secrets are empty or use references** - Never hardcoded values

## Error Handling

- If no services detected, create minimal template with config_status.status = "incomplete"
- If service type cannot be determined, use "template" as default
- If dependencies form a cycle, log warning and break cycle
- If docker-compose parsing fails, fall back to codebase analysis

## Output

```json
{
  "file_created": "aramb.toml",
  "services_detected": 2,
  "services_configured": {
    "complete": [1],
    "incomplete": [2],
    "incomplete_reason": "Service 2 has empty secrets that need to be filled"
  },
  "self_validation": {
    "critical_passed": true,
    "checks_run": [
      "TOML syntax valid",
      "Service types valid",
      "No duplicate IDs",
      "Dependencies valid"
    ]
  }
}
```

## Examples

### Example 1: Docker Compose with Postgres + Backend

**Input**: docker-compose.yml with postgres and node backend

**Output**: aramb.toml with 2 services, backend depends on postgres, connection string uses references

### Example 2: Monorepo with Frontend + Backend

**Input**: No docker-compose, but package.json (React) and go.mod (Gin)

**Output**: aramb.toml with frontend and backend services, no dependencies

### Example 3: Update Existing Configuration

**Input**: aramb.toml exists with 2 services, new Redis service added to docker-compose

**Output**: Updated aramb.toml with 3 services, preserving existing configuration
