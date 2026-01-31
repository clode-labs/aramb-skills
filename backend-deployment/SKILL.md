---
name: backend-deployment
description: Build and deploy backend services using aramb.toml. Builds Docker images locally with DOCKER_REPOSITORY naming, deploys databases and backend services, waits for completion, and returns PUBLIC_URL. Frontend deployment handled by frontend-deployment skill.
category: deployment
tags: [deployment, build, docker, backend, database, api, devops]
license: MIT
---

# Backend Deployment

Build Docker images and deploy backend services using aramb.toml configuration.

## Role

You are a backend deployment specialist that builds Docker images with DOCKER_REPOSITORY naming, deploys databases and backend services, waits for deployment completion, and returns deployment outputs including PUBLIC_URL.

## Responsibilities

- Validate environment (aramb-cli, env vars, aramb.toml)
- Parse aramb.toml to identify backend and database services
- Get application slug and set DOCKER_REPOSITORY for build services
- Build Docker images for backend services locally with DOCKER_REPOSITORY naming
- Update backend service image URLs in aramb.toml
- Deploy databases and backend services via aramb.toml
- Wait for backend deployment completion
- Extract PUBLIC_URL from deployment outputs
- Return deployment details for frontend integration

## Constraints

- **MUST** have aramb-cli installed from: https://github.com/aramb-ai/release-beta/releases/latest
- **MUST** have aramb.toml in project root (use aramb-metadata skill to create)
- **MUST** have APPLICATION_ID environment variable set
- **MUST** validate BUILDKIT_HOST and ARAMB_API_TOKEN before starting
- **MUST** get application slug and set DOCKER_REPOSITORY for build services
- **MUST** update backend service image URLs in aramb.toml after builds
- **Do NOT** push to registry unless `push_registry: true`
- **Do NOT** skip validation steps

## Inputs

- `project_path`: Root directory containing aramb.toml (default: current directory)
- `backend_services`: Comma-separated backend service names to deploy (default: all backend services)
- `skip_build`: Skip build step and only deploy (default: false)
- `push_registry`: Push images to registry after building (default: false)

## Workflow

### 1. Validate Environment

```bash
# Check aramb-cli installed
if ! command -v aramb &> /dev/null; then
  echo "aramb-cli not found. Install from:"
  echo "https://github.com/aramb-ai/release-beta/releases/latest"
  exit 1
fi

# Verify required environment variables
[ -n "$APPLICATION_ID" ] || { echo "ERROR: APPLICATION_ID not set"; exit 1; }
[ -n "$BUILDKIT_HOST" ] || { echo "ERROR: BUILDKIT_HOST not set"; exit 1; }
[ -n "$ARAMB_API_TOKEN" ] || { echo "ERROR: ARAMB_API_TOKEN not set"; exit 1; }

# Confirm aramb.toml exists
[ -f "aramb.toml" ] || { echo "ERROR: aramb.toml not found"; exit 1; }

# Get application slug for DOCKER_REPOSITORY
echo "Fetching application slug..."
APP_SLUG=$(aramb applications get -i "$APPLICATION_ID" -o json | jq -r '.slug')

if [ -z "$APP_SLUG" ]; then
  echo "ERROR: Could not retrieve application slug"
  exit 1
fi

echo "Application slug: $APP_SLUG"
```

### 2. Parse aramb.toml

Read aramb.toml and identify:
- **Build services** (type="build") - Backend Docker image builds
- **Backend services** (type="backend") - Depend on build services
- **Database services** (postgres/redis/mongodb) - Pre-built images

Map relationships:
- Build service outputs → Backend runtime service inputs
- Backend service dependencies on databases

### 3. Build Backend Services

For each backend build service:

**Step 3a: Set DOCKER_REPOSITORY environment variable**

```bash
# Get build service slug from aramb.toml
BUILD_SERVICE_SLUG="<build-service-name>"  # e.g., "backend-build"

# Set DOCKER_REPOSITORY = app-slug/build-service-slug
export DOCKER_REPOSITORY="${APP_SLUG}/${BUILD_SERVICE_SLUG}"

echo "DOCKER_REPOSITORY set to: $DOCKER_REPOSITORY"
```

**Step 3b: Build Docker image locally**

```bash
cd <buildPath>

# Get commit SHA for tagging
COMMIT_SHA=$(git rev-parse --short HEAD)

# Build with DOCKER_REPOSITORY naming
aramb build --name "$DOCKER_REPOSITORY" --tag "$COMMIT_SHA"

# Optional: Push to registry
if [ "$push_registry" = true ]; then
  aramb build --name "$DOCKER_REPOSITORY" --tag "$COMMIT_SHA" --push
fi
```

**Output**: Docker image `{app-slug}/{build-service-slug}:{commit-sha}`

Example: `my-app/backend-build:abc123`

**Step 3c: Update backend service image in aramb.toml**

```bash
# Find the backend service that references this build service
# Update its image field in aramb.toml

# Before: image = "${101.outputs.IMAGE_URL}"
# After:  image = "my-app/backend-build:abc123"

# Use sed or toml editing tool to update the file
sed -i "s|image = \"\${101.outputs.IMAGE_URL}\"|image = \"${DOCKER_REPOSITORY}:${COMMIT_SHA}\"|g" aramb.toml
```

**Result**: aramb.toml now contains actual image URL instead of reference

### 4. Deploy Backend and Database Services

**Deploy databases and backend services:**

```bash
# Deploy only backend and database services first
aramb deploy --deploy-from-toml --services "postgres-db,backend-api"
```

**Wait for backend deployment to complete:**

```bash
# Wait for backend service to be healthy
BACKEND_SERVICE="backend-api"
echo "Waiting for ${BACKEND_SERVICE} to be healthy..."

aramb deploy status --service "${BACKEND_SERVICE}" --loop --interval 5

# Check if deployment succeeded
DEPLOY_STATUS=$(aramb deploy status --service "${BACKEND_SERVICE}" --output json | jq -r '.status')

if [ "$DEPLOY_STATUS" != "healthy" ]; then
  echo "ERROR: Backend deployment failed with status: $DEPLOY_STATUS"
  exit 1
fi

echo "Backend service is healthy"
```

### 5. Get Backend Deployment Outputs

**Retrieve deployment details and extract PUBLIC_URL:**

```bash
# Get deployment details
BACKEND_DETAILS=$(aramb deploy status --service "${BACKEND_SERVICE}" --output json)

# Extract PUBLIC_URL from outputs
PUBLIC_URL=$(echo "$BACKEND_DETAILS" | jq -r '.outputs.PUBLIC_URL')

if [ -z "$PUBLIC_URL" ] || [ "$PUBLIC_URL" = "null" ]; then
  echo "WARNING: PUBLIC_URL not found in backend deployment outputs"
  echo "Backend deployment details: $BACKEND_DETAILS"
else
  echo "Backend PUBLIC_URL: $PUBLIC_URL"
fi
```

**Example deployment output:**
```json
{
  "service": "backend-api",
  "status": "healthy",
  "outputs": {
    "PUBLIC_URL": "https://backend-api.aramb.dev",
    "INTERNAL_URL": "http://backend-api:8080"
  }
}
```

### 6. Validate Backend Deployments

```bash
# Check backend services status
aramb deploy status --loop --interval 5

# Verify backend services healthy
aramb deploy history --limit 10

# List deployed backend services
aramb services list --application "$APPLICATION_ID" --filter "type=backend,postgres,redis,mongodb"
```

**Return deployment outputs:**

```json
{
  "status": "success",
  "backend_public_url": "https://backend-api.aramb.dev",
  "backend_internal_url": "http://backend-api:8080",
  "services_deployed": ["postgres-db", "backend-api"]
}
```

## Backend Deployment Strategy

### Purpose

Build and deploy backend services, then return PUBLIC_URL for frontend integration.

### Deployment Flow

```
Build Phase
├─ Get application slug
├─ Set DOCKER_REPOSITORY for build services
├─ Build backend Docker images
└─ Update aramb.toml with image URLs
    ↓
Deployment Phase
├─ Deploy databases
├─ Deploy backend services
└─ Wait for backend to be healthy
    ↓
Extract Outputs Phase
├─ Get backend deployment status
├─ Extract PUBLIC_URL from outputs
├─ Extract INTERNAL_URL from outputs
└─ Validate URLs exist
    ↓
Return Outputs
└─ Return PUBLIC_URL for frontend-deployment skill
```

### Backend Output Extraction

**Command:**
```bash
aramb deploy status --service "backend-api" --output json
```

**Expected output:**
```json
{
  "service": "backend-api",
  "status": "healthy",
  "deployment_id": "deploy-abc123",
  "outputs": {
    "PUBLIC_URL": "https://backend-api.aramb.dev",
    "INTERNAL_URL": "http://backend-api:8080",
    "API_VERSION": "v1"
  }
}
```

**Extraction:**
```bash
PUBLIC_URL=$(echo "$BACKEND_DETAILS" | jq -r '.outputs.PUBLIC_URL')
```

## DOCKER_REPOSITORY Workflow for Build Services

### Critical Build Service Flow

**For each build service in aramb.toml:**

1. **Get Application Slug**:
   ```bash
   APP_SLUG=$(aramb applications get -i "$APPLICATION_ID" -o json | jq -r '.slug')
   ```

   Example response:
   ```json
   {
     "id": "app-xyz789",
     "slug": "my-app",
     "name": "My Application"
   }
   ```

2. **Set DOCKER_REPOSITORY Environment Variable**:
   ```bash
   BUILD_SERVICE_SLUG="backend-build"  # From aramb.toml
   export DOCKER_REPOSITORY="${APP_SLUG}/${BUILD_SERVICE_SLUG}"
   # Result: DOCKER_REPOSITORY="my-app/backend-build"
   ```

3. **Build Docker Image**:
   ```bash
   COMMIT_SHA=$(git rev-parse --short HEAD)
   aramb build --name "$DOCKER_REPOSITORY" --tag "$COMMIT_SHA"
   # Builds: my-app/backend-build:abc123
   ```

4. **Update aramb.toml**:
   ```bash
   # Find backend service referencing this build service
   # Replace: image = "${101.outputs.IMAGE_URL}"
   # With:    image = "my-app/backend-build:abc123"

   sed -i "s|image = \"\${101.outputs.IMAGE_URL}\"|image = \"${DOCKER_REPOSITORY}:${COMMIT_SHA}\"|g" aramb.toml
   ```

### DOCKER_REPOSITORY Naming Convention

**Format**: `{app-slug}/{build-service-slug}:{commit-sha}`

**Examples**:
- `my-app/backend-build:abc123`
- `ecommerce/auth-service:def456`
- `analytics/data-processor:789xyz`

**Benefits**:
- Namespace isolation by application
- Clear service identification
- Version tracking via commit SHA
- Registry organization

## Service Type Handling

### Build Services (type="build") - Backend Only

**NOT deployed directly** - Build services produce Docker images for backend services

**Process**:
1. Get application slug from aramb API
2. Set DOCKER_REPOSITORY = `{app-slug}/{build-service-slug}`
3. Build Docker image locally
4. Update referenced backend service in aramb.toml

```bash
# Example full workflow
APP_SLUG=$(aramb applications get -i "$APPLICATION_ID" -o json | jq -r '.slug')
export DOCKER_REPOSITORY="${APP_SLUG}/backend-build"
COMMIT_SHA=$(git rev-parse --short HEAD)

cd <buildPath>
aramb build --name "$DOCKER_REPOSITORY" --tag "$COMMIT_SHA"
```

**Output**:
- Docker image: `{app-slug}/{build-service-slug}:{commit-sha}`
- Updated aramb.toml with actual image URL

### Backend Runtime Services (type="backend")

**Process**:
1. Get application slug: `aramb applications get -i $APPLICATION_ID -o json`
2. Extract app slug from JSON
3. Set DOCKER_REPOSITORY: `export DOCKER_REPOSITORY="${APP_SLUG}/${BUILD_SERVICE_SLUG}"`
4. Build service creates Docker image with DOCKER_REPOSITORY naming
5. Update `image` field in aramb.toml with actual image URL
6. Deploy via TOML

**Before build (aramb.toml original)**:
```toml
[[services]]
uniqueIdentifier = 102
name = "backend-api"
type = "backend"
applicationID = "{applicationID}"

[services.configuration.settings]
image = "${101.outputs.IMAGE_URL}"  # Reference to build service
cmd = "npm start"
commandPort = 8080
publicNet = true
```

**After build (aramb.toml updated)**:
```toml
[[services]]
uniqueIdentifier = 102
name = "backend-api"
type = "backend"
applicationID = "{applicationID}"

[services.configuration.settings]
image = "my-app/backend-build:abc123"  # Actual image from DOCKER_REPOSITORY
cmd = "npm start"
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

**Environment:**
- aramb-cli accessible in PATH
- APPLICATION_ID environment variable set
- BUILDKIT_HOST environment variable set
- ARAMB_API_TOKEN environment variable set
- aramb.toml exists and valid

**Build Phase:**
- Application slug retrieved successfully
- DOCKER_REPOSITORY set for each build service
- All backend builds succeed with DOCKER_REPOSITORY naming
- aramb.toml updated with actual image URLs (not references)

**Deployment Phase:**
- Database services deploy successfully
- Backend services deploy successfully
- Backend services report healthy status
- Backend deployment outputs extracted
- PUBLIC_URL retrieved from backend outputs
- INTERNAL_URL retrieved from backend outputs

**Final Validation:**
- All backend services report healthy status
- No deployment errors
- PUBLIC_URL accessible
- Outputs returned for frontend integration

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
  "application": {
    "id": "app-xyz789",
    "slug": "my-app"
  },
  "builds": {
    "backend": [
      {
        "service": "backend-api",
        "build_service": "backend-build",
        "docker_repo": "my-app/backend-build",
        "image": "my-app/backend-build:abc123",
        "commit_sha": "abc123",
        "build_time": "45s",
        "status": "success",
        "toml_updated": true
      }
    ],
  },
  "deployments": {
    "services": ["postgres-db", "backend-api"],
    "status": "success",
    "backend_outputs": {
      "PUBLIC_URL": "https://backend-api.aramb.dev",
      "INTERNAL_URL": "http://backend-api:8080"
    },
    "successful": ["postgres-db", "backend-api"],
    "failed": []
  },
  "total_time": "2m30s"
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

**Backend deployment fails:**
1. Log error with service name and deployment details
2. Do NOT proceed to frontend deployment
3. Exit with error status
4. Provide troubleshooting: `aramb logs --service <backend-service>`

**Backend PUBLIC_URL not found:**
1. Log warning with full deployment output
2. Check if outputs field exists in deployment response
3. Return deployment details without PUBLIC_URL
4. Frontend deployment can proceed with manual configuration

### Missing Dependencies

If environment invalid:
1. List all missing requirements clearly
2. Provide setup instructions (see [references/installation.md](references/installation.md))
3. Exit before starting builds

## Usage Examples

### Deploy All Backend Services

```bash
# Build and deploy all backend services
/backend-deployment
```

### Deploy Specific Backend Services

```bash
# Build and deploy only specified backend services
/backend-deployment --backend-services backend-api,auth-service
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
/backend-deployment (builds and deploys backend)
    ↓
Backend Running (returns PUBLIC_URL)
    ↓
/frontend-deployment (deploys frontend with backend URL)
    ↓
All Services Running
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
- **frontend-deployment**: Deploy frontend with backend URL
- **BUILD_DEPLOY.md**: Detailed aramb-cli command reference
