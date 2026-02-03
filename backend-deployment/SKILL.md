---
name: backend-deployment
description: Build and deploy backend services using aramb.toml. Builds Docker images locally with DOCKER_REPOSITORY naming, deploys databases and backend services, waits for completion, and returns PUBLIC_URL. Frontend deployment handled by frontend-deployment skill.
category: deployment
tags: [deployment, build, docker, backend, database, api, devops]
license: MIT
---

# Backend Deployment

Build Docker images and deploy backend services using aramb.toml configuration.

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
   Read TOML → Extract builds → Get app slug → Build images → Update TOML → Deploy
   ```

2. **Without Build Services** (no type="build" in TOML):
   ```
   Read TOML → No builds found → Deploy directly
   ```

**Key Principles:**
- ✅ Build services are OPTIONAL
- ✅ If no builds → Skip to deployment
- ✅ If builds exist → Must complete successfully before deployment
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
2. Extract build services (optional - if none exist, skip to step 9)
3. Get application slug (only if build services exist)
4. Create image names (DOCKER_REPOSITORY format) (only if build services exist)
5. Run build commands for each build service (only if build services exist)
6. Capture image URLs (only if build services exist)
7. Update backend service images in aramb.toml (only if build services exist)
8. Run `aramb deploy --deploy-from-toml`
9. Return deployment details

**If any step fails → Exit with error. No recovery attempts.**
**Build services are OPTIONAL → If no build services, skip steps 3-7 and go directly to step 9.**
**Step 0 is MANDATORY → If aramb-cli installation fails, EXIT immediately. Do NOT debug or fix.**
**Step 0.5 is MANDATORY → BUILDKIT_HOST must be set for remote builds.**
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

Step 2: Extract Build Services
   ↓
   ├─ ✓ Found build services → Continue to Step 3
   └─ ✗ No build services → SKIP to Step 9 (deploy directly)

┌─────────────────────────────────────────────────────────────┐
│              BUILD PHASE (Optional - only if build services exist) │
└─────────────────────────────────────────────────────────────┘

Step 3: Get Application Slug
   ↓
   ├─ ✓ Got slug → Continue
   └─ ✗ Failed → EXIT: "Failed to retrieve application slug"

Step 4: Create Image Names
   ↓
   └─ ✓ Names created: {app-slug}/{build-service}

Step 5: Run Build Commands
   ↓
   ├─ ✓ All builds succeed → Continue
   └─ ✗ Any build fails → EXIT: "Build failed for {service}"

Step 6: Update aramb.toml
   ↓
   ├─ ✓ TOML updated → Continue
   └─ ✗ Update failed → EXIT: "Failed to update aramb.toml"

┌─────────────────────────────────────────────────────────────┐
│              DEPLOYMENT PHASE (Always runs)                 │
└─────────────────────────────────────────────────────────────┘

Step 9: Deploy from TOML
   ↓
   ├─ ✓ Deploy succeeds → Continue
   └─ ✗ Deploy fails → EXIT: "aramb deploy failed"

Step 10: Return Deployment Details
   ↓
   └─ ✓ Return: {status, public_url, images_built}

════════════════════════════════════════════════════════════

ANY ERROR → IMMEDIATE EXIT
NO DEBUGGING | NO RETRIES | NO ALTERNATIVES
BUILD SERVICES OPTIONAL → NO BUILD SERVICES = SKIP TO STEP 9
BUILDKIT_HOST IS MANDATORY → Must be set for builds (no local Docker needed)
ARAMB-CLI IS MANDATORY → NEVER attempt to debug or fix aramb-cli issues
LOCAL DOCKER DAEMON NOT REQUIRED → Builds happen on remote BuildKit server
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

# Step 2: Check for build services
BUILD_SERVICES=$(grep -A 20 '\[services\]' aramb.toml | grep -B 5 'type = "build"' | grep 'name = ' | cut -d'"' -f2 || true)

if [ -n "$BUILD_SERVICES" ]; then
  # BUILD PHASE (Steps 3-7)

  # Step 3: Get application slug
  [ -n "$APPLICATION_ID" ] || { echo "ERROR: APPLICATION_ID not set"; exit 1; }
  APP_SLUG=$(aramb applications get -i "$APPLICATION_ID" -o json | jq -r '.slug')
  [ "$APP_SLUG" != "null" ] || { echo "ERROR: Failed to get app slug"; exit 1; }

  # Step 4: Create image names
  declare -A IMAGE_NAMES IMAGE_URLS
  for BUILD_SERVICE in $BUILD_SERVICES; do
    IMAGE_NAMES[$BUILD_SERVICE]="${APP_SLUG}/${BUILD_SERVICE}"
  done

  # Step 5: Build images
  # Get version tag: use git commit SHA if available, otherwise generate simple tag
  if git rev-parse --short HEAD &> /dev/null; then
    VERSION_TAG=$(git rev-parse --short HEAD)
    echo "Using git commit SHA: $VERSION_TAG"
  else
    VERSION_TAG="v$(date +%Y%m%d-%H%M%S)"
    echo "Git not available, using generated tag: $VERSION_TAG"
  fi

  for BUILD_SERVICE in $BUILD_SERVICES; do
    IMAGE_NAME=${IMAGE_NAMES[$BUILD_SERVICE]}
    aramb build --name "$IMAGE_NAME" --tag "$VERSION_TAG" || { echo "ERROR: Build failed for $BUILD_SERVICE"; exit 1; }
    IMAGE_URLS[$BUILD_SERVICE]="${IMAGE_NAME}:${VERSION_TAG}"
  done

  # Step 6: Update aramb.toml with image URLs
  for BUILD_SERVICE in $BUILD_SERVICES; do
    BUILD_ID=$(grep -B 10 "name = \"$BUILD_SERVICE\"" aramb.toml | grep 'uniqueIdentifier = ' | tail -1 | awk '{print $3}')
    [ -n "$BUILD_ID" ] || { echo "ERROR: No uniqueIdentifier for $BUILD_SERVICE"; exit 1; }
    sed -i "s|image = \"\${${BUILD_ID}.outputs.IMAGE_URL}\"|image = \"${IMAGE_URLS[$BUILD_SERVICE]}\"|g" aramb.toml
  done

  SKIP_BUILD=false
else
  # NO BUILD PHASE - skip to deployment
  echo "ℹ No build services - deploying directly from TOML"
  SKIP_BUILD=true
fi

# Step 9: Deploy from TOML (always runs)
aramb deploy --deploy-from-toml --yes || { echo "ERROR: Deploy failed"; exit 1; }

# Step 10: Return deployment details
BACKEND_SERVICE=$(grep -A 5 'type = "backend"' aramb.toml | grep 'name = ' | head -1 | cut -d'"' -f2 || echo "")
if [ -n "$BACKEND_SERVICE" ]; then
  PUBLIC_URL=$(aramb deploy status --service "$BACKEND_SERVICE" --output json 2>/dev/null | jq -r '.outputs.PUBLIC_URL // "n/a"')
fi

IMAGES_COUNT=$([ "$SKIP_BUILD" = true ] && echo 0 || echo "${#IMAGE_URLS[@]}")

echo "{\"status\": \"success\", \"public_url\": \"${PUBLIC_URL:-n/a}\", \"images_built\": $IMAGES_COUNT, \"build_skipped\": $SKIP_BUILD}"
```

**Key Conditions:**
- aramb.toml must exist → EXIT if missing
- Docker must be installed and running → Can attempt installation/troubleshooting (it's openly available)
- aramb-cli must be available → NEVER attempt to debug or fix (proprietary)
- Build services optional → If none, skip Steps 3-8
- If build services exist → APPLICATION_ID required, Docker required, build phase executes
- If build services missing → Skip directly to Step 9 (deploy)
- Deploy always runs → Either with built images or pre-configured images
- Errors in any step → EXIT immediately (no recovery except Docker troubleshooting)

## Constraints

### Strict Flow Requirements

- **MUST** install aramb-cli if not present (Step 0) - **CRITICAL FIRST STEP**
- **MUST** check Docker is installed and running (Step 0.5) - **CRITICAL - aramb-cli needs Docker**
- **MUST** exit immediately if aramb-cli installation fails
- **MUST NOT** attempt to debug or fix aramb-cli installation failures
- **CAN** attempt to install/troubleshoot Docker (it's openly available)
- **MUST** exit if Docker cannot be installed or started after troubleshooting
- **MUST** follow the exact flow (no deviations)
- **MUST** exit immediately on any error (except Docker troubleshooting)
- **MUST NOT** attempt to debug or fix errors (except Docker)
- **MUST NOT** try alternative approaches (except for Docker installation methods)
- **MUST NOT** attempt authentication or login
- **MUST NOT** list resources or explore
- **MUST** have aramb.toml in project root
- **MUST** have APPLICATION_ID environment variable set (only if build services exist)

### Exit Immediately If:

- aramb-cli installation fails (Step 0) - **EXIT, do NOT debug or fix**
- Docker cannot be installed or started after troubleshooting (Step 0.5) - **EXIT after attempting fix**
- aramb.toml not found
- APPLICATION_ID not set (only if build services exist)
- Application slug retrieval fails (only if build services exist)
- Any build command fails (only if build services exist)
- TOML update fails (only if build services exist)
- Deploy command fails

**Note:** Git is NOT required - if git is not available, a timestamp-based tag will be generated automatically

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

### Step 0.5: Check Docker Installation and Status (CRITICAL)

**IMPORTANT: aramb-cli needs Docker to build images. This step is MANDATORY.**

**Docker is openly available - can attempt installation and troubleshooting.**

```bash
# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  echo "Docker not found. Attempting installation..."

  # Detect OS and attempt Docker installation
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')

  if [ "$OS" = "linux" ]; then
    # Install Docker on Linux using official script
    echo "Installing Docker on Linux..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh || { echo "ERROR: Failed to install Docker"; exit 1; }

    # Start Docker service
    sudo systemctl start docker || sudo service docker start

    # Add current user to docker group (optional, for non-root access)
    sudo usermod -aG docker $USER || true

    echo "✓ Docker installed successfully"
  else
    echo "ERROR: Docker not found. Please install Docker Desktop from:"
    echo "https://docs.docker.com/get-docker/"
    exit 1
  fi
fi

# Check if Docker daemon is running
if ! docker ps &> /dev/null; then
  echo "Docker daemon is not running. Attempting to start..."

  # Try to start Docker daemon
  if command -v systemctl &> /dev/null; then
    sudo systemctl start docker || { echo "ERROR: Failed to start Docker daemon"; exit 1; }
  elif command -v service &> /dev/null; then
    sudo service docker start || { echo "ERROR: Failed to start Docker daemon"; exit 1; }
  else
    echo "ERROR: Docker daemon is not running. Please start Docker manually."
    exit 1
  fi

  # Verify Docker is now running
  sleep 2
  if ! docker ps &> /dev/null; then
    echo "ERROR: Docker daemon still not running after start attempt"
    exit 1
  fi

  echo "✓ Docker daemon started successfully"
fi

echo "✓ Docker is installed and running ($(docker --version))"
```

**Exit if:** Docker cannot be installed or started after troubleshooting attempts.

**Why Docker is Required:**
- aramb-cli uses Docker to build container images
- Build services (type="build") create Docker images
- Without Docker, image builds will fail

**Installation Methods:**
- **Linux**: Uses official Docker installation script (https://get.docker.com)
- **macOS/Windows**: Requires manual Docker Desktop installation

**Troubleshooting Steps:**
1. Check if Docker is installed: `docker --version`
2. Check if Docker daemon is running: `docker ps`
3. Try starting Docker: `sudo systemctl start docker` or `sudo service docker start`
4. Check Docker service status: `systemctl status docker`
5. For permission issues: `sudo usermod -aG docker $USER` (requires logout/login)

**Supported Docker Installations:**
- Docker Desktop (macOS, Windows, Linux)
- Docker Engine (Linux)
- Docker CE (Community Edition)

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

### Step 2: Extract Build Services

```bash
# Parse TOML to find all build services (type="build")
BUILD_SERVICES=$(grep -A 20 '\[services\]' aramb.toml | grep -B 5 'type = "build"' | grep 'name = ' | cut -d'"' -f2)

if [ -z "$BUILD_SERVICES" ]; then
  echo "ℹ No build services found in aramb.toml - skipping build phase"
  # Skip to Step 8: Deploy from TOML directly
  SKIP_BUILD=true
else
  echo "✓ Found build services: $BUILD_SERVICES"
  SKIP_BUILD=false
fi
```

**Behavior:**
- If build services found → Continue to Step 3 (build phase)
- If no build services → Skip to Step 8 (deploy directly)

---

### Step 3: Get Application Slug (Only if build services exist)

```bash
# Skip this step if no build services
if [ "$SKIP_BUILD" = true ]; then
  echo "ℹ Skipping Step 3 (no build services)"
else
  # Check APPLICATION_ID is set
  if [ -z "$APPLICATION_ID" ]; then
    echo "ERROR: APPLICATION_ID environment variable not set"
    exit 1
  fi

  # Get application slug
  APP_SLUG=$(aramb applications get -i "$APPLICATION_ID" -o json 2>&1 | jq -r '.slug')

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

### Step 4: Create Image Names (Only if build services exist)

```bash
# Skip this step if no build services
if [ "$SKIP_BUILD" = true ]; then
  echo "ℹ Skipping Step 4 (no build services)"
else
  # For each build service, create DOCKER_REPOSITORY name
  # Format: {app-slug}/{build-service-name}

  declare -A IMAGE_NAMES

  for BUILD_SERVICE in $BUILD_SERVICES; do
    IMAGE_NAME="${APP_SLUG}/${BUILD_SERVICE}"
    IMAGE_NAMES[$BUILD_SERVICE]=$IMAGE_NAME
    echo "✓ Image name: $IMAGE_NAME"
  done
fi
```

**Exit if:** Image name creation fails (only checked if build services exist)

---

### Step 5: Run Build Commands (Only if build services exist)

```bash
# Skip this step if no build services
if [ "$SKIP_BUILD" = true ]; then
  echo "ℹ Skipping Step 5 (no build services)"
else
  # Get version tag for tagging: use git commit SHA if available, otherwise generate simple tag
  if git rev-parse --short HEAD &> /dev/null 2>&1; then
    VERSION_TAG=$(git rev-parse --short HEAD)
    echo "Using git commit SHA: $VERSION_TAG"
  else
    VERSION_TAG="v$(date +%Y%m%d-%H%M%S)"
    echo "Git not available, using generated tag: $VERSION_TAG"
  fi

  # Build each service
  declare -A IMAGE_URLS

  for BUILD_SERVICE in $BUILD_SERVICES; do
    IMAGE_NAME=${IMAGE_NAMES[$BUILD_SERVICE]}
    FULL_IMAGE="${IMAGE_NAME}:${VERSION_TAG}"

    echo "Building: $FULL_IMAGE"

    # Run build command
    aramb build --name "$IMAGE_NAME" --tag "$VERSION_TAG" 2>&1

    if [ $? -ne 0 ]; then
      echo "ERROR: Build failed for $BUILD_SERVICE"
      echo "Image: $FULL_IMAGE"
      exit 1
    fi

    # Store image URL
    IMAGE_URLS[$BUILD_SERVICE]=$FULL_IMAGE
    echo "✓ Built: $FULL_IMAGE"
  done
fi
```

**Exit if:** (only checked if build services exist)
- Git not available
- Any build command fails
- Build returns non-zero exit code

---

### Step 6: Update Backend Service Images in TOML (Only if build services exist)

```bash
# Skip this step if no build services
if [ "$SKIP_BUILD" = true ]; then
  echo "ℹ Skipping Step 6 (no build services)"
else
  # Find backend services that reference build services
  # Replace ${buildServiceId.outputs.IMAGE_URL} with actual image

  for BUILD_SERVICE in $BUILD_SERVICES; do
    FULL_IMAGE=${IMAGE_URLS[$BUILD_SERVICE]}

    # Find the service ID for this build service
    BUILD_ID=$(grep -B 10 "name = \"$BUILD_SERVICE\"" aramb.toml | grep 'uniqueIdentifier = ' | tail -1 | awk '{print $3}')

    if [ -z "$BUILD_ID" ]; then
      echo "ERROR: Could not find uniqueIdentifier for build service $BUILD_SERVICE"
      exit 1
    fi

    # Replace image reference with actual image URL
    sed -i "s|image = \"\${${BUILD_ID}.outputs.IMAGE_URL}\"|image = \"${FULL_IMAGE}\"|g" aramb.toml

    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to update aramb.toml for build service $BUILD_SERVICE"
      exit 1
    fi

    echo "✓ Updated aramb.toml: ${BUILD_ID}.outputs.IMAGE_URL -> $FULL_IMAGE"
  done
fi
```

**Exit if:** (only checked if build services exist)
- Cannot find build service ID
- sed command fails
- TOML update fails

---

### Step 8: Run TOML Deploy (Always runs)

```bash
# Deploy all services from aramb.toml (with or without built images)
echo "Deploying services from aramb.toml..."

aramb deploy --deploy-from-toml --yes 2>&1

if [ $? -ne 0 ]; then
  echo "ERROR: aramb deploy --deploy-from-toml failed"
  exit 1
fi

echo "✓ Deployment initiated"
```

**Exit if:** Deploy command fails

---

### Step 9: Return Deployment Details (Always runs)

```bash
# Get backend service name (first backend service found)
BACKEND_SERVICE=$(grep -A 5 'type = "backend"' aramb.toml | grep 'name = ' | head -1 | cut -d'"' -f2)

if [ -z "$BACKEND_SERVICE" ]; then
  echo "WARNING: No backend service found for PUBLIC_URL extraction"
  echo '{"status": "deployed", "services": "all", "build_skipped": '$SKIP_BUILD'}'
  exit 0
fi

# Get deployment status
DEPLOY_STATUS=$(aramb deploy status --service "$BACKEND_SERVICE" --output json 2>&1)

if [ $? -ne 0 ]; then
  echo "WARNING: Could not get deployment status for $BACKEND_SERVICE"
  echo '{"status": "deployed", "backend_service": "'$BACKEND_SERVICE'", "build_skipped": '$SKIP_BUILD'}'
  exit 0
fi

# Extract PUBLIC_URL
PUBLIC_URL=$(echo "$DEPLOY_STATUS" | jq -r '.outputs.PUBLIC_URL // empty')

# Calculate images built (0 if SKIP_BUILD=true)
if [ "$SKIP_BUILD" = true ]; then
  IMAGES_COUNT=0
else
  IMAGES_COUNT=$(echo "${!IMAGE_URLS[@]}" | wc -w)
fi

# Return deployment details
cat <<EOF
{
  "status": "success",
  "backend_service": "$BACKEND_SERVICE",
  "public_url": "$PUBLIC_URL",
  "build_skipped": $SKIP_BUILD,
  "images_built": $IMAGES_COUNT,
  "version_tag": "${VERSION_TAG:-n/a}"
}
EOF
```

**Exit if:** None (warnings only for status retrieval)

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

# Get version tag: use git commit SHA if available, otherwise generate simple tag
if git rev-parse --short HEAD &> /dev/null 2>&1; then
  VERSION_TAG=$(git rev-parse --short HEAD)
  echo "Using git commit SHA: $VERSION_TAG"
else
  VERSION_TAG="v$(date +%Y%m%d-%H%M%S)"
  echo "Git not available, using generated tag: $VERSION_TAG"
fi

# Build with DOCKER_REPOSITORY naming
aramb build --name "$DOCKER_REPOSITORY" --tag "$VERSION_TAG"

# Optional: Push to registry
if [ "$push_registry" = true ]; then
  aramb build --name "$DOCKER_REPOSITORY" --tag "$VERSION_TAG" --push
fi
```

**Output**: Docker image `{app-slug}/{build-service-slug}:{version-tag}`

Examples:
- With git: `my-app/backend-build:abc123` (commit SHA)
- Without git: `my-app/backend-build:v20260202-143022` (timestamp)

**Step 3c: Update backend service image in aramb.toml**

```bash
# Find the backend service that references this build service
# Update its image field in aramb.toml

# Before: image = "${101.outputs.IMAGE_URL}"
# After:  image = "my-app/backend-build:abc123" (or with timestamp tag)

# Use sed or toml editing tool to update the file
sed -i "s|image = \"\${101.outputs.IMAGE_URL}\"|image = \"${DOCKER_REPOSITORY}:${VERSION_TAG}\"|g" aramb.toml
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
   # Get version tag
   if git rev-parse --short HEAD &> /dev/null 2>&1; then
     VERSION_TAG=$(git rev-parse --short HEAD)
   else
     VERSION_TAG="v$(date +%Y%m%d-%H%M%S)"
   fi

   aramb build --name "$DOCKER_REPOSITORY" --tag "$VERSION_TAG"
   # Builds: my-app/backend-build:abc123 (or v20260202-143022)
   ```

4. **Update aramb.toml**:
   ```bash
   # Find backend service referencing this build service
   # Replace: image = "${101.outputs.IMAGE_URL}"
   # With:    image = "my-app/backend-build:abc123" (or timestamp tag)

   sed -i "s|image = \"\${101.outputs.IMAGE_URL}\"|image = \"${DOCKER_REPOSITORY}:${VERSION_TAG}\"|g" aramb.toml
   ```

### DOCKER_REPOSITORY Naming Convention

**Format**: `{app-slug}/{build-service-slug}:{version-tag}`

**Examples with git:**
- `my-app/backend-build:abc123` (commit SHA)
- `ecommerce/auth-service:def456` (commit SHA)
- `analytics/data-processor:789xyz` (commit SHA)

**Examples without git:**
- `my-app/backend-build:v20260202-143022` (timestamp)
- `ecommerce/auth-service:v20260202-150330` (timestamp)
- `analytics/data-processor:v20260202-162445` (timestamp)

**Benefits**:
- Namespace isolation by application
- Clear service identification
- Version tracking via commit SHA or timestamp
- Registry organization
- Works with or without git

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

# Get version tag
if git rev-parse --short HEAD &> /dev/null 2>&1; then
  VERSION_TAG=$(git rev-parse --short HEAD)
else
  VERSION_TAG="v$(date +%Y%m%d-%H%M%S)"
fi

cd <buildPath>
aramb build --name "$DOCKER_REPOSITORY" --tag "$VERSION_TAG"
```

**Output**:
- Docker image: `{app-slug}/{build-service-slug}:{version-tag}` (commit SHA or timestamp)
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

Report build and deployment results:

**With Build Services:**
```json
{
  "status": "success",
  "public_url": "https://backend-api.aramb.dev",
  "internal_url": "http://backend-api:8080",
  "application": {
    "id": "app-xyz789",
    "slug": "my-app"
  },
  "build_skipped": false,
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
    ]
  },
  "deployments": {
    "services": ["postgres-db", "backend-api"],
    "status": "success",
    "successful": ["postgres-db", "backend-api"],
    "failed": []
  },
  "all_healthy": true,
  "total_time": "2m30s"
}
```

**Without Build Services (Direct Deploy):**
```json
{
  "status": "success",
  "public_url": "https://backend-api.aramb.dev",
  "internal_url": "http://backend-api:8080",
  "build_skipped": true,
  "images_built": 0,
  "deployments": {
    "services": ["postgres-db", "backend-api"],
    "status": "success",
    "successful": ["postgres-db", "backend-api"],
    "failed": []
  },
  "all_healthy": true,
  "total_time": "30s"
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

**Step 5 - Build failed:**
```
ERROR: Build failed for backend-build
Step: 5 - Run Build Commands
Details: Image my-app/backend-build:abc123
Command: aramb build --name my-app/backend-build --tag abc123
```

**Step 7 - Deploy failed:**
```
ERROR: aramb deploy --deploy-from-toml failed
Step: 7 - Run TOML Deploy
Details: Check aramb.toml syntax and service configurations
```

### What NOT to Do

- ❌ Do NOT attempt to create aramb.toml if missing
- ❌ Do NOT try to login or authenticate
- ❌ Do NOT list applications or services
- ❌ Do NOT retry failed builds
- ❌ Do NOT suggest fixes or debug
- ❌ Do NOT proceed to next step if current fails

### What TO Do

- ✅ Log clear error message
- ✅ Exit immediately with exit code 1
- ✅ Return error details in output

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
