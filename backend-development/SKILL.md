---
name: backend-development
description: Build backend services, APIs, and server-side applications. Use this skill for creating REST/GraphQL APIs, database integrations, authentication systems, and server-side business logic in Go, Python, or Node.js.
category: development
tags: [backend, api, rest, golang, python, nodejs, database]
license: MIT
---

# Backend Development

Build APIs following project patterns. Implement proper validation, error handling, and security. Create Dockerfile and docker-compose.yml for containerization and deployment.

## Inputs

- `requirements`: What to build
- `files_to_create`: Files to create (including Dockerfile, docker-compose.yml)
- `files_to_modify`: Existing files to modify
- `patterns_to_follow`: Reference patterns in codebase
- `include_docker`: Whether to create Dockerfile and docker-compose.yml (default: true)
- `validation_criteria`: Self-validation criteria
  - `critical`: MUST pass before completing
  - `expected`: SHOULD pass (log warning if not)
  - `nice_to_have`: Optional improvements

## Constraints

- Always validate input data
- Use parameterized queries (never string concatenation for SQL)
- Follow OWASP security guidelines
- **Do NOT create documentation files** unless explicitly requested
- **Always create Dockerfile and docker-compose.yml** unless explicitly excluded

## Docker Containerization

When building backend services, create containerization files:

### Dockerfile

Create a multi-stage Dockerfile optimized for the language:

**Go:**
```dockerfile
# Build stage
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

# Runtime stage
FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/main .
EXPOSE 8080
CMD ["./main"]
```

**Python (FastAPI/Flask):**
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8080
CMD ["python", "main.py"]
```

**Node.js:**
```dockerfile
# Build stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Runtime stage
FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
EXPOSE 8080
CMD ["node", "server.js"]
```

### docker-compose.yml

Create a complete docker-compose.yml with all services:

```yaml
version: '3.8'

services:
  backend:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      - PORT=8080
      - NODE_ENV=production
    depends_on:
      - postgres
    networks:
      - app-network

  postgres:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=${POSTGRES_DB:-myapp}
      - POSTGRES_USER=${POSTGRES_USER:-postgres}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - app-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:

networks:
  app-network:
    driver: bridge
```

### Best Practices

1. **Multi-stage builds**: Reduce final image size
2. **Security**:
   - Run as non-root user
   - Use minimal base images (alpine, distroless)
   - Don't include secrets in images
3. **Optimization**:
   - Layer caching (copy dependency files first)
   - .dockerignore file (exclude node_modules, .git, etc.)
4. **Health checks**: Add health check endpoints and Docker health checks
5. **Environment variables**: Use env vars for configuration, never hardcode
6. **Volumes**: Persist data for databases
7. **Networks**: Isolate services in custom networks

## Self-Validation

Before completing, verify `validation_criteria.critical` items pass:
1. Run each critical check (e.g., `go build ./...`, `go test ./...`, start server)
2. Validate Docker setup:
   - `docker build -t backend:test .` - Dockerfile builds successfully
   - `docker-compose config` - docker-compose.yml syntax is valid
   - `docker-compose up -d` - All services start successfully
   - `docker-compose ps` - All services are running (healthy)
   - `docker-compose down` - Clean up test containers
3. If a check fails, fix and re-run
4. Only complete when all critical criteria pass

### Common Validation Criteria

**Critical checks** (must pass):
- Code compiles without errors
- Tests pass
- Database migrations run successfully
- Server starts and responds to health check
- **Dockerfile builds successfully**
- **docker-compose services start and are healthy**

**Expected checks** (should pass):
- Input validation implemented
- Error handling in place
- Authentication/authorization enforced
- Environment variables properly configured
- **Docker health checks configured**

**Nice to have**:
- Logging implemented
- Metrics/monitoring endpoints
- API documentation
- **Docker image optimized (multi-stage build)**

## Workflow

1. **Explore codebase**: Identify language, framework, existing patterns
2. **Implement feature**: Create/modify files following patterns
3. **Add validation**: Input validation, error handling, security checks
4. **Create Docker files**: Generate Dockerfile and docker-compose.yml
5. **Run tests**: Execute test suite
6. **Validate Docker**: Build image, start services, verify health
7. **Self-validate**: Run all critical checks from validation_criteria
8. **Output summary**: Report what was created and validation results

## Output

```json
{
  "files_created": [
    "internal/handlers/resource.go",
    "migrations/00X_create_resource.sql",
    "Dockerfile",
    "docker-compose.yml",
    ".dockerignore"
  ],
  "files_modified": ["internal/routes/routes.go"],
  "self_validation": {
    "critical_passed": true,
    "checks_run": [
      "Go compiles",
      "Tests pass",
      "Server starts",
      "Migrations run",
      "Dockerfile builds successfully",
      "docker-compose services start and healthy"
    ]
  },
  "docker": {
    "image_size": "45MB",
    "build_time": "2m15s",
    "services": ["backend", "postgres"],
    "all_healthy": true
  }
}
```

## Examples

### Example 1: REST API with Database

**Input:**
```json
{
  "requirements": "Create user management API with CRUD operations",
  "files_to_create": [
    "internal/handlers/users.go",
    "internal/models/user.go",
    "migrations/001_create_users.sql"
  ],
  "files_to_modify": ["internal/routes/routes.go"],
  "patterns_to_follow": "See internal/handlers/auth.go for handler pattern",
  "include_docker": true,
  "validation_criteria": {
    "critical": [
      "Code compiles",
      "Tests pass",
      "Migration runs",
      "API endpoints respond",
      "Dockerfile builds",
      "docker-compose starts services"
    ],
    "expected": [
      "Input validation",
      "Auth middleware applied",
      "Error handling"
    ],
    "nice_to_have": ["Logging", "Rate limiting"]
  }
}
```

**Output:**
- Creates user CRUD handlers
- Creates user model with validation
- Creates database migration
- Updates routes
- **Creates Dockerfile with multi-stage build**
- **Creates docker-compose.yml with backend + postgres**
- **Creates .dockerignore**
- Validates all services start and are healthy

### Example 2: GraphQL API

**Input:**
```json
{
  "requirements": "Build GraphQL API for product catalog",
  "files_to_create": [
    "graphql/schema.graphql",
    "graphql/resolvers/product.go",
    "internal/services/product_service.go"
  ],
  "include_docker": true,
  "validation_criteria": {
    "critical": [
      "GraphQL schema valid",
      "Resolvers work",
      "Docker build succeeds",
      "Services start"
    ]
  }
}
```

**Output:**
- Creates GraphQL schema
- Creates resolvers
- Creates service layer
- **Creates Dockerfile for Go GraphQL server**
- **Creates docker-compose.yml with backend + database + redis cache**
- Validates GraphQL queries work

### Example 3: Microservice with Message Queue

**Input:**
```json
{
  "requirements": "Build notification service with RabbitMQ consumer",
  "files_to_create": [
    "internal/consumer/notifications.go",
    "internal/services/email_service.go"
  ],
  "include_docker": true,
  "validation_criteria": {
    "critical": [
      "Consumer connects to RabbitMQ",
      "Messages processed",
      "Docker services communicate"
    ]
  }
}
```

**Output:**
- Creates RabbitMQ consumer
- Creates email service
- **Creates Dockerfile**
- **Creates docker-compose.yml with backend + rabbitmq + postgres**
- Validates message flow works
