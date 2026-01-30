---
name: local-deploy
description: Build and deploy services locally using aramb.toml. Use this when you need to build Docker images locally, build frontend static files, and deploy all services via TOML configuration. Triggered by requests like "deploy locally", "build and deploy everything", "local deployment", or "deploy using aramb.toml".
category: deployment
tags: [deployment, build, docker, frontend, backend, local, devops]
license: MIT
---

# Local Deploy

Orchestrate local builds and deployments using aramb-cli and aramb.toml.

## Role

You are a deployment orchestrator that builds Docker images and static files locally, then deploys services via aramb.toml configuration.

## Responsibilities

- Validate environment (aramb-cli, env vars, aramb.toml)
- Parse aramb.toml to identify services and dependencies
- Build Docker images for backend services locally
- Build static files for frontend services locally
- Update service configurations with build artifacts
- Deploy all services via `aramb deploy --deploy-from-toml`
- Validate deployments are successful

## Constraints

- **MUST** have aramb-cli installed: `go install github.com/aramb-dev/aramb-cli/cmd/aramb@latest`
- **MUST** have aramb.toml in project root (use aramb-metadata skill to create)
- **MUST** validate BUILDKIT_HOST and ARAMB_API_TOKEN before starting
- **Do NOT** push to registry unless `push_registry: true`
- **Do NOT** create or modify aramb.toml structure
- **Do NOT** skip validation steps

## Inputs

- `project_path`: Root directory containing aramb.toml (default: current directory)
- `services`: Comma-separated service names to deploy (default: all services)
- `skip_build`: Skip build step and only deploy (default: false)
- `push_registry`: Push images to registry after building (default: false)

## Workflow

### 1. Validate Environment

```bash
# Check aramb-cli installed
command -v aramb || go install github.com/aramb-dev/aramb-cli/cmd/aramb@latest

# Verify required environment variables
[ -n "$BUILDKIT_HOST" ] || exit 1
[ -n "$ARAMB_API_TOKEN" ] || exit 1

# Confirm aramb.toml exists
[ -f "aramb.toml" ] || exit 1
```

### 2. Parse aramb.toml

Read aramb.toml and identify:
- **Build services** (type="build") - Backend builds only
- **Backend services** (type="backend") - Depend on build services
- **Frontend services** (type="frontend") - Single service, no separate build
- **Database services** (postgres/redis/mongodb) - Pre-built images

Map relationships:
- Build service outputs → Backend runtime service inputs
- Frontend staticPath → Local build directory

### 3. Build Backend Services

For each backend build service:

```bash
cd <buildPath>
aramb build --name <service-name> --tag <commit-sha>

# Optional: Push to registry
if [ "$push_registry" = true ]; then
  aramb build --name <service-name> --tag <commit-sha> --push
fi
```

**Output**: Docker image `<service-name>:<commit-sha>`

### 4. Build Frontend Services

For each frontend service (type="frontend"):

```bash
# Determine framework and build
aramb build --static-outdir ./dist
```

**Supported frameworks**: Next.js, React, Vue, Angular, Vite

**Output**: Static files in `./dist` (or framework-specific directory)

### 5. Update Service Configurations

Create temporary updated aramb.toml:

**Backend services**:
```toml
[services.configuration.settings]
image = "<service-name>:<commit-sha>"  # From local build
```

**Frontend services**:
```toml
[services.configuration.settings]
staticPath = "/absolute/path/to/dist"  # From local build
```

### 6. Deploy All Services

```bash
aramb deploy --deploy-from-toml
```

Deploys services in dependency order:
1. Databases (no build required)
2. Backend services (with built images)
3. Frontend services (with static paths)

### 7. Validate Deployment

```bash
# Check deployment status
aramb deploy status --loop --interval 5

# Verify all services healthy
aramb deploy history --limit 10
```

## Service Type Handling

### Build Services (type="build") - Backend Only

**Skip deployment**: Build services produce outputs, not deployed directly

```bash
cd <buildPath>
aramb build --name backend-api --tag abc123
```

**Output**: `IMAGE_URL` consumed by backend runtime service

### Backend Runtime Services (type="backend")

**Process**:
1. Build service creates Docker image
2. Update `image` field with local image name
3. Deploy via TOML

```toml
[[services]]
uniqueIdentifier = 102
name = "backend-api"
type = "backend"

[services.configuration.settings]
image = "backend-api:abc123"  # Updated from build
cmd = "npm start"
commandPort = 8080
publicNet = true
```

### Frontend Services (type="frontend") - Single Service

**No separate build service**. Frontend is single service with local build.

**Process**:
1. Build static files locally
2. Update `staticPath` with absolute path
3. Deploy via TOML

```toml
[[services]]
uniqueIdentifier = 103
name = "frontend-web"
type = "frontend"

[services.configuration.settings]
staticPath = "/home/user/project/frontend/dist"  # Updated from build
cmd = "npx http-server"
commandPort = 8080
publicNet = true
```

### Database Services (postgres/redis/mongodb)

**No build required**. Use pre-built images directly.

```toml
[[services]]
uniqueIdentifier = 100
name = "postgres-db"
type = "postgres"

[services.configuration.settings]
image = "postgres:15"
commandPort = 5432
publicNet = false
```

## Validation Criteria

### Critical (MUST pass)

- aramb-cli accessible in PATH
- BUILDKIT_HOST environment variable set
- ARAMB_API_TOKEN environment variable set
- aramb.toml exists and valid
- All backend builds succeed
- All frontend builds succeed
- Deployment completes without errors
- All services report healthy status

### Expected (SHOULD pass)

- Build artifacts correctly passed to runtime services
- Service references properly resolved
- Environment variables configured in services
- Services start in dependency order

### Nice to Have

- Build process optimized (caching, parallel builds)
- Deployment history logged
- Service metrics available

## Output

Report build and deployment results:

```json
{
  "status": "success",
  "builds": {
    "backend": [
      {
        "service": "backend-api",
        "build_service": "backend-build",
        "image": "backend-api:abc123",
        "build_time": "45s",
        "status": "success"
      }
    ],
    "frontend": [
      {
        "service": "frontend-web",
        "output_path": "/home/user/project/frontend/dist",
        "build_time": "30s",
        "status": "success"
      }
    ]
  },
  "deployments": {
    "successful": ["postgres-db", "backend-api", "frontend-web"],
    "failed": []
  },
  "total_time": "2m15s"
}
```

## Error Handling

### Build Failures

If build fails:
1. Log error with service name and build output
2. Continue with independent builds
3. Skip deployment for failed services
4. Report summary of successes and failures

### Deployment Failures

If deployment fails:
1. Log error with service name and deployment details
2. Do NOT rollback automatically
3. Provide rollback instructions
4. Display: `aramb deploy history --service <name>`

### Missing Dependencies

If environment invalid:
1. List all missing requirements clearly
2. Provide setup instructions (see [references/installation.md](references/installation.md))
3. Exit before starting builds

## Usage Examples

### Deploy All Services

```bash
# Build and deploy everything
/local-deploy
```

### Deploy Specific Services

```bash
# Build and deploy only specified services
/local-deploy --services backend-api,frontend-web
```

### Deploy Without Building

```bash
# Skip build, only deploy existing artifacts
/local-deploy --skip-build
```

### Build and Push to Registry

```bash
# Build, push to registry, then deploy
/local-deploy --push-registry
```

### Custom Project Path

```bash
# Deploy from specific directory
/local-deploy --project-path /path/to/project
```

## Integration with Other Skills

### With aramb-metadata

1. First, generate configuration:
   ```bash
   /aramb-metadata
   ```
   Creates aramb.toml with build and runtime services

2. Then, deploy locally:
   ```bash
   /local-deploy
   ```
   Builds and deploys using generated configuration

### Typical Workflow

```
User Request
    ↓
/aramb-metadata (creates aramb.toml)
    ↓
/local-deploy (builds and deploys)
    ↓
Services Running
```

## Best Practices

1. **Run aramb-metadata first** to generate or update aramb.toml
2. **Verify environment** before starting deployment
3. **Use version tags** for reproducible deployments
4. **Monitor deployment status** until all services healthy
5. **Keep aramb.toml in version control** for team collaboration
6. **Test locally** before pushing to production

## Advanced Usage

For advanced topics, see reference documentation:

- **Installation**: [references/installation.md](references/installation.md) - aramb-cli setup
- **Troubleshooting**: [references/troubleshooting.md](references/troubleshooting.md) - Common issues
- **Advanced**: [references/advanced.md](references/advanced.md) - Registry config, optimization

## See Also

- **aramb-metadata**: Generate aramb.toml configuration
- **backend-development**: Build backend services with Dockerfile
- **frontend-development**: Build frontend applications
- **BUILD_DEPLOY.md**: Detailed aramb-cli command reference
