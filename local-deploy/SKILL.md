---
name: local-deploy
description: Build and deploy services locally. Builds Docker images and static frontend applications on the local machine, then deploys backend services via aramb.toml configuration and frontend services to their respective destinations.
category: deployment
tags: [deployment, build, docker, frontend, backend, local, devops]
license: MIT
---

# Local Deploy

Build and deploy all services locally with automatic image passing to backend services and static file deployment for frontends.

## Overview

This skill orchestrates a complete local build and deployment workflow:

1. **Backend Services**: Build Docker images locally → Pass to runtime services → Deploy via TOML
2. **Frontend Services**: Build static files locally → Update staticPath in service configuration → Deploy via TOML
3. **Coordinated Deployment**: Use aramb.toml for service orchestration

**Note**: Frontend services are configured as single services (no separate build service). Local builds update the `staticPath` field directly.

## Inputs

- `project_path`: Root directory containing aramb.toml (defaults to current directory)
- `services`: Comma-separated service names to deploy (defaults to all services)
- `skip_build`: Skip build step and only deploy (default: false)
- `push_registry`: Push images to registry after building (default: false)

## Prerequisites

**Required Tools:**
- **Go 1.21+** - Required to install aramb-cli
- **Docker** - For building images
- **BuildKit** - For advanced Docker builds

**Install aramb-cli:**
```bash
# Install aramb-cli using go install
go install github.com/aramb-dev/aramb-cli/cmd/aramb@latest

# Verify installation
aramb --version

# Ensure $GOPATH/bin is in your PATH
export PATH=$PATH:$(go env GOPATH)/bin
```

**Required Environment Variables:**
- `BUILDKIT_HOST` - BuildKit server endpoint (for Docker builds)
- `ARAMB_API_TOKEN` - API token for Aramb services
- `ARAMB_SERVICE_ID` - Service ID for deployment tracking

**Optional Environment Variables:**
- `DOCKER_REGISTRY` - Docker registry URL
- `DOCKER_USERNAME` - Docker registry username
- `DOCKER_PASSWORD` - Docker registry password
- `JUMBO_URL` - Jumbo API endpoint (default: https://jumbo.aramb.dev)
- `HATHI_URL` - Hathi API endpoint (default: https://hathi.aramb.dev)

**Required Files:**
- `aramb.toml` - Service configuration file (use aramb-metadata skill to generate)

## Quick Setup

Before using this skill for the first time:

```bash
# 1. Install Go (if not already installed)
# Ubuntu/Debian:
sudo apt-get update && sudo apt-get install -y golang

# macOS:
brew install go

# 2. Install aramb-cli
go install github.com/aramb-dev/aramb-cli/cmd/aramb@latest

# 3. Add GOPATH/bin to PATH
echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc
source ~/.bashrc

# 4. Set required environment variables
export BUILDKIT_HOST="tcp://your-buildkit-host:1234"
export ARAMB_API_TOKEN="your-api-token"
export ARAMB_SERVICE_ID="your-service-id"

# 5. Generate aramb.toml (if not exists)
# Use the aramb-metadata skill: /aramb-metadata

# 6. Verify setup
aramb --version
docker version
echo $BUILDKIT_HOST
```

## Workflow

### 1. Parse aramb.toml Configuration

Read and validate the aramb.toml file:
- Identify all services in the configuration
- Separate build services (type="build") from runtime services (backend only)
- Map backend build service outputs to backend runtime service inputs
- Identify frontend services (type="frontend") for static builds (no separate build service)

### 2. Build Backend Services Locally

For each backend build service:

```bash
# Navigate to build path
cd <buildPath>

# Build Docker image locally
aramb build --name <service-name> --tag <commit-sha>

# Optional: Push to registry if flag is set
aramb build --name <service-name> --tag <commit-sha> --push
```

**Outputs:**
- Local Docker image: `<service-name>:<commit-sha>`
- Registry path (if pushed): `${DOCKER_REGISTRY}/<service-name>:<commit-sha>`

### 3. Build Frontend Services Locally

For each frontend service (type="frontend"):

```bash
# Navigate to frontend directory (extracted from staticPath)
cd <frontend-directory>

# Detect framework and build to appropriate output directory
aramb build --static-outdir ./dist
```

**Supported Frameworks:**
- Next.js → `out/`
- Create React App → `build/`
- Vite (React/Vue) → `dist/`
- Vue CLI → `dist/`
- Angular → `dist/`
- Generic (npm build) → `dist/`

**Outputs:**
- Static build directory: `./dist` (or framework-specific)

**Note**: Frontend services have NO separate build service. The staticPath in the frontend service configuration points directly to the local build output.

### 4. Update Runtime Service Configurations

Before deployment, update aramb.toml with built artifacts:

**Backend Runtime Services:**
```toml
[services.configuration.settings]
# Update image reference to locally built image
image = "<service-name>:<commit-sha>"
# OR if pushed to registry:
image = "${DOCKER_REGISTRY}/<service-name>:<commit-sha>"
```

**Frontend Runtime Services:**
```toml
[services.configuration.settings]
# Update static path to built files
staticPath = "<absolute-path-to-dist>"
```

### 5. Deploy via TOML

Deploy all services using the updated configuration:

```bash
aramb deploy --deploy-from-toml
```

This command:
- Reads the updated aramb.toml
- Deploys all services with their configurations
- Uses locally built images for backend services
- Uses local static files for frontend services

## Service Type Handling

### Build Services (type="build") - Backend Only

**Skip Direct Deployment:**
- Build services are NOT deployed directly
- They produce outputs (IMAGE_URL) consumed by backend runtime services
- Build happens locally, not on Aramb infrastructure
- **Only used for backend services**

**Example Build Service:**
```toml
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
```

**Local Build Process:**
1. Clone/pull repository (if needed)
2. Navigate to buildPath
3. Execute: `aramb build --name backend-api --tag <sha>`
4. Capture image name for runtime service

### Backend Runtime Services (type="backend")

**Deployment Process:**
1. Update `image` field with locally built image
2. Deploy via `aramb deploy --deploy-from-toml`

**Example Runtime Service:**
```toml
[[services]]
uniqueIdentifier = 102
name = "backend-api"
type = "backend"
application = 10

[services.configuration.settings]
image = "backend-api:abc123"  # Updated from local build
cmd = "npm start"
commandPort = 8080
publicNet = true
```

### Frontend Services (type="frontend") - Single Service

**No Separate Build Service:**
- Frontend services are configured as single services
- NO separate build service (type="build") is created
- Build happens locally, staticPath points directly to build output

**Deployment Process:**
1. Build frontend locally to output directory (e.g., ./dist)
2. Update `staticPath` with absolute path to build output
3. Deploy via `aramb deploy --deploy-from-toml`

**Example Frontend Service:**
```toml
[[services]]
uniqueIdentifier = 103
name = "frontend-web"
type = "frontend"
application = 10

[services.configuration.settings]
staticPath = "/home/user/project/frontend/dist"  # Updated from local build
cmd = "npx http-server"
commandPort = 8080
publicNet = true

[[services.configuration.vars]]
key = "API_URL"
value = "http://localhost:8080"
```

### Database Services (type="postgres", "redis", "mongodb")

**No Build Required:**
- Use pre-built images directly
- Deploy via TOML without modification

**Example Database Service:**
```toml
[[services]]
uniqueIdentifier = 100
name = "postgres-db"
type = "postgres"
application = 10

[services.configuration.settings]
image = "postgres:15"
commandPort = 5432
publicNet = false
```

## Execution Steps

### Step 1: Validate Environment

```bash
# Check if aramb-cli is installed
if ! command -v aramb &> /dev/null; then
  echo "Error: aramb-cli not found. Installing..."
  go install github.com/aramb-dev/aramb-cli/cmd/aramb@latest

  # Verify installation succeeded
  if ! command -v aramb &> /dev/null; then
    echo "Error: Failed to install aramb-cli. Ensure Go is installed and GOPATH/bin is in PATH"
    exit 1
  fi
fi

# Verify aramb-cli version
aramb --version

# Check required environment variables
if [ -z "$BUILDKIT_HOST" ]; then
  echo "Error: BUILDKIT_HOST not set"
  exit 1
fi

if [ -z "$ARAMB_API_TOKEN" ]; then
  echo "Error: ARAMB_API_TOKEN not set"
  exit 1
fi

# Verify aramb.toml exists
if [ ! -f "aramb.toml" ]; then
  echo "Error: aramb.toml not found. Use /aramb-metadata to generate it."
  exit 1
fi
```

### Step 2: Parse and Plan

```bash
# Read aramb.toml
# Extract all services
# Group by type: build, backend, frontend, database
# Create build plan with dependencies
```

### Step 3: Execute Builds

```bash
# For each backend build service:
cd <buildPath>
aramb build --name <service-name> --tag <commit-sha>

# For each frontend build service:
cd <buildPath>
aramb build --static-outdir ./dist
```

### Step 4: Update Configuration

```bash
# Create temporary aramb.toml with updated references
cp aramb.toml aramb.toml.backup

# Update backend runtime services with built images
# Update frontend runtime services with static paths

# Validate updated configuration
```

### Step 5: Deploy All Services

```bash
# Deploy using updated configuration
aramb deploy --deploy-from-toml

# Monitor deployment status
aramb deploy status --loop --interval 5
```

### Step 6: Cleanup

```bash
# Restore original aramb.toml if needed
# Remove temporary files
# Display deployment summary
```

## Error Handling

### Build Failures

If a build fails:
1. Log the error with service name and build output
2. Continue with other independent builds
3. Skip deployment for failed services
4. Report summary of successful and failed builds

### Deployment Failures

If deployment fails:
1. Log the error with service name and deployment details
2. Provide rollback instructions
3. Display deployment history: `aramb deploy history`

### Missing Dependencies

If environment variables or files are missing:
1. List all missing requirements
2. Provide setup instructions
3. Exit before starting builds

## Output Summary

After completion, provide a comprehensive summary:

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
        "status": "success",
        "note": "Single service - no separate build service"
      }
    ]
  },
  "deployments": {
    "successful": [
      {"service": "postgres-db", "status": "running"},
      {"service": "backend-api", "status": "running"},
      {"service": "frontend-web", "status": "running"}
    ],
    "failed": []
  },
  "total_time": "2m15s"
}
```

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

## Integration with aramb-metadata

This skill works seamlessly with aramb-metadata:

1. **Generate Configuration:**
   ```bash
   /aramb-metadata
   ```
   Creates aramb.toml with build and runtime services separated

2. **Local Deploy:**
   ```bash
   /local-deploy
   ```
   Builds locally and deploys using the generated configuration

## Constraints and Limitations

1. **Local Build Environment:**
   - Requires Go 1.21+ (for aramb-cli installation)
   - Requires Docker and BuildKit installed locally
   - Sufficient disk space for images
   - Network access to pull base images
   - `$GOPATH/bin` must be in `$PATH` to access aramb-cli

2. **Service Dependencies:**
   - Build services must complete before runtime services deploy
   - Database services can deploy immediately (no build required)

3. **TOML Configuration:**
   - Must follow aramb.toml schema
   - Build services (type="build") must have lower uniqueIdentifier than runtime services
   - Runtime services must reference build service outputs

4. **Registry Access:**
   - If `--push-registry` is used, requires valid registry credentials
   - Without registry push, images exist only locally

## Best Practices

1. **Run aramb-metadata first** to generate or update aramb.toml
2. **Test builds locally** before deploying
3. **Use version tags** for reproducible deployments
4. **Monitor deployment status** until all services are running
5. **Keep aramb.toml in version control** for team collaboration

## Troubleshooting

### aramb-cli Not Found

```bash
# Check if Go is installed
go version

# If Go is not installed, install it first
# On Ubuntu/Debian:
sudo apt-get update && sudo apt-get install -y golang

# On macOS:
brew install go

# Install aramb-cli
go install github.com/aramb-dev/aramb-cli/cmd/aramb@latest

# Add GOPATH/bin to PATH (add to ~/.bashrc or ~/.zshrc)
export PATH=$PATH:$(go env GOPATH)/bin

# Reload shell configuration
source ~/.bashrc  # or source ~/.zshrc

# Verify installation
aramb --version
```

### Build Fails

```bash
# Check BuildKit connection
docker buildx ls

# Verify Dockerfile exists in buildPath
ls -la <buildPath>/Dockerfile

# Check build logs
aramb build --name <service> --tag test

# Test aramb-cli connectivity
aramb --help
```

### Deployment Fails

```bash
# Check deployment status
aramb deploy status --service <service-name>

# View deployment history
aramb deploy history --service <service-name>

# Check service configuration
cat aramb.toml | grep -A 20 "name = \"<service-name>\""

# Verify aramb-cli can connect to Aramb services
echo $ARAMB_API_TOKEN
echo $ARAMB_SERVICE_ID
```

### Missing Environment Variables

```bash
# Verify all required variables are set
echo $BUILDKIT_HOST
echo $ARAMB_API_TOKEN
echo $ARAMB_SERVICE_ID

# Set missing variables
export BUILDKIT_HOST="tcp://localhost:1234"
export ARAMB_API_TOKEN="your-token"
export ARAMB_SERVICE_ID="your-service-id"

# Make permanent by adding to ~/.bashrc or ~/.zshrc
echo 'export BUILDKIT_HOST="tcp://localhost:1234"' >> ~/.bashrc
echo 'export ARAMB_API_TOKEN="your-token"' >> ~/.bashrc
echo 'export ARAMB_SERVICE_ID="your-service-id"' >> ~/.bashrc
```

## See Also

- **aramb-metadata**: Generate aramb.toml configuration
- **BUILD_DEPLOY.md**: Detailed documentation on build and deploy commands
- **backend-planner**: Plan backend service implementations
- **frontend-planner**: Plan frontend service implementations
