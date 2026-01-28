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

- Create complete aramb.toml with project, application, and services sections
- Analyze docker-compose files to identify services and extract image names
- **CRITICAL**: Thoroughly analyze codebase to extract vars and secrets:
  - Parse .env files, config files, source code for environment variables
  - Identify all configuration values used by the application
  - Classify as vars (non-sensitive) or secrets (sensitive)
- Map services to supported types: aramb-agent, backend, build, frontend, mongodb, onboarding, postgres, redis, template
- Generate settings section with required fields only (image for non-build services)
- Create service references using `${uniqueIdentifier.vars.KEY}` syntax
- Identify dependencies between services (higher IDs depend on lower IDs)

## Workflow

### 1. Discover Services

**Priority 1: Docker Compose Analysis**
- Search for docker-compose.yml, docker-compose.yaml, or compose.yml files
- Parse service definitions, ports, environment variables, volumes
- Identify service types from image names or build contexts
- Extract dependencies from `depends_on` directives
- Extract image names for database services (postgres:15, redis:7, mongo:6)

**Priority 2: Codebase Analysis (ALWAYS do this, even with docker-compose)**
- **Environment files**: .env, .env.example, .env.production
- **Config files**: config.js, settings.py, application.yml, config.toml
- **Package files**: package.json, go.mod, requirements.txt, Cargo.toml
- **Source code**: Search for `process.env`, `os.Getenv()`, `os.environ`, etc.
- **Framework detection**:
  - Backend: Express, FastAPI, Gin, Django, Rails, Spring Boot
  - Frontend: React, Vue, Angular, Next.js, Nuxt.js, Svelte
  - Database: PostgreSQL, MongoDB, Redis, MySQL connections
- **Build files**: Dockerfile, Makefile, build scripts

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

For each service, thoroughly analyze the codebase to extract:

**Vars (Non-sensitive configuration):**
- Database names, hosts, ports (POSTGRES_DB, POSTGRES_USER, DB_HOST, DB_PORT)
- API endpoints and URLs (API_URL, SERVICE_URL, BACKEND_URL)
- Port numbers (PORT, COMMANDPORT)
- Environment identifiers (NODE_ENV, ENVIRONMENT, DEBUG)
- Feature flags and configuration keys
- Connection pool settings, timeouts, etc.

**Secrets (Sensitive data - leave empty):**
- Passwords (POSTGRES_PASSWORD, DB_PASSWORD, MYSQL_PASSWORD)
- API keys and tokens (API_KEY, AUTH_TOKEN, JWT_SECRET, SECRET_KEY)
- Private keys and credentials (PRIVATE_KEY, CREDENTIALS)
- OAuth secrets (OAUTH_CLIENT_SECRET, GITHUB_TOKEN)
- Encryption keys (ENCRYPTION_KEY, SESSION_SECRET)

**Settings (Optional - only for customization):**
- `image`: REQUIRED for non-build services (postgres:15, redis:7, mongo:6)
- `repoUrl`: For services built from Git repositories
- `commandPort`: Service listening port (defaults applied if omitted)
- `publicNet`: Public network access (true/false)
- `cmd`: Custom start command
- Other fields: cpu, memory, restartPolicy, etc. (all have defaults)

**Service References:**
- Use `${uniqueIdentifier.vars.KEY}` to reference vars from other services
- Use `${uniqueIdentifier.secrets.KEY}` to reference secrets from other services

### 4. Generate TOML Structure

Create aramb.toml following this structure:

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

# Service 1: Database
[[services]]
uniqueIdentifier = 100
name = "postgres-db"
type = "postgres"
application = 10

[services.configuration]
  # Settings are OPTIONAL - only include image for non-build services
  [services.configuration.settings]
  image = "postgres:15"        # Required for non-build services
  commandPort = 5432           # Optional - defaults will be applied
  publicNet = false            # Optional

  # Vars - Non-sensitive configuration extracted from codebase
  [[services.configuration.vars]]
  key = "POSTGRES_DB"
  value = "myapp"

  [[services.configuration.vars]]
  key = "POSTGRES_USER"
  value = "postgres"

  # Secrets - Sensitive data left empty for user to fill
  [[services.configuration.secrets]]
  key = "POSTGRES_PASSWORD"
  value = ""

# Service 2: Backend API
[[services]]
uniqueIdentifier = 101
name = "api-backend"
type = "backend"
application = 10

[services.configuration]
  # For build services with repoUrl, image is optional
  [services.configuration.settings]
  repoUrl = "https://github.com/user/repo"  # If building from source
  buildPath = "."
  cmd = "npm start"
  commandPort = 8080
  publicNet = true
  targetBranches = ["main"]

  # Vars extracted from codebase analysis
  [[services.configuration.vars]]
  key = "PORT"
  value = "8080"

  [[services.configuration.vars]]
  key = "NODE_ENV"
  value = "production"

  [[services.configuration.vars]]
  key = "DB_HOST"
  value = "${100.vars.POSTGRES_DB}"    # Reference to postgres service

  [[services.configuration.vars]]
  key = "DB_USER"
  value = "${100.vars.POSTGRES_USER}"

  # Secrets with service references
  [[services.configuration.secrets]]
  key = "DB_PASSWORD"
  value = "${100.secrets.POSTGRES_PASSWORD}"

  [[services.configuration.secrets]]
  key = "JWT_SECRET"
  value = ""

[config_status]
status = "incomplete"
completed = []
incomplete = [100, 101]
message = "Services configured. Fill in empty secrets before deployment."
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

- **Project & Application**: Always create one project and one application that contains all services
- **uniqueIdentifiers**: Use 1 for project, 10 for application, 100+ for services (sequential)
- **Service Types**: Only use supported types: aramb-agent, backend, build, frontend, mongodb, onboarding, postgres, redis, template
- **Settings Section**: All fields are OPTIONAL with defaults applied, EXCEPT:
  - `image` is REQUIRED for non-build services (e.g., postgres, redis, mongodb)
  - For build services (with `repoUrl`), image is optional
- **Vars & Secrets**: CRITICAL - Extract from codebase analysis:
  - Database connections, API endpoints, ports, environment configs
  - NEVER hardcode sensitive values (passwords, API keys, tokens)
  - Leave secrets with empty values (`""`) for user to fill
- **Service References**: Use `${uniqueIdentifier.vars.KEY}` or `${uniqueIdentifier.secrets.KEY}` to avoid duplication
- **Dependencies**: Services are ordered by uniqueIdentifier (dependent services have higher IDs)

## Best Practices

### Codebase Analysis for Vars & Secrets

**1. Environment Files (.env, .env.example)**
```bash
# Parse .env.example to identify required configuration
DATABASE_URL=postgres://user:password@localhost:5432/dbname  # Extract var pattern
JWT_SECRET=your-secret-here                                   # Identify as secret
PORT=8080                                                     # Extract as var
```

Maps to:
- Vars: DB_HOST=localhost, DB_PORT=5432, DB_NAME=dbname, DB_USER=user, PORT=8080
- Secrets: DB_PASSWORD="", JWT_SECRET=""

**2. Configuration Files (config.js, settings.py, application.yml)**
```javascript
// Node.js config.js
module.exports = {
  port: process.env.PORT || 3000,           // Var: PORT=3000
  database: {
    host: process.env.DB_HOST || 'localhost',  // Var: DB_HOST=localhost
    password: process.env.DB_PASSWORD,         // Secret: DB_PASSWORD=""
  },
  jwtSecret: process.env.JWT_SECRET          // Secret: JWT_SECRET=""
}
```

**3. Docker Compose Files**
```yaml
services:
  db:
    image: postgres:15        # Settings: image="postgres:15", type="postgres"
    environment:
      POSTGRES_USER: postgres # Var: POSTGRES_USER=postgres
      POSTGRES_DB: myapp      # Var: POSTGRES_DB=myapp
      POSTGRES_PASSWORD: ${DB_PASSWORD}  # Secret: POSTGRES_PASSWORD=""
    ports:
      - "5432:5432"          # Settings: commandPort=5432
```

**4. Source Code Analysis**
```go
// Go main.go - Look for os.Getenv() calls
dbHost := os.Getenv("DB_HOST")           // Var: DB_HOST
dbPassword := os.Getenv("DB_PASSWORD")   // Secret: DB_PASSWORD
port := os.Getenv("PORT")                // Var: PORT
```

### Secret Detection Rules

Classify as **secret** if key name contains (case-insensitive):
- PASSWORD, PASSWD, PWD
- SECRET, TOKEN, KEY (but not PUBLIC_KEY for public keys)
- API_KEY, AUTH_TOKEN, ACCESS_TOKEN
- PRIVATE, CREDENTIAL, CREDENTIALS
- JWT, OAUTH, SESSION (when combined with SECRET/KEY)

Classify as **var** otherwise:
- HOST, PORT, URL, ENDPOINT
- DATABASE, DB_NAME, DB_USER
- ENVIRONMENT, NODE_ENV, DEBUG
- TIMEOUT, MAX_CONNECTIONS

### Service References & Dependencies

```toml
# Service 1: Postgres (uniqueIdentifier = 100)
[[services.configuration.vars]]
key = "POSTGRES_DB"
value = "myapp"

# Service 2: Backend (uniqueIdentifier = 101) references Service 1
[[services.configuration.vars]]
key = "DB_NAME"
value = "${100.vars.POSTGRES_DB}"    # References postgres service

[[services.configuration.secrets]]
key = "DB_PASSWORD"
value = "${100.secrets.POSTGRES_PASSWORD}"  # Shares secret from postgres

# Connection string construction
[[services.configuration.vars]]
key = "DATABASE_URL"
value = "postgres://${100.vars.POSTGRES_USER}:${100.secrets.POSTGRES_PASSWORD}@${100.vars.POSTGRES_HOST}:5432/${100.vars.POSTGRES_DB}"
```

### Settings: When to Include vs Omit

**Always Include (Required for non-build services):**
```toml
[services.configuration.settings]
image = "postgres:15"     # Required for postgres, redis, mongodb, etc.
```

**Include for Build Services:**
```toml
[services.configuration.settings]
repoUrl = "https://github.com/user/repo"  # For git-based builds
buildPath = "."
cmd = "npm start"
targetBranches = ["main"]
```

**Optional (defaults applied - only include if customizing):**
```toml
[services.configuration.settings]
cpu = 1000.0              # Default: reasonable allocation
memory = 512.0            # Default: reasonable allocation
publicNet = true          # Default: false for databases, true for web services
commandPort = 8080        # Default: service-specific
restartPolicy = "Always"  # Default: "Always"
```

## Self-Validation

Before completing, verify critical criteria:
1. **TOML syntax is valid** - Parse the generated TOML file with a TOML parser
2. **Structure is complete**:
   - One `[[project]]` section with uniqueIdentifier=1
   - One `[[application]]` section with uniqueIdentifier=10, project=1
   - One or more `[[services]]` sections with uniqueIdentifier starting from 100
3. **Service types are valid** - Check against: aramb-agent, backend, build, frontend, mongodb, onboarding, postgres, redis, template
4. **uniqueIdentifiers are correct**:
   - Project: 1
   - Application: 10
   - Services: 100, 101, 102, ... (sequential, no duplicates)
5. **Required fields present**:
   - Project: uniqueIdentifier, name
   - Application: uniqueIdentifier, name, project
   - Service: uniqueIdentifier, name, type, application
6. **Settings validation**:
   - Non-build services (postgres, redis, mongodb) have `image` field
   - Build services have `repoUrl` field
   - Optional fields are only included when needed
7. **Vars and secrets extracted from codebase** - Not just empty, but populated based on actual code analysis
8. **Service references are valid** - `${N.vars.KEY}` points to existing service uniqueIdentifier
9. **Secrets are empty or use references** - Never hardcoded sensitive values
10. **Application references** - All services reference the same application (uniqueIdentifier=10)

## Error Handling

- If no services detected, create minimal template with config_status.status = "incomplete"
- If service type cannot be determined, use "template" as default
- If dependencies form a cycle, log warning and break cycle
- If docker-compose parsing fails, fall back to codebase analysis

## Output

```json
{
  "file_created": "aramb.toml",
  "structure": {
    "projects": 1,
    "applications": 1,
    "services": 2
  },
  "services_detected": [
    {"uniqueIdentifier": 100, "name": "postgres-db", "type": "postgres"},
    {"uniqueIdentifier": 101, "name": "backend-api", "type": "backend"}
  ],
  "vars_extracted": {
    "100": ["POSTGRES_DB", "POSTGRES_USER"],
    "101": ["PORT", "NODE_ENV", "DB_HOST", "DATABASE_URL"]
  },
  "secrets_identified": {
    "100": ["POSTGRES_PASSWORD"],
    "101": ["JWT_SECRET", "DB_PASSWORD"]
  },
  "service_references": [
    "101 references 100 for DB_HOST, DATABASE_URL, DB_PASSWORD"
  ],
  "config_status": {
    "status": "incomplete",
    "incomplete_services": [100, 101],
    "reason": "Empty secrets need to be filled: POSTGRES_PASSWORD, JWT_SECRET"
  },
  "self_validation": {
    "critical_passed": true,
    "checks_run": [
      "TOML syntax valid",
      "Project and application structure correct",
      "Service types valid",
      "uniqueIdentifiers correct (1, 10, 100, 101)",
      "Service references valid",
      "Image field present for non-build services",
      "Vars and secrets extracted from codebase"
    ]
  }
}
```

## Examples

### Example 1: Docker Compose with Postgres + Backend

**Input**:
- docker-compose.yml with postgres and node backend
- .env.example with DATABASE_URL, JWT_SECRET, PORT

**Analysis**:
1. Detect postgres service (image: postgres:15)
2. Detect node backend service (build context)
3. Extract vars from .env.example: PORT=8080, DB_NAME=myapp
4. Extract secrets from .env.example: JWT_SECRET, DB_PASSWORD
5. Create service references for backend to use postgres vars/secrets

**Output**: aramb.toml
```toml
[[project]]
uniqueIdentifier = 1
name = "My Project"

[[application]]
uniqueIdentifier = 10
name = "My Application"
project = 1

[[services]]
uniqueIdentifier = 100
name = "postgres-db"
type = "postgres"
application = 10

[services.configuration]
  [services.configuration.settings]
  image = "postgres:15"

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
application = 10

[services.configuration]
  [services.configuration.settings]
  repoUrl = "https://github.com/user/backend"
  cmd = "npm start"
  commandPort = 8080
  targetBranches = ["main"]

  [[services.configuration.vars]]
  key = "PORT"
  value = "8080"

  [[services.configuration.vars]]
  key = "DB_HOST"
  value = "${100.vars.POSTGRES_HOST}"

  [[services.configuration.vars]]
  key = "DATABASE_URL"
  value = "postgres://${100.vars.POSTGRES_USER}:${100.secrets.POSTGRES_PASSWORD}@localhost:5432/${100.vars.POSTGRES_DB}"

  [[services.configuration.secrets]]
  key = "JWT_SECRET"
  value = ""

  [[services.configuration.secrets]]
  key = "DB_PASSWORD"
  value = "${100.secrets.POSTGRES_PASSWORD}"
```

### Example 2: Codebase Analysis (No Docker Compose)

**Input**:
- package.json (React frontend)
- go.mod (Gin backend)
- config/database.go (database connection code)

**Analysis**:
1. Detect React frontend from package.json dependencies
2. Detect Go backend from go.mod (github.com/gin-gonic/gin)
3. Parse config/database.go for DB environment vars
4. Extract vars: API_URL, PORT, DB_HOST, DB_PORT, DB_NAME
5. Extract secrets: API_KEY, DB_PASSWORD

**Output**: aramb.toml with frontend and backend services

### Example 3: Update Existing Configuration

**Input**:
- Existing aramb.toml with 2 services
- New Redis service added to docker-compose.yml

**Analysis**:
1. Read existing aramb.toml (preserve project, application, existing services)
2. Detect new Redis service (image: redis:7)
3. Assign next uniqueIdentifier = 102
4. Extract Redis vars from docker-compose environment

**Output**: Updated aramb.toml with 3 services, preserving existing configuration
