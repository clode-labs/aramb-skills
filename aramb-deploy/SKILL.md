---
name: aramb-deploy
description: Unified full-stack deployment for aramb applications. Deploys backend services first (builds Docker images, creates services, deploys), then frontend services (creates service, resolves backend URLs, deploys with environment variables). Use for complete application deployment from aramb.toml.
category: deployment
tags: [deployment, fullstack, backend, frontend, docker, build, unified]
license: MIT
---

# Aramb Deploy - Unified Full-Stack Deployment

Deploy complete applications from aramb.toml. Backend deployment takes priority, followed by frontend deployment with automatic backend reference resolution.

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

## Role

You are a unified deployment specialist that orchestrates application deployments. Supports three deployment types: **fullstack** (backend + frontend), **backend-only**, or **frontend-only**. For fullstack deployments, backend takes priority. **No debugging, no retries, no alternative flows.** If any step fails, exit immediately with error.

## Supported Deployment Types

### 1. Fullstack (Backend + Frontend)
```
aramb.toml contains:
- Backend service(s) (type="backend" or type="build")
- Frontend service (type="frontend")

Flow:
1. Deploy backend services
2. Get backend PUBLIC_URL
3. Deploy frontend with resolved backend URL
```

### 2. Backend-Only
```
aramb.toml contains:
- Backend service(s) only
- No frontend service

Flow:
1. Deploy backend services
2. Get backend PUBLIC_URL
3. Skip frontend phase
4. Return backend-only output
```

### 3. Frontend-Only
```
aramb.toml contains:
- Frontend service only
- No backend service

Flow:
1. Skip backend phase
2. Deploy frontend service
3. Return frontend-only output

⚠️ RESTRICTION: Frontend CANNOT have backend references (${}) if no backend exists
```

## Critical Flow (Strict Order - No Deviations)

**IMPORTANT**: Follow this exact sequence. If ANY step fails, EXIT immediately with error message. Do NOT attempt to:
- Debug the issue
- Login or authenticate
- List resources
- Try alternative approaches
- Fix or recover from errors

**The Flow:**
0. **Install aramb-cli (CRITICAL FIRST STEP - if installation fails, EXIT immediately)**
0.5. **Check BUILDKIT_HOST is set (CRITICAL - aramb-cli uses remote BuildKit for builds)**
1. Read aramb.toml

**BACKEND DEPLOYMENT PHASE (If backend services exist):**
2. **Deploy TOML (create all services - if ANY service creation fails, EXIT immediately)**
3. Extract build services (optional - if none exist, skip to step 8)
4. Get application slug (only if build services exist)
5. Identify build service dependencies (only if build services exist)
6. **Build & deploy each backend service using `aramb build --push --deploy --service` (only if build services exist)**
7. Wait for backend deployments to complete (only if build services exist)
8. **Get backend PUBLIC_URL (if backend exists)**

**FRONTEND DEPLOYMENT PHASE (If frontend service exists):**
9. Create frontend service
10. **Validate backend references (EXIT if frontend needs backend but none exists)**
11. Detect/build static files
12. Deploy frontend with environment variables
13. Validate frontend deployment

**COMPLETION:**
14. Return deployment details (backend + frontend, or backend-only, or frontend-only)

**If any step fails → Exit with error. No recovery attempts.**
**Backend MUST complete successfully before frontend starts.**
**Step 0 is MANDATORY → If aramb-cli installation fails, EXIT immediately. Do NOT debug or fix.**
**Step 0.5 is MANDATORY → BUILDKIT_HOST must be set for remote builds.**
**Step 2 is CRITICAL → Deploy TOML first to create services. If ANY service creation fails, EXIT.**

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│           UNIFIED DEPLOYMENT FLOW (STRICT ORDER)            │
│                    (NO DEVIATIONS)                          │
└──────────────────────────────────��──────────────────────────┘

Step 0: Install aramb-cli (CRITICAL FIRST STEP)
   ↓
   ├─ ✓ Already installed → Continue
   ├─ ✗ Not installed → Install from GitHub latest release
   │    ├─ ✓ Installation succeeds → Continue to Step 0.5
   │    └─ ✗ Installation fails → EXIT: "Failed to install aramb-cli" (DO NOT DEBUG)
   └─ ✗ Installation error → EXIT: "Failed to install aramb-cli" (DO NOT DEBUG)

Step 0.5: Check BUILDKIT_HOST (CRITICAL)
   ↓
   ├─ ✓ BUILDKIT_HOST is set → Continue
   └─ ✗ BUILDKIT_HOST not set → EXIT: "BUILDKIT_HOST not set"

Step 1: Read aramb.toml
   ���
   ├─ ✓ Found → Continue
   └─ ✗ Not found → EXIT: "aramb.toml not found"

┌─────────────────────────────────────────────────────────────┐
│          BACKEND DEPLOYMENT PHASE (PRIORITY)                │
└─────────────────────────────────────────────────────────────┘

Step 2: Deploy from TOML (Create All Services)
   ↓
   ├─ ✓ All services created (Status: Created) → Continue
   └─ ✗ Any service creation fails → EXIT: "Service creation failed"

Step 3: Extract Build Services
   ↓
   ├─ ✓ Found build services → Continue to Step 4
   └─ ✗ No build services → SKIP to Step 8 (get backend URL)

Step 4: Get Application Slug (if build services exist)
   ↓
   ├─ ✓ Got slug → Continue
   └─ ✗ Failed → EXIT: "Failed to retrieve application slug"

Step 5: Identify Dependencies (if build services exist)
   ↓
   └─ ✓ Map build services to backend services

Step 6: Build & Deploy Each Backend Service (if build services exist)
   ↓
   For each backend service:
   ├─ Run: aramb build --push --deploy --name {build-slug} {path} --service {backend-slug}
   ├─ ✓ Build & deploy succeed → Continue to next
   └─ ✗ Build or deploy fails → EXIT: "Backend build/deploy failed"

Step 7: Wait for Backend Deployments (if build services exist)
   ↓
   ├─ ✓ All deployments healthy → Continue
   └─ ✗ Any deployment fails → EXIT: "Backend deployment failed"

Step 8: Get Backend PUBLIC_URL
   ↓
   ├─ ✓ URL retrieved → Continue to FRONTEND PHASE
   └─ ✗ URL retrieval fails → EXIT: "Cannot get backend URL"

┌─────────────────────────────────────────────────────────────┐
│       FRONTEND DEPLOYMENT PHASE (After Backend Success)    │
└─────────────────────────────────────────────────────────────┘

Step 9: Create Frontend Service
   ↓
   ├─ ✓ Service created → Continue
   └─ ✗ Creation fails → EXIT: "Frontend service creation failed"

Step 10: Resolve Backend References
   ↓
   ├─ ✓ Backend URL from Step 8 → Use for env vars
   └─ ✗ No backend URL → Use empty (if no references needed)

Step 11: Detect/Build Static Files
   ↓
   ├─ ✓ Static files ready → Continue
   └─ ✗ Build fails → EXIT: "Frontend build failed"

Step 12: Deploy Frontend with Environment Variables
   ↓
   ├─ ✓ Deploy succeeds → Continue
   └─ ✗ Deploy fails → EXIT: "Frontend deployment failed"

Step 13: Validate Frontend Deployment
   ↓
   ├─ ✓ Deployment healthy → Continue
   └─ ✗ Deployment fails → EXIT: "Frontend validation failed"

┌─────────────────────────────────────────────────────────────┐
│                   COMPLETION PHASE                          │
└─────────────────────────────────────────────────────────────┘

Step 14: Return Deployment Details
   ↓
   └─ ✓ Return: {backend_url, frontend_url, status, services}

════════════════════════════════════════════════════════════

ANY ERROR → IMMEDIATE EXIT
NO DEBUGGING | NO RETRIES | NO ALTERNATIVES
BACKEND FIRST → Frontend only starts after backend succeeds
BUILDKIT_HOST IS MANDATORY → Must be set for builds
ARAMB-CLI IS MANDATORY → NEVER attempt to debug or fix
USE SERVICE SLUG → For all status checks and commands
```

## Compact Workflow (Precise Logic)

```bash
#!/bin/bash
set -e  # Exit on any error

# ========================================
# PREREQUISITES
# ========================================

# Step 0: Install aramb-cli if not present (CRITICAL FIRST STEP)
if ! command -v aramb &> /dev/null; then
  echo "Installing aramb-cli..."
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m)

  if [ "$ARCH" = "x86_64" ]; then ARCH="amd64"
  elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then ARCH="arm64"; fi

  BINARY_NAME="aramb-${OS}-${ARCH}"
  curl -LO "https://github.com/aramb-ai/release-beta/releases/latest/download/${BINARY_NAME}" || { echo "ERROR: Failed to download aramb-cli"; exit 1; }
  chmod +x "${BINARY_NAME}"
  sudo mv "${BINARY_NAME}" /usr/local/bin/aramb || { echo "ERROR: Failed to install aramb-cli"; exit 1; }
  echo "✓ aramb-cli installed successfully"
else
  echo "✓ aramb-cli already installed"
fi

# Step 0.5: Check BUILDKIT_HOST is set (CRITICAL)
if [ -z "$BUILDKIT_HOST" ]; then
  echo "ERROR: BUILDKIT_HOST environment variable not set"
  exit 1
fi
echo "✓ BUILDKIT_HOST is set: $BUILDKIT_HOST"

# Step 1: Validate aramb.toml exists
[ -f "aramb.toml" ] || { echo "ERROR: aramb.toml not found"; exit 1; }
[ -n "$ARAMB_API_TOKEN" ] || { echo "ERROR: ARAMB_API_TOKEN not set"; exit 1; }
[ -n "$APPLICATION_ID" ] || { echo "ERROR: APPLICATION_ID not set"; exit 1; }

# ========================================
# BACKEND DEPLOYMENT PHASE (PRIORITY)
# ========================================

echo "════════════════════════════════════════════════"
echo "  BACKEND DEPLOYMENT PHASE (PRIORITY)"
echo "════════════════════════════════════════════════"

# Step 2: Deploy from TOML (create all services)
echo "Creating services from aramb.toml..."
DEPLOY_OUTPUT=$(aramb deploy --deploy-from-toml 2>&1)
echo "$DEPLOY_OUTPUT"

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
  APP_SLUG=$(aramb applications get -i "$APPLICATION_ID" -o json | jq -r '.slug')
  [ "$APP_SLUG" != "null" ] || { echo "ERROR: Failed to get app slug"; exit 1; }
  echo "✓ Application slug: $APP_SLUG"

  # Step 5: Identify dependencies
  declare -A BUILD_PATHS BUILD_SLUGS BACKEND_SLUGS

  for BUILD_SERVICE in $BUILD_SERVICES; do
    BUILD_SLUG=$(grep -A 10 "name = \"$BUILD_SERVICE\"" aramb.toml | grep 'slug = ' | head -1 | cut -d'"' -f2)
    BUILD_PATH=$(grep -A 10 "name = \"$BUILD_SERVICE\"" aramb.toml | grep 'buildPath = ' | head -1 | cut -d'"' -f2)
    BUILD_ID=$(grep -A 10 "name = \"$BUILD_SERVICE\"" aramb.toml | grep 'uniqueIdentifier = ' | head -1 | awk '{print $3}')

    BUILD_SLUGS[$BUILD_SERVICE]=$BUILD_SLUG
    BUILD_PATHS[$BUILD_SERVICE]=$BUILD_PATH

    BACKEND_SLUG=$(grep -B 15 "\${${BUILD_ID}.outputs.IMAGE_URL}" aramb.toml | grep 'slug = ' | tail -1 | cut -d'"' -f2)
    BACKEND_SLUGS[$BUILD_SERVICE]=$BACKEND_SLUG

    echo "✓ Build service: $BUILD_SERVICE → Backend: $BACKEND_SLUG"
  done

  # Step 6: Build & deploy each backend service
  for BUILD_SERVICE in $BUILD_SERVICES; do
    BUILD_SLUG=${BUILD_SLUGS[$BUILD_SERVICE]}
    BUILD_PATH=${BUILD_PATHS[$BUILD_SERVICE]}
    BACKEND_SLUG=${BACKEND_SLUGS[$BUILD_SERVICE]}

    echo "Building and deploying: $BUILD_SERVICE → $BACKEND_SLUG"
    export DOCKER_REPOSITORY="${APP_SLUG}/${BUILD_SLUG}"

    aramb build --push --deploy --name "$BUILD_SLUG" "$BUILD_PATH" --service "$BACKEND_SLUG" || {
      echo "ERROR: Backend build/deploy failed for $BUILD_SERVICE"
      exit 1
    }
    echo "✓ Successfully built and deployed: $BUILD_SERVICE"
  done

  # Step 7: Wait for deployments
  echo "Waiting for backend deployments to complete..."
  sleep 5
fi

# Step 8: Get backend PUBLIC_URL (CRITICAL for frontend)
BACKEND_SLUG=$(grep -A 5 'type = "backend"' aramb.toml | grep 'slug = ' | head -1 | cut -d'"' -f2 || echo "")
BACKEND_PUBLIC_URL=""

if [ -n "$BACKEND_SLUG" ]; then
  BACKEND_STATUS=$(aramb deploy status --service "$BACKEND_SLUG" --output json 2>/dev/null)
  BACKEND_PUBLIC_URL=$(echo "$BACKEND_STATUS" | jq -r '.outputs.PUBLIC_URL // empty')

  if [ -z "$BACKEND_PUBLIC_URL" ]; then
    echo "WARNING: Could not get backend PUBLIC_URL"
  else
    echo "✓ Backend PUBLIC_URL: $BACKEND_PUBLIC_URL"
  fi
  echo "✓ Backend deployment complete"
else
  echo "ℹ No backend service found in TOML"
fi

# ========================================
# FRONTEND DEPLOYMENT PHASE
# ========================================

echo ""
echo "════════════════════════════════════════════════"
echo "  FRONTEND DEPLOYMENT PHASE"
echo "════════════════════════════════════════════════"

# Check if frontend service exists
FRONTEND_NAME=$(grep -A 10 'type = "frontend"' aramb.toml | grep 'name = ' | head -1 | cut -d'"' -f2 || echo "")

if [ -z "$FRONTEND_NAME" ]; then
  echo "ℹ No frontend service found - deployment complete"

  # Check if backend exists
  if [ -n "$BACKEND_SLUG" ]; then
    # Backend-only deployment
    cat <<EOF
{
  "status": "success",
  "deployment_type": "backend-only",
  "backend": {
    "slug": "$BACKEND_SLUG",
    "public_url": "$BACKEND_PUBLIC_URL"
  },
  "frontend": null
}
EOF
  else
    # No backend and no frontend - invalid TOML
    echo "ERROR: No backend or frontend services found in aramb.toml"
    exit 1
  fi
  exit 0
fi

# Step 9: Create frontend service
FRONTEND_DESC=$(grep -A 10 'type = "frontend"' aramb.toml | grep 'description = ' | head -1 | cut -d'"' -f2)

echo "Creating frontend service: $FRONTEND_NAME"
aramb services create \
  --name "$FRONTEND_NAME" \
  --type frontend \
  --description "${FRONTEND_DESC:-Frontend service}" \
  --application "$APPLICATION_ID" \
  --tags frontend,aramb || { echo "ERROR: Frontend service creation failed"; exit 1; }

FRONTEND_SLUG=$(grep -A 10 'type = "frontend"' aramb.toml | grep 'slug = ' | head -1 | cut -d'"' -f2)
echo "✓ Frontend service created: $FRONTEND_SLUG"

# Step 10: Validate backend references
# Check if frontend has backend references
HAS_BACKEND_REFS=$(grep -A 50 'type = "frontend"' aramb.toml | grep -E '\$\{.*\.outputs\.' || echo "")

if [ -n "$HAS_BACKEND_REFS" ]; then
  # Frontend has backend references
  if [ -z "$BACKEND_PUBLIC_URL" ]; then
    echo "ERROR: Frontend has backend references but no backend service found or backend URL unavailable"
    echo "Frontend cannot be deployed without backend"
    exit 1
  fi
  echo "✓ Backend URL available for frontend: $BACKEND_PUBLIC_URL"
else
  echo "ℹ No backend references in frontend configuration"
fi

# Step 11: Detect/build static files
BUILD_PATH=$(grep -A 15 'type = "frontend"' aramb.toml | grep 'buildPath = ' | head -1 | cut -d'"' -f2)
STATIC_DIR="${BUILD_PATH:-dist}"

if [ ! -d "$STATIC_DIR" ] || [ -z "$(ls -A $STATIC_DIR)" ]; then
  echo "Building static files..."
  if [ -f "package.json" ]; then
    npm install
    npm run build || { echo "ERROR: Frontend build failed"; exit 1; }
  fi
  echo "✓ Build complete"
else
  echo "✓ Using existing static files: $STATIC_DIR"
fi

# Step 12: Prepare environment variables and deploy
declare -a ENV_VARS

# Extract vars from services.configuration.vars
VARS_SECTION=$(grep -A 50 'type = "frontend"' aramb.toml | sed -n '/\[.*\.configuration\.vars\]/,/^\[/p' | head -n -1)

if [ -n "$VARS_SECTION" ]; then
  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*([A-Z_][A-Z0-9_]*)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
      VAR_NAME="${BASH_REMATCH[1]}"
      VAR_VALUE=$(echo "${BASH_REMATCH[2]}" | sed 's/^"//;s/"$//')

      if [[ "$VAR_VALUE" == *'${'* ]] && [ -n "$BACKEND_PUBLIC_URL" ]; then
        ENV_VARS+=("--env" "${VAR_NAME}=${BACKEND_PUBLIC_URL}")
        echo "✓ Resolved: $VAR_NAME=$BACKEND_PUBLIC_URL"
      elif [[ "$VAR_VALUE" != *'${'* ]]; then
        ENV_VARS+=("--env" "${VAR_NAME}=${VAR_VALUE}")
        echo "✓ Set: $VAR_NAME=$VAR_VALUE"
      fi
    fi
  done <<< "$VARS_SECTION"
fi

# Deploy frontend with environment variables
echo "Deploying frontend to: $FRONTEND_SLUG"
DEPLOY_CMD="aramb deploy ${STATIC_DIR}/ --service ${FRONTEND_SLUG}"
[ ${#ENV_VARS[@]} -gt 0 ] && DEPLOY_CMD="$DEPLOY_CMD ${ENV_VARS[@]}"

FRONTEND_DEPLOY_OUTPUT=$(eval "$DEPLOY_CMD" 2>&1) || {
  echo "ERROR: Frontend deployment failed"
  exit 1
}
echo "✓ Frontend deployed successfully"

# Step 13: Validate frontend deployment
FRONTEND_STATUS=$(aramb deploy status --service "$FRONTEND_SLUG" --output json 2>/dev/null)
FRONTEND_PUBLIC_URL=$(echo "$FRONTEND_STATUS" | jq -r '.outputs.PUBLIC_URL // empty')

if [ -z "$FRONTEND_PUBLIC_URL" ]; then
  echo "WARNING: Could not get frontend PUBLIC_URL"
else
  echo "✓ Frontend PUBLIC_URL: $FRONTEND_PUBLIC_URL"
fi

# ========================================
# COMPLETION
# ========================================

echo ""
echo "════════════════════════════════════════════════"
echo "  DEPLOYMENT COMPLETE"
echo "════════════════════════════════════════════════"

# Step 14: Return deployment details
# Determine deployment type
if [ -n "$BACKEND_SLUG" ] && [ -n "$FRONTEND_SLUG" ]; then
  DEPLOYMENT_TYPE="fullstack"
elif [ -n "$BACKEND_SLUG" ]; then
  DEPLOYMENT_TYPE="backend-only"
else
  DEPLOYMENT_TYPE="frontend-only"
fi

# Return appropriate output based on type
if [ "$DEPLOYMENT_TYPE" = "fullstack" ]; then
  cat <<EOF
{
  "status": "success",
  "deployment_type": "fullstack",
  "backend": {
    "slug": "$BACKEND_SLUG",
    "public_url": "$BACKEND_PUBLIC_URL"
  },
  "frontend": {
    "slug": "$FRONTEND_SLUG",
    "public_url": "$FRONTEND_PUBLIC_URL"
  },
  "services_deployed": {
    "backend": "$BACKEND_SLUG",
    "frontend": "$FRONTEND_SLUG"
  }
}
EOF
elif [ "$DEPLOYMENT_TYPE" = "frontend-only" ]; then
  cat <<EOF
{
  "status": "success",
  "deployment_type": "frontend-only",
  "backend": null,
  "frontend": {
    "slug": "$FRONTEND_SLUG",
    "public_url": "$FRONTEND_PUBLIC_URL"
  }
}
EOF
fi
```

## Constraints

### Strict Flow Requirements

- **MUST** install aramb-cli as FIRST and FOREMOST step (Step 0) - **CRITICAL**
- **MUST** check BUILDKIT_HOST is set (Step 0.5) - **CRITICAL**
- **MUST** exit immediately if aramb-cli installation fails
- **MUST NOT** attempt to debug or fix installation failures
- **MUST** deploy TOML first to create all services (Step 2) - **CRITICAL**
- **MUST** exit if ANY service creation fails
- **MUST** complete backend deployment before starting frontend
- **MUST** get backend PUBLIC_URL before frontend deployment
- **MUST** use service SLUG (not name) for all commands
- **MUST** follow the exact flow (no deviations)
- **MUST** exit immediately on any error (no recovery)

### Exit Immediately If:

- aramb-cli installation fails (Step 0) - **EXIT, do NOT debug**
- BUILDKIT_HOST not set (Step 0.5) - **EXIT**
- aramb.toml not found (Step 1) - **EXIT**
- ANY service creation fails (Step 2) - **EXIT**
- APPLICATION_ID not set - **EXIT**
- Backend build/deploy fails (Step 6) - **EXIT**
- Backend URL retrieval fails (Step 8) - **EXIT**
- Frontend service creation fails (Step 9) - **EXIT**
- Frontend build fails (Step 11) - **EXIT**
- Frontend deployment fails (Step 12) - **EXIT**

### No Recovery Allowed

- **NO** retry logic
- **NO** debugging
- **NO** error recovery
- **NO** alternative flows
- **EXIT** with clear error message

## Deployment Priority

**Backend deployment has absolute priority:**

1. **All backend services MUST complete successfully**
2. **Backend PUBLIC_URL MUST be available**
3. **Only then proceed to frontend deployment**

**If backend fails at any point:**
- Frontend deployment is **NEVER** started
- Exit immediately with backend error
- No partial deployments

## Validation Criteria

### Critical (MUST pass)

**Environment:**
- aramb-cli accessible in PATH
- BUILDKIT_HOST environment variable set
- ARAMB_API_TOKEN environment variable set
- APPLICATION_ID environment variable set
- aramb.toml exists and valid

**Backend Phase:**
- All services created (Status: Created)
- Build services identified correctly
- Backend services built and deployed successfully
- Backend deployments report healthy status
- Backend PUBLIC_URL retrieved successfully

**Frontend Phase (only runs if backend succeeds):**
- Frontend service created successfully
- Backend URL resolved for environment variables
- Static files built or found
- Frontend deployed with resolved env vars
- Frontend deployment reports healthy status
- Frontend PUBLIC_URL retrieved successfully

**Final Validation:**
- Both backend and frontend report healthy status
- Both PUBLIC_URLs accessible
- No deployment errors
- Complete deployment details returned

## Output Requirements

Before completing, you MUST set comprehensive outputs:

```python
outputs = {
    # Backend details (CRITICAL)
    "backend_slug": "backend-api-548cad1",
    "backend_url": "https://backend-api.aramb.dev",
    "backend_status": "healthy",

    # Frontend details (if deployed)
    "frontend_slug": "frontend-web-abc123",
    "frontend_url": "https://frontend-web.aramb.dev",
    "frontend_status": "healthy",

    # Application info
    "application_id": "app-xyz789",
    "application_slug": "my-app",

    # Deployment info
    "deployment_type": "fullstack",  # or "backend-only"
    "services_deployed": ["backend-api-548cad1", "frontend-web-abc123"],
    "images_built": 1,

    # Status
    "status": "success",
    "all_healthy": true
}
```

## Output

Report complete deployment results for all three supported types:

**Type 1: Fullstack Deployment (Backend + Frontend):**
```json
{
  "status": "success",
  "deployment_type": "fullstack",
  "backend": {
    "slug": "backend-api-548cad1",
    "public_url": "https://backend-api.aramb.dev",
    "status": "healthy"
  },
  "frontend": {
    "slug": "frontend-web-abc123",
    "public_url": "https://frontend-web.aramb.dev",
    "status": "healthy"
  },
  "services_deployed": {
    "backend": "backend-api-548cad1",
    "frontend": "frontend-web-abc123"
  }
}
```

**Type 2: Backend-Only Deployment:**
```json
{
  "status": "success",
  "deployment_type": "backend-only",
  "backend": {
    "slug": "backend-api-548cad1",
    "public_url": "https://backend-api.aramb.dev",
    "status": "healthy"
  },
  "frontend": null
}
```

**Type 3: Frontend-Only Deployment:**
```json
{
  "status": "success",
  "deployment_type": "frontend-only",
  "backend": null,
  "frontend": {
    "slug": "frontend-web-abc123",
    "public_url": "https://frontend-web.aramb.dev",
    "status": "healthy"
  }
}
```

## Error Handling (Strict Exit Policy)

### All Errors = Immediate Exit

**No error recovery. No debugging. No retries.**

### Error Message Format

```bash
echo "ERROR: {specific error message}"
echo "Phase: {BACKEND or FRONTEND}"
echo "Step: {step number and name}"
echo "Details: {relevant context}"
exit 1
```

### Example Error Messages

**Backend Phase - Step 2:**
```
ERROR: Service creation failed
Phase: BACKEND
Step: 2 - Deploy from TOML
Details: One or more services failed to create (Status: Failed)
```

**Backend Phase - Step 6:**
```
ERROR: Backend build/deploy failed for backend-build
Phase: BACKEND
Step: 6 - Build & Deploy Backend Service
Details: aramb build --push --deploy failed
```

**Frontend Phase - Step 9:**
```
ERROR: Frontend service creation failed
Phase: FRONTEND
Step: 9 - Create Frontend Service
Details: aramb services create returned error
Note: Backend deployment completed successfully
```

### What NOT to Do

- ❌ Do NOT attempt to create aramb.toml if missing
- ❌ Do NOT try to login or authenticate
- ❌ Do NOT list applications or services
- ❌ Do NOT retry failed builds
- ❌ Do NOT suggest fixes or debug
- ❌ Do NOT proceed to next step if current fails
- ❌ Do NOT start frontend if backend fails
- ❌ Do NOT manually update TOML files

### What TO Do

- ✅ Log clear error message with phase
- ✅ Exit immediately with exit code 1
- ✅ Return error details in output
- ✅ Use service SLUG in error messages
- ✅ Indicate which phase failed

## Best Practices

1. **Verify aramb.toml** contains both backend and frontend services
2. **Check environment variables** before starting (BUILDKIT_HOST, APPLICATION_ID)
3. **Monitor backend deployment** until all services healthy
4. **Extract backend URL** immediately after backend succeeds
5. **Use backend URL** for frontend environment variable resolution
6. **Validate both deployments** before returning success

## Integration

### Complete Deployment Workflow

```
User Request
    ↓
/aramb-metadata (creates aramb.toml with backend + frontend)
    ↓
/aramb-deploy (unified deployment)
    ├─ BACKEND PHASE
    │  ├─ Deploy TOML (create services)
    │  ├─ Build & deploy backend
    │  └─ Get backend PUBLIC_URL
    ↓
    ├─ FRONTEND PHASE (only if backend succeeds)
    │  ├─ Create frontend service
    │  ├─ Resolve backend URL for env vars
    │  ├─ Build static files
    │  └─ Deploy frontend
    ↓
All Services Running
    ├─ Backend: https://backend-api.aramb.dev
    └─ Frontend: https://frontend-web.aramb.dev
```

## See Also

- **aramb-metadata**: Generate aramb.toml for complete applications
- **backend-deployment**: Standalone backend deployment
- **frontend-deployment**: Standalone frontend deployment
