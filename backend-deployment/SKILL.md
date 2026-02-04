---
name: backend-deployment
description: Deploy backend services using aramb.toml. Deploys TOML to create services, then builds and deploys backend images using aramb build with --service flag. Returns PUBLIC_URL for frontend integration. Frontend deployment handled by frontend-deployment skill.
category: deployment
tags: [deployment, build, docker, backend, database, api, devops]
license: MIT
---

# Backend Deployment

Deploy backend services from aramb.toml configuration. Creates services first, then builds and deploys backend images.

## Session Continuity

Your session persists. You may be started fresh OR resumed with new context.

### Trigger Types

| Trigger | Meaning |
|---------|---------|
| `start` | Normal task execution (first time) |
| `resume` | User provided additional context |
| `task_chat` | Direct message from task chat UI |

### Resume Trigger Format

When resumed, you receive:
```
## Task Resumed

The user has provided additional context:

<user's message>

Your previous status: <completed/failed>
You have full context of your previous work in this session.
```

### How to Handle Resume

| Previous Status | User Intent | Action |
|-----------------|-------------|--------|
| `failed` | Providing fix info | Retry with new context |
| `completed` | Wants redeployment | Redeploy or update |
| `completed` | Asking question | Answer from your context |
| `in_progress` | Adding context | Incorporate and continue |

### Q&A Mode

If resumed with `mode="qa"`:
- Only answer questions
- Do NOT perform new deployments
- Use `TaskChatResponse` to reply

## Quick Reference

**Two Deployment Paths:**

1. **With Build Services** (type="build" exists in TOML):
   ```
   Read TOML → Deploy TOML (create services) → Get app slug → Identify dependencies → Build & deploy each backend service
   ```

2. **Without Build Services** (no type="build" in TOML):
   ```
   Read TOML → Deploy TOML (create services) → Done
   ```

**Key Principles:**
- ✅ Build services are OPTIONAL
- ✅ Deploy TOML first (creates all services)
- ✅ Then build & deploy backend services individually
- ✅ Use service SLUG (not name) for status checks
- ❌ Any error → EXIT immediately (no recovery)

## Task Chat Communication

Send progress updates to the task chat so users can follow along. Use `TaskUserResponse` MCP tool for key milestones:

**When to send updates:**
- **Starting**: What services you're deploying
- **Key milestones**: Build complete, services deploying, health checks
- **Completion**: Final PUBLIC_URL and deployment status

**Example:**
```
TaskUserResponse(message="🚀 Starting backend deployment. Found 2 services: postgres-db, backend-api. Building images...")
```

```
TaskUserResponse(message="📦 Image built: my-app/backend-build:abc123. Deploying services...")
```

```
TaskUserResponse(message="✅ Backend deployed! PUBLIC_URL: https://backend-api.aramb.dev - All services healthy.")
```

```
TaskUserResponse(message="❌ Deployment failed: Docker build error. See output for details.")
```

Keep messages concise. Focus on status and final URL.

## Role

You are a backend deployment specialist that follows a strict linear deployment flow. **No debugging, no retries, no alternative flows.** If any step fails, exit immediately with error.

## Critical Flow (Strict Order - No Deviations)

**IMPORTANT**: Follow this exact sequence. If ANY step fails, EXIT immediately with error message. Do NOT attempt to:
- Debug the issue
- Login or authenticate
- List resources
- Try alternative approaches
- Fix or recover from errors

**The Flow:**
0. **Install aramb-cli if not present (CRITICAL FIRST STEP - if installation fails, EXIT immediately)**
0.5. **Check BUILDKIT_HOST is set (CRITICAL - aramb-cli uses remote BuildKit for builds)**
1. Read aramb.toml
2. **Deploy from TOML (create all services - if ANY service creation fails, EXIT immediately)**
3. Extract build services (optional - if none exist, skip to step 8)
4. Get application slug (only if build services exist)
5. Identify build service dependencies (only if build services exist)
6. **Build & deploy each backend service using `aramb build --push --deploy --service` (only if build services exist)**
7. Wait for deployments to complete (only if build services exist)
8. Return deployment details

**If any step fails → Exit with error. No recovery attempts.**
**Build services are OPTIONAL → If no build services, skip steps 4-7 after step 2.**
**Step 0 is MANDATORY → If aramb-cli installation fails, EXIT immediately. Do NOT debug or fix.**
**Step 0.5 is MANDATORY → BUILDKIT_HOST must be set for remote builds.**
**Step 2 is CRITICAL → Deploy TOML first to create services. If ANY service creation fails, EXIT.**
**Note: Local Docker daemon is NOT required - builds happen on remote BuildKit server.**

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│              STRICT LINEAR DEPLOYMENT FLOW                  │
│                    (NO DEVIATIONS)                          │
└─────────────────────────────────────────────────────────────┘

Step 0: Install aramb-cli (CRITICAL FIRST STEP)
   ↓
   ├─ ✓ Already installed → Continue
   ├─ ✗ Not installed → Install from GitHub latest release
   │    ├─ ✓ Installation succeeds → Continue to Step 0.5
   │    └─ ✗ Installation fails → EXIT: "Failed to install aramb-cli" (DO NOT DEBUG)
   └─ ✗ Installation error → EXIT: "Failed to install aramb-cli" (DO NOT DEBUG)

Step 0.5: Check BUILDKIT_HOST (CRITICAL - aramb uses remote BuildKit)
   ↓
   ├─ ✓ BUILDKIT_HOST is set → Continue
   └─ ✗ BUILDKIT_HOST not set → EXIT: "BUILDKIT_HOST not set"

   Note: Local Docker daemon is NOT required
         Builds happen on remote BuildKit server

Step 1: Read aramb.toml
   ↓
   ├─ ✓ Found → Continue
   └─ ✗ Not found → EXIT: "aramb.toml not found"

Step 2: Deploy from TOML (Create Services)
   ↓
   ├─ ✓ All services created (Status: Created) → Continue
   └─ ✗ Any service creation fails → EXIT: "Service creation failed"

   Output Example:
   Resolving projects
   Resolving applications
   Resolving services
     Name: postgres-db
     Slug: postgres-db-8db22d9
     Status: Created
     Name: backend-build
     Slug: backend-build-68ace48
     Status: Created
     Name: backend-api
     Slug: backend-api-548cad1
     Status: Created

Step 3: Extract Build Services
   ↓
   ├─ ✓ Found build services → Continue to Step 4
   └─ ✗ No build services → SKIP to Step 8 (done)

┌─────────────────────────────────────────────────────────────┐
│              BUILD PHASE (Optional - only if build services exist) │
└─────────────────────────────────────────────────────────────┘

Step 4: Get Application Slug
   ↓
   ├─ ✓ Got slug → Continue
   └─ ✗ Failed → EXIT: "Failed to retrieve application slug"

Step 5: Identify Dependencies
   ↓
   └─ ✓ Map build services to backend services

Step 6: Build & Deploy Each Backend Service
   ↓
   For each backend service dependent on build service:
   ├─ Get build service slug
   ├─ Get backend service slug
   ├─ Run: aramb build --push --deploy --name {build-service-slug} {build-path} --service {backend-service-slug}
   ├─ ✓ Build & deploy succeed → Continue to next
   └─ ✗ Build or deploy fails → EXIT: "Build/deploy failed for {service}"

Step 7: Wait for Deployments
   ↓
   ├─ ✓ All deployments healthy → Continue
   └─ ✗ Any deployment fails → EXIT: "Deployment failed"

┌─────────────────────────────────────────────────────────────┐
│              COMPLETION PHASE (Always runs)                 │
└─────────────────────────────────────────────────────────────┘

Step 8: Return Deployment Details
   ↓
   └─ ✓ Return: {status, public_url, services_deployed}

════════════════════════════════════════════════════════════

ANY ERROR → IMMEDIATE EXIT
NO DEBUGGING | NO RETRIES | NO ALTERNATIVES
DEPLOY TOML FIRST → Creates all services before building
BUILD SERVICES OPTIONAL → NO BUILD SERVICES = SKIP TO STEP 8
BUILDKIT_HOST IS MANDATORY → Must be set for builds (no local Docker needed)
ARAMB-CLI IS MANDATORY → NEVER attempt to debug or fix aramb-cli issues
LOCAL DOCKER DAEMON NOT REQUIRED → Builds happen on remote BuildKit server
USE SERVICE SLUG → For status checks and build --service flag
```

## Compact Workflow (Precise Logic)

```bash
#!/bin/bash
set -e  # Exit on any error

# Step 0: Install aramb-cli if not present (CRITICAL FIRST STEP)
# IF THIS FAILS, EXIT IMMEDIATELY. DO NOT DEBUG OR FIX.
if ! command -v aramb &> /dev/null; then
  echo "Installing aramb-cli..."
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m)

  if [ "$ARCH" = "x86_64" ]; then
    ARCH="amd64"
  elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    ARCH="arm64"
  fi

  BINARY_NAME="aramb-${OS}-${ARCH}"
  curl -LO "https://github.com/aramb-ai/release-beta/releases/latest/download/${BINARY_NAME}" || { echo "ERROR: Failed to download aramb-cli"; exit 1; }
  chmod +x "${BINARY_NAME}"
  sudo mv "${BINARY_NAME}" /usr/local/bin/aramb || { echo "ERROR: Failed to install aramb-cli"; exit 1; }
  echo "✓ aramb-cli installed successfully"
else
  echo "✓ aramb-cli already installed"
fi

# Step 0.5: Check BUILDKIT_HOST is set (CRITICAL)
# aramb-cli uses remote BuildKit for builds - local Docker daemon NOT required
if [ -z "$BUILDKIT_HOST" ]; then
  echo "ERROR: BUILDKIT_HOST environment variable not set"
  echo "aramb-cli requires BUILDKIT_HOST to connect to remote BuildKit server"
  echo "Example: export BUILDKIT_HOST=tcp://buildkit.example.com:1234"
  exit 1
fi

echo "✓ BUILDKIT_HOST is set: $BUILDKIT_HOST"
echo "ℹ Note: Builds will happen on remote BuildKit server (local Docker not required)"

# Step 1: Validate aramb.toml exists
[ -f "aramb.toml" ] || { echo "ERROR: aramb.toml not found"; exit 1; }

# Step 2: Deploy from TOML (create all services)
echo "Creating services from aramb.toml..."
DEPLOY_OUTPUT=$(aramb deploy --deploy-from-toml 2>&1)
echo "$DEPLOY_OUTPUT"

# Verify all services were created
if echo "$DEPLOY_OUTPUT" | grep -q "Status: Failed"; then
  echo "ERROR: Service creation failed"
  exit 1
fi

echo "✓ All services created successfully"

# Step 3: Check for build services
BUILD_SERVICES=$(grep -A 20 '\[services\]' aramb.toml | grep -B 5 'type = "build"' | grep 'name = ' | cut -d'"' -f2 || true)

if [ -n "$BUILD_SERVICES" ]; then
  # BUILD PHASE (Steps 4-7)

  # Step 4: Get application slug
  [ -n "$APPLICATION_ID" ] || { echo "ERROR: APPLICATION_ID not set"; exit 1; }
  APP_SLUG=$(aramb applications get -i "$APPLICATION_ID" -o json | jq -r '.slug')
  [ "$APP_SLUG" != "null" ] || { echo "ERROR: Failed to get app slug"; exit 1; }

  echo "✓ Application slug: $APP_SLUG"

  # Step 5: Identify dependencies
  # For each build service, find backend services that reference it
  declare -A BUILD_PATHS BUILD_SLUGS BACKEND_SERVICES

  for BUILD_SERVICE in $BUILD_SERVICES; do
    # Get build service slug and path from TOML
    BUILD_SLUG=$(grep -A 10 "name = \"$BUILD_SERVICE\"" aramb.toml | grep 'slug = ' | head -1 | cut -d'"' -f2)
    BUILD_PATH=$(grep -A 10 "name = \"$BUILD_SERVICE\"" aramb.toml | grep 'buildPath = ' | head -1 | cut -d'"' -f2)
    BUILD_ID=$(grep -A 10 "name = \"$BUILD_SERVICE\"" aramb.toml | grep 'uniqueIdentifier = ' | head -1 | awk '{print $3}')

    BUILD_SLUGS[$BUILD_SERVICE]=$BUILD_SLUG
    BUILD_PATHS[$BUILD_SERVICE]=$BUILD_PATH

    # Find backend services that reference this build service
    BACKEND_SERVICE=$(grep -B 15 "\${${BUILD_ID}.outputs.IMAGE_URL}" aramb.toml | grep 'slug = ' | tail -1 | cut -d'"' -f2)
    BACKEND_SERVICES[$BUILD_SERVICE]=$BACKEND_SERVICE

    echo "✓ Build service: $BUILD_SERVICE (slug: $BUILD_SLUG)"
    echo "  → Backend service: $BACKEND_SERVICE"
    echo "  → Build path: $BUILD_PATH"
  done

  # Step 6: Build & deploy each backend service
  for BUILD_SERVICE in $BUILD_SERVICES; do
    BUILD_SLUG=${BUILD_SLUGS[$BUILD_SERVICE]}
    BUILD_PATH=${BUILD_PATHS[$BUILD_SERVICE]}
    BACKEND_SLUG=${BACKEND_SERVICES[$BUILD_SERVICE]}

    echo "Building and deploying: $BUILD_SERVICE → $BACKEND_SLUG"

    # Set DOCKER_REPOSITORY for naming convention
    export DOCKER_REPOSITORY="${APP_SLUG}/${BUILD_SLUG}"

    # Build, push, and deploy
    aramb build --push --deploy --name "$BUILD_SLUG" "$BUILD_PATH" --service "$BACKEND_SLUG" || {
      echo "ERROR: Build/deploy failed for $BUILD_SERVICE"
      exit 1
    }

    echo "✓ Successfully built and deployed: $BUILD_SERVICE"
  done

  # Step 7: Wait for deployments
  echo "Waiting for deployments to complete..."
  sleep 5

  SKIP_BUILD=false
else
  # NO BUILD PHASE
  echo "ℹ No build services found - deployment complete"
  SKIP_BUILD=true
fi

# Step 8: Return deployment details
# Use backend service slug (not name) for status check
BACKEND_SLUG=$(grep -A 5 'type = "backend"' aramb.toml | grep 'slug = ' | head -1 | cut -d'"' -f2 || echo "")
if [ -n "$BACKEND_SLUG" ]; then
  PUBLIC_URL=$(aramb deploy status --service "$BACKEND_SLUG" --output json 2>/dev/null | jq -r '.outputs.PUBLIC_URL // "n/a"')
fi

IMAGES_COUNT=$([ "$SKIP_BUILD" = true ] && echo 0 || echo "${#BUILD_SERVICES[@]}")

echo "{\"status\": \"success\", \"public_url\": \"${PUBLIC_URL:-n/a}\", \"images_built\": $IMAGES_COUNT, \"build_skipped\": $SKIP_BUILD}"
```

**Key Conditions:**
- aramb.toml must exist → EXIT if missing
- aramb-cli must be available → NEVER attempt to debug or fix (proprietary)
- BUILDKIT_HOST must be set → EXIT if missing
- Deploy TOML first → Creates all services, EXIT if ANY service creation fails
- Build services optional → If none, deployment already complete
- If build services exist → APPLICATION_ID required, build & deploy phase executes
- Use service SLUG (not name) → For status checks and --service flag
- Errors in any step → EXIT immediately (no recovery)

## Constraints

### Strict Flow Requirements

- **MUST** install aramb-cli if not present (Step 0) - **CRITICAL FIRST STEP**
- **MUST** check BUILDKIT_HOST is set (Step 0.5) - **CRITICAL - aramb-cli uses remote BuildKit**
- **MUST** exit immediately if aramb-cli installation fails
- **MUST NOT** attempt to debug or fix aramb-cli installation failures
- **MUST** deploy TOML first to create services (Step 2) - **CRITICAL**
- **MUST** exit if ANY service creation fails
- **MUST** follow the exact flow (no deviations)
- **MUST** exit immediately on any error (no recovery)
- **MUST NOT** attempt to debug or fix errors
- **MUST NOT** try alternative approaches
- **MUST NOT** attempt authentication or login
- **MUST NOT** list resources or explore
- **MUST** have aramb.toml in project root
- **MUST** have APPLICATION_ID environment variable set (only if build services exist)
- **MUST** use service SLUG (not name) for status checks and --service flag

### Exit Immediately If:

- aramb-cli installation fails (Step 0) - **EXIT, do NOT debug or fix**
- BUILDKIT_HOST not set (Step 0.5) - **EXIT**
- aramb.toml not found (Step 1) - **EXIT**
- ANY service creation fails (Step 2) - **EXIT**
- APPLICATION_ID not set (only if build services exist) - **EXIT**
- Application slug retrieval fails (only if build services exist) - **EXIT**
- Any build/deploy command fails (only if build services exist) - **EXIT**

**Note:** Local Docker daemon is NOT required - builds happen on remote BuildKit server

### No Recovery Allowed

- **NO** retry logic
- **NO** debugging
- **NO** error recovery
- **NO** alternative flows
- **EXIT** with clear error message

## Inputs

- `project_path`: Root directory containing aramb.toml (default: current directory)
- `backend_services`: Comma-separated backend service names to deploy (default: all backend services)
- `skip_build`: Skip build step and only deploy (default: false)
- `push_registry`: Push images to registry after building (default: false)

## Strict Deployment Flow

### Step 0: Install aramb-cli (CRITICAL FIRST STEP)

**IMPORTANT: This is the first and foremost step. If installation fails, EXIT immediately. Do NOT attempt to debug or fix.**

```bash
# Check if aramb-cli is installed
if ! command -v aramb &> /dev/null; then
  echo "aramb-cli not found. Installing..."

  # Detect OS and architecture
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m)

  # Map architecture names
  if [ "$ARCH" = "x86_64" ]; then
    ARCH="amd64"
  elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    ARCH="arm64"
  fi

  # Construct binary name
  BINARY_NAME="aramb-${OS}-${ARCH}"

  # Download latest release
  echo "Downloading ${BINARY_NAME}..."
  curl -LO "https://github.com/aramb-ai/release-beta/releases/latest/download/${BINARY_NAME}"

  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to download aramb-cli"
    exit 1
  fi

  # Make executable and install
  chmod +x "${BINARY_NAME}"
  sudo mv "${BINARY_NAME}" /usr/local/bin/aramb

  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install aramb-cli to /usr/local/bin/aramb"
    exit 1
  fi

  echo "✓ aramb-cli installed successfully"
else
  echo "✓ aramb-cli already installed ($(aramb --version 2>/dev/null || echo 'version unknown'))"
fi
```

**Exit if:** Download fails OR installation fails. **Do NOT attempt to debug or fix.**

**Supported platforms:**
- Linux (amd64, arm64)
- macOS/Darwin (amd64, arm64)

---

### Step 1: Read aramb.toml

```bash
# Check aramb.toml exists
if [ ! -f "aramb.toml" ]; then
  echo "ERROR: aramb.toml not found in current directory"
  exit 1
fi

echo "✓ Found aramb.toml"
```

**Exit if:** aramb.toml doesn't exist

---

### Step 2: Deploy from TOML (Service Creation)

```bash
# Deploy TOML to create all services
echo "Creating services from aramb.toml..."
DEPLOY_OUTPUT=$(aramb deploy --deploy-from-toml 2>&1)

# Display output
echo "$DEPLOY_OUTPUT"

# Expected output format:
# Resolving projects
# Resolving applications
# Resolving services
#   Name: postgres-db
#   Slug: postgres-db-8db22d9
#   Status: Created
#   Name: backend-build
#   Slug: backend-build-68ace48
#   Status: Created
#   Name: backend-api
#   Slug: backend-api-548cad1
#   Status: Created

# Verify all services were created successfully
if echo "$DEPLOY_OUTPUT" | grep -q "Status: Failed"; then
  echo "ERROR: Service creation failed"
  exit 1
fi

echo "✓ All services created successfully"
```

**Exit if:** ANY service shows "Status: Failed"

**Important:** TOML already contains service slugs and IDs - no need to extract from output

---

### Step 3: Extract Build Services

```bash
# Parse TOML to find all build services (type="build")
BUILD_SERVICES=$(grep -A 20 '\[services\]' aramb.toml | grep -B 5 'type = "build"' | grep 'name = ' | cut -d'"' -f2)

if [ -z "$BUILD_SERVICES" ]; then
  echo "ℹ No build services found - deployment complete"
  SKIP_BUILD=true
else
  echo "✓ Found build services: $BUILD_SERVICES"
  SKIP_BUILD=false
fi
```

**Behavior:**
- If build services found → Continue to Step 4 (build phase)
- If no build services → Skip to Step 8 (done)

---

### Step 4: Get Application Slug (Only if build services exist)

```bash
# Skip this step if no build services
if [ "$SKIP_BUILD" = true ]; then
  echo "ℹ Skipping Step 4 (no build services)"
else
  # Check APPLICATION_ID is set
  if [ -z "$APPLICATION_ID" ]; then
    echo "ERROR: APPLICATION_ID environment variable not set"
    exit 1
  fi

  # Get application slug
  APP_SLUG=$(aramb applications get -i "$APPLICATION_ID" -o json | jq -r '.slug')

  if [ -z "$APP_SLUG" ] || [ "$APP_SLUG" = "null" ]; then
    echo "ERROR: Failed to retrieve application slug"
    echo "Command: aramb applications get -i $APPLICATION_ID -o json"
    exit 1
  fi

  echo "✓ Application slug: $APP_SLUG"
fi
```

**Exit if:** APPLICATION_ID not set OR slug retrieval fails (only checked if build services exist)

---

### Step 5: Identify Dependencies (Only if build services exist)

```bash
# Skip this step if no build services
if [ "$SKIP_BUILD" = true ]; then
  echo "ℹ Skipping Step 5 (no build services)"
else
  # For each build service, find backend services that reference it
  declare -A BUILD_PATHS BUILD_SLUGS BACKEND_SLUGS

  for BUILD_SERVICE in $BUILD_SERVICES; do
    # Get build service slug and path from TOML
    BUILD_SLUG=$(grep -A 10 "name = \"$BUILD_SERVICE\"" aramb.toml | grep 'slug = ' | head -1 | cut -d'"' -f2)
    BUILD_PATH=$(grep -A 10 "name = \"$BUILD_SERVICE\"" aramb.toml | grep 'buildPath = ' | head -1 | cut -d'"' -f2)
    BUILD_ID=$(grep -A 10 "name = \"$BUILD_SERVICE\"" aramb.toml | grep 'uniqueIdentifier = ' | head -1 | awk '{print $3}')

    # Store build service info
    BUILD_SLUGS[$BUILD_SERVICE]=$BUILD_SLUG
    BUILD_PATHS[$BUILD_SERVICE]=$BUILD_PATH

    # Find backend service that references this build service
    # Look for: image = "${BUILD_ID.outputs.IMAGE_URL}"
    BACKEND_SLUG=$(grep -B 15 "\${${BUILD_ID}.outputs.IMAGE_URL}" aramb.toml | grep 'slug = ' | tail -1 | cut -d'"' -f2)
    BACKEND_SLUGS[$BUILD_SERVICE]=$BACKEND_SLUG

    echo "✓ Build service: $BUILD_SERVICE"
    echo "  → Slug: $BUILD_SLUG"
    echo "  → Path: $BUILD_PATH"
    echo "  → Backend service: $BACKEND_SLUG"
  done
fi
```

**Note:** uniqueIdentifier is ONLY used for finding dependencies within TOML file

---

### Step 6: Build & Deploy Each Backend Service (Only if build services exist)

```bash
# Skip this step if no build services
if [ "$SKIP_BUILD" = true ]; then
  echo "ℹ Skipping Step 6 (no build services)"
else
  # Build and deploy each backend service
  for BUILD_SERVICE in $BUILD_SERVICES; do
    BUILD_SLUG=${BUILD_SLUGS[$BUILD_SERVICE]}
    BUILD_PATH=${BUILD_PATHS[$BUILD_SERVICE]}
    BACKEND_SLUG=${BACKEND_SLUGS[$BUILD_SERVICE]}

    echo "Building and deploying: $BUILD_SERVICE → $BACKEND_SLUG"

    # Set DOCKER_REPOSITORY for naming convention
    export DOCKER_REPOSITORY="${APP_SLUG}/${BUILD_SLUG}"

    # Build, push, and deploy using --service flag
    aramb build --push --deploy --name "$BUILD_SLUG" "$BUILD_PATH" --service "$BACKEND_SLUG"

    if [ $? -ne 0 ]; then
      echo "ERROR: Build/deploy failed for $BUILD_SERVICE"
      exit 1
    fi

    echo "✓ Successfully built and deployed: $BUILD_SERVICE → $BACKEND_SLUG"
  done
fi
```

**Exit if:** Any build or deploy command fails

**Key Points:**
- Use `--service {BACKEND_SERVICE_SLUG}` flag (NOT environment variable)
- Use build service slug for `--name` parameter
- Use backend service slug for `--service` parameter
- DOCKER_REPOSITORY format: `{app-slug}/{build-service-slug}`

---

### Step 7: Wait for Deployments (Only if build services exist)

```bash
# Skip this step if no build services
if [ "$SKIP_BUILD" = true ]; then
  echo "ℹ Skipping Step 7 (no build services)"
else
  echo "Waiting for deployments to complete..."
  sleep 5

  # Optionally check deployment status
  for BUILD_SERVICE in $BUILD_SERVICES; do
    BACKEND_SLUG=${BACKEND_SLUGS[$BUILD_SERVICE]}
    STATUS=$(aramb deploy status --service "$BACKEND_SLUG" --output json 2>/dev/null | jq -r '.status // "unknown"')
    echo "✓ Backend service $BACKEND_SLUG status: $STATUS"
  done
fi
```

---

### Step 8: Return Deployment Details (Always runs)

```bash
# Get backend service slug (first backend service found)
# Use SLUG, not name, for status checks
BACKEND_SLUG=$(grep -A 5 'type = "backend"' aramb.toml | grep 'slug = ' | head -1 | cut -d'"' -f2)

if [ -z "$BACKEND_SLUG" ]; then
  echo "WARNING: No backend service found for PUBLIC_URL extraction"
  echo '{"status": "deployed", "services": "all", "build_skipped": '$SKIP_BUILD'}'
  exit 0
fi

# Get deployment status using service slug
DEPLOY_STATUS=$(aramb deploy status --service "$BACKEND_SLUG" --output json 2>&1)

if [ $? -ne 0 ]; then
  echo "WARNING: Could not get deployment status for $BACKEND_SLUG"
  echo '{"status": "deployed", "backend_slug": "'$BACKEND_SLUG'", "build_skipped": '$SKIP_BUILD'}'
  exit 0
fi

# Extract PUBLIC_URL
PUBLIC_URL=$(echo "$DEPLOY_STATUS" | jq -r '.outputs.PUBLIC_URL // empty')

# Calculate services deployed (number of build services built and deployed)
if [ "$SKIP_BUILD" = true ]; then
  SERVICES_DEPLOYED=0
else
  SERVICES_DEPLOYED=$(echo "$BUILD_SERVICES" | wc -w)
fi

# Return deployment details
cat <<EOF
{
  "status": "success",
  "backend_slug": "$BACKEND_SLUG",
  "public_url": "$PUBLIC_URL",
  "build_skipped": $SKIP_BUILD,
  "services_deployed": $SERVICES_DEPLOYED
}
EOF
```

**Exit if:** None (warnings only for status retrieval)

**Important:** Always use service SLUG (not name) for status checks


## Backend Deployment Strategy

### Purpose

Deploy backend services from TOML, build Docker images, deploy to backend services, and return PUBLIC_URL for frontend integration.

### Deployment Flow

```
Service Creation Phase
├─ Deploy TOML (creates all services)
└─ Verify all services created successfully
    ↓
Build Phase (if build services exist)
├─ Get application slug
├─ Identify build service dependencies
├─ For each backend service dependent on build service:
│  ├─ Set DOCKER_REPOSITORY naming
│  ├─ Build Docker image
│  ├─ Push to registry
│  └─ Deploy to backend service using --service flag
└─ Wait for deployments to complete
    ↓
Extract Outputs Phase
├─ Get backend deployment status (using service SLUG)
├─ Extract PUBLIC_URL from outputs
└─ Validate URLs exist
    ↓
Return Outputs
└─ Return PUBLIC_URL for frontend-deployment skill
```

### Backend Output Extraction

**Command:**
```bash
# Use backend service SLUG (not name)
BACKEND_SLUG="backend-api-548cad1"
aramb deploy status --service "$BACKEND_SLUG" --output json
```

**Expected output:**
```json
{
  "service": "backend-api-548cad1",
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
PUBLIC_URL=$(echo "$DEPLOY_STATUS" | jq -r '.outputs.PUBLIC_URL')
```

## DOCKER_REPOSITORY Workflow for Build Services

### Critical Build Service Flow

**For each build service in aramb.toml:**

1. **Deploy TOML First** (creates all services):
   ```bash
   aramb deploy --deploy-from-toml
   # Output: All services created with Status: Created
   ```

2. **Get Application Slug**:
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

3. **Identify Dependencies**:
   ```bash
   # From aramb.toml, extract:
   BUILD_SLUG="backend-build"        # Build service slug
   BUILD_PATH="./backend"             # Build path
   BUILD_ID=101                       # uniqueIdentifier (for finding dependencies)
   BACKEND_SLUG="backend-api-548cad1" # Backend service slug

   # uniqueIdentifier is ONLY used to find which backend service
   # references this build service via: image = "${101.outputs.IMAGE_URL}"
   ```

4. **Set DOCKER_REPOSITORY Environment Variable**:
   ```bash
   export DOCKER_REPOSITORY="${APP_SLUG}/${BUILD_SLUG}"
   # Result: DOCKER_REPOSITORY="my-app/backend-build"
   ```

5. **Build, Push, and Deploy**:
   ```bash
   aramb build --push --deploy --name "$BUILD_SLUG" "$BUILD_PATH" --service "$BACKEND_SLUG"
   # This command:
   # 1. Builds the Docker image
   # 2. Pushes to registry
   # 3. Deploys to backend service (specified by --service flag)
   ```

### DOCKER_REPOSITORY Naming Convention

**Format**: `{app-slug}/{build-service-slug}`

**Examples:**
- `my-app/backend-build`
- `ecommerce/auth-service`
- `analytics/data-processor`

**Benefits**:
- Namespace isolation by application
- Clear service identification
- Registry organization
- Consistent naming across services

## Service Type Handling

### Build Services (type="build") - Backend Only

**NOT deployed directly** - Build services produce Docker images for backend services

**New Process**:
1. Deploy TOML first (creates all services including build services)
2. Get application slug from aramb API
3. Set DOCKER_REPOSITORY = `{app-slug}/{build-service-slug}`
4. Build, push, and deploy using `aramb build --push --deploy --service`

```bash
# Example full workflow
# Step 1: Services already created via TOML deploy

# Step 2: Get app slug
APP_SLUG=$(aramb applications get -i "$APPLICATION_ID" -o json | jq -r '.slug')

# Step 3: Get build service and backend service info from TOML
BUILD_SLUG="backend-build"          # From build service
BUILD_PATH="./backend"               # From build service
BACKEND_SLUG="backend-api-548cad1"  # From backend service

# Step 4: Set DOCKER_REPOSITORY
export DOCKER_REPOSITORY="${APP_SLUG}/${BUILD_SLUG}"

# Step 5: Build, push, and deploy
aramb build --push --deploy --name "$BUILD_SLUG" "$BUILD_PATH" --service "$BACKEND_SLUG"
```

**Output**:
- Docker image built and pushed to registry
- Image deployed to backend service (specified by --service flag)
- No manual TOML updates needed

### Backend Runtime Services (type="backend")

**Process**:
1. Created during TOML deploy (Step 2)
2. If dependent on build service:
   - Build service builds image
   - Image deployed to backend service via `--service` flag
3. If using pre-built image:
   - Already deployed from TOML

**aramb.toml (before build)**:
```toml
[[services]]
uniqueIdentifier = 102
name = "backend-api"
slug = "backend-api-548cad1"
type = "backend"
applicationID = "{applicationID}"

[services.configuration.settings]
image = "${101.outputs.IMAGE_URL}"  # Reference to build service
cmd = "npm start"
commandPort = 8080
publicNet = true
```

**No TOML update needed** - aramb build command handles deployment directly to backend service using `--service` flag

### Database Services (postgres/redis/mongodb)

**No build required**. Created and deployed during TOML deploy.

```toml
[[services]]
uniqueIdentifier = 100
name = "postgres-db"
slug = "postgres-db-8db22d9"
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
- BUILDKIT_HOST environment variable set
- ARAMB_API_TOKEN environment variable set
- aramb.toml exists and valid
- APPLICATION_ID environment variable set (only if build services exist)

**Service Creation Phase:**
- aramb deploy --deploy-from-toml succeeds
- All services show "Status: Created"
- No services show "Status: Failed"

**Build Phase (if build services exist):**
- Application slug retrieved successfully
- DOCKER_REPOSITORY set for each build service
- Build service dependencies identified correctly
- Backend service slugs extracted from TOML
- All build/deploy commands succeed with --service flag

**Completion Phase:**
- Backend services report healthy status
- Backend deployment outputs extracted using service SLUG
- PUBLIC_URL retrieved from backend outputs

**Final Validation:**
- All backend services report healthy status
- No deployment errors
- PUBLIC_URL accessible
- Outputs returned for frontend integration

### Expected (SHOULD pass)

- Service slugs correctly used for status checks
- Build images deployed to correct backend services
- Environment variables configured in services
- Services start in correct order

### Nice to Have

- Build process optimized (caching, parallel builds)
- Deployment history logged
- Service metrics available

## Output Requirements (IMPORTANT)

Before completing, you MUST set comprehensive outputs. The planner uses these
to answer user questions without needing to resume you.

**Always include:**

```python
outputs = {
    # URLs and identifiers (CRITICAL)
    "public_url": "https://backend-api.aramb.dev",
    "internal_url": "http://backend-api:8080",
    "deployment_id": "deploy-abc123xyz",

    # Application info
    "application_id": "app-xyz789",
    "application_slug": "my-app",

    # Services deployed
    "services_deployed": ["postgres-db", "backend-api"],
    "backend_service": "backend-api",
    "database_service": "postgres-db",

    # Build info (if builds were done)
    "build_skipped": false,
    "images_built": 1,
    "docker_image": "my-app/backend-build:abc123",

    # Status
    "status": "success",
    "all_healthy": true,
    "total_time": "2m30s"
}
```

**Why this matters:**
- Planner receives your outputs in `task_completed` trigger
- Planner can answer "What's the PUBLIC_URL?", "Is the backend deployed?", etc. immediately
- No need to resume you for simple factual questions

## Output

Report deployment results:

**With Build Services:**
```json
{
  "status": "success",
  "backend_slug": "backend-api-548cad1",
  "public_url": "https://backend-api.aramb.dev",
  "build_skipped": false,
  "services_deployed": 1
}
```

**Without Build Services (Direct Deploy):**
```json
{
  "status": "success",
  "backend_slug": "backend-api-548cad1",
  "public_url": "https://backend-api.aramb.dev",
  "build_skipped": true,
  "services_deployed": 0
}
```

**Detailed Output Example:**
```json
{
  "status": "success",
  "backend_slug": "backend-api-548cad1",
  "public_url": "https://backend-api.aramb.dev",
  "build_skipped": false,
  "services_deployed": 1,
  "services_created": [
    "postgres-db-8db22d9",
    "backend-build-68ace48",
    "backend-api-548cad1"
  ]
}
```

## Error Handling (Strict Exit Policy)

### All Errors = Immediate Exit

**No error recovery. No debugging. No retries.**

### Error Message Format

```bash
echo "ERROR: {specific error message}"
echo "Step: {step number and name}"
echo "Details: {relevant context}"
exit 1
```

### Example Error Messages

**Step 1 - aramb.toml not found:**
```
ERROR: aramb.toml not found in current directory
Step: 1 - Read aramb.toml
Details: Ensure aramb-metadata skill has generated the TOML file
```

**Step 2 - Service creation failed:**
```
ERROR: Service creation failed
Step: 2 - Deploy from TOML
Details: One or more services failed to create (Status: Failed)
Check aramb.toml syntax and service configurations
```

**Step 4 - Application slug retrieval failed:**
```
ERROR: Failed to retrieve application slug
Step: 4 - Get Application Slug
Details: APPLICATION_ID may be invalid or API unavailable
Command: aramb applications get -i $APPLICATION_ID -o json
```

**Step 6 - Build/deploy failed:**
```
ERROR: Build/deploy failed for backend-build
Step: 6 - Build & Deploy Backend Service
Details: Failed to build or deploy backend service
Build service: backend-build
Backend service: backend-api-548cad1
Command: aramb build --push --deploy --name backend-build ./backend --service backend-api-548cad1
```

### What NOT to Do

- ❌ Do NOT attempt to create aramb.toml if missing
- ❌ Do NOT try to login or authenticate
- ❌ Do NOT list applications or services
- ❌ Do NOT retry failed builds
- ❌ Do NOT suggest fixes or debug
- ❌ Do NOT proceed to next step if current fails
- ❌ Do NOT manually update TOML files

### What TO Do

- ✅ Log clear error message
- ✅ Exit immediately with exit code 1
- ✅ Return error details in output
- ✅ Use service SLUG (not name) in error messages

### Missing Dependencies

If environment invalid:
1. List all missing requirements clearly
2. Provide setup instructions (see [references/installation.md](references/installation.md))
3. Exit before starting deployment

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
/backend-deployment
    ├─ Deploy TOML (create services)
    ├─ Build & deploy backend services (if build services exist)
    └─ Return PUBLIC_URL
    ↓
Backend Running (PUBLIC_URL available)
    ↓
/frontend-deployment (deploys frontend with backend URL)
    ↓
All Services Running
```

## Best Practices

1. **Run aramb-metadata first** to generate or update aramb.toml
2. **Verify environment** before starting deployment (aramb-cli, BUILDKIT_HOST, APPLICATION_ID)
3. **Deploy TOML first** to create all services before building
4. **Use service SLUG** (not name) for status checks and commands
5. **Monitor deployment status** until all services healthy
6. **Keep aramb.toml in version control** for team collaboration
7. **No manual TOML updates** - aramb build handles deployment automatically

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
