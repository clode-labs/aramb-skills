---
name: frontend-deployment
description: Deploy frontend applications with or without aramb.toml. If TOML exists, deploys from TOML first then static files. Otherwise auto-creates service. Automatically detects frameworks, builds static files, and returns deployment ID and URL. Use for all frontend deployments.
category: deployment
tags: [frontend, deployment, static, toml, react, vue, nextjs, angular, build]
license: MIT
---

# Frontend Deployment

Deploy frontend applications with TOML-based or auto-create workflows.

## Role

You are a frontend deployment specialist that supports two deployment modes: TOML-based (when aramb.toml exists) and auto-create (when no TOML). Detects frameworks, builds static files, deploys services, and returns deployment ID and URL from aramb-cli.

## Deployment Modes

**TOML Mode** (if aramb.toml exists):
1. Deploy services from TOML: `aramb deploy --deploy-from-toml`
2. Extract frontend service slug from aramb.toml
3. Build static files if needed
4. Deploy static files: `aramb deploy --service {slug} --static-outdir {path}`

**Auto Mode** (if no aramb.toml):
1. Requires APPLICATION_ID environment variable
2. Build static files if needed
3. Auto-generate service name
4. Create and deploy: `aramb deploy --service {name} --static-outdir {path}`

## Responsibilities

- Check for aramb.toml configuration file
- Deploy services from aramb.toml first
- Extract frontend service slug from TOML
- Detect if static files exist or need building
- Build static files if needed using appropriate framework
- Deploy static files to the frontend service
- Validate deployment successful
- Return deployment ID and URL

## Constraints

- **MUST** have APPLICATION_ID environment variable set
- **MUST** have aramb-cli (latest) installed from: https://github.com/aramb-ai/release-beta/releases/latest
- **Frontend only** - No backend, no database, no aramb.toml
- **Do NOT** create aramb.toml
- **Do NOT** deploy backend services
- **Do NOT** modify existing services

## Inputs

- `project_path`: Frontend project directory (default: current directory)
- `service_name`: Service name to create (default: auto-generate from directory name)
- `port`: Service port (default: 8080)
- `force_build`: Force rebuild even if static files exist (default: false)

## Workflow

### 1. Validate Environment

```bash
# Check aramb-cli installed
if ! command -v aramb &> /dev/null; then
  echo "aramb-cli not found. Install from:"
  echo "https://github.com/aramb-ai/release-beta/releases/latest"
  exit 1
fi

# Verify ARAMB_API_TOKEN
[ -n "$ARAMB_API_TOKEN" ] || exit 1

# Check for aramb.toml to determine deployment flow
if [ -f "aramb.toml" ]; then
  DEPLOY_MODE="toml"
  echo "Found aramb.toml - using TOML-based deployment"
else
  DEPLOY_MODE="auto"
  echo "No aramb.toml - using auto-create deployment"
  # For auto mode, APPLICATION_ID is required
  [ -n "$APPLICATION_ID" ] || exit 1
fi
```

### 2. Detect Static Files or Build Requirement

Scan project directory to determine action:

**Check for existing static files:**
```bash
# Common static file directories
if [ -d "dist" ] && [ -n "$(ls -A dist)" ]; then
  STATIC_DIR="dist"
elif [ -d "build" ] && [ -n "$(ls -A build)" ]; then
  STATIC_DIR="build"
elif [ -d "out" ] && [ -n "$(ls -A out)" ]; then
  STATIC_DIR="out"
elif [ -d "public" ] && [ -n "$(ls -A public)" ]; then
  STATIC_DIR="public"
else
  NEEDS_BUILD=true
fi
```

**Detect framework if build needed:**
- Check `package.json` for framework
- Identify: React, Vue, Next.js, Angular, Vite, or generic

### 3. Build Static Files (if needed)

If `NEEDS_BUILD=true` or `force_build=true`:

```bash
# Use aramb build to detect framework and build
aramb build --static-outdir ./dist

# Capture output directory
STATIC_DIR="./dist"  # or framework-specific
```

**Framework detection:**
- **Next.js**: `out/` directory
- **Create React App**: `build/` directory
- **Vite**: `dist/` directory
- **Vue CLI**: `dist/` directory
- **Angular**: `dist/` directory
- **Generic**: `dist/` directory

### 4. Deploy Services (TOML mode) OR Create Service (Auto mode)

**If DEPLOY_MODE="toml" (aramb.toml exists):**

```bash
# Step 4a: Deploy all services from TOML first
echo "Deploying services from aramb.toml..."
aramb deploy --deploy-from-toml --yes

# Step 4b: Extract frontend service slug from aramb.toml
# Parse the TOML to find the frontend service
SERVICE_SLUG=$(grep -A 10 '\[services\.' aramb.toml | grep -E 'type.*=.*"frontend"' -B 5 | grep '\[services\.' | sed 's/\[services\.//;s/\]//' | head -1)

if [ -z "$SERVICE_SLUG" ]; then
  echo "ERROR: No frontend service found in aramb.toml"
  exit 1
fi

echo "Found frontend service: $SERVICE_SLUG"
```

**If DEPLOY_MODE="auto" (no aramb.toml):**

```bash
# Generate service name if not provided
SERVICE_SLUG="${service_name:-$(basename $(pwd))-web}"

# Create service via aramb deploy
aramb deploy --service "${SERVICE_SLUG}" \
  --application "${APPLICATION_ID}" \
  --static-outdir "${STATIC_DIR}" \
  --yes
```

### 5. Deploy Static Files to Frontend Service

Deploy the static files to the frontend service:

```bash
# Deploy static files using the service slug
DEPLOY_OUTPUT=$(aramb deploy --service "${SERVICE_SLUG}" \
  --static-outdir "${STATIC_DIR}" \
  --yes 2>&1)

# Capture deployment ID and URL from aramb-cli output
# aramb-cli returns these values - parse them
DEPLOYMENT_ID=$(echo "$DEPLOY_OUTPUT" | grep -oP 'deployment_id:\s*\K[^\s]+' || echo "")
DEPLOYMENT_URL=$(echo "$DEPLOY_OUTPUT" | grep -oP 'url:\s*\K[^\s]+' || echo "")

echo "Deployment ID: $DEPLOYMENT_ID"
echo "Deployment URL: $DEPLOYMENT_URL"
```

### 6. Validate Deployment

```bash
# Check deployment status
aramb deploy status --service "${SERVICE_SLUG}"

# Verify deployment ID and URL were captured
if [ -z "$DEPLOYMENT_ID" ]; then
  echo "WARNING: deployment_id not captured from aramb-cli output"
fi

if [ -z "$DEPLOYMENT_URL" ]; then
  echo "WARNING: deployment_url not captured from aramb-cli output"
fi

# Wait for service to be healthy
aramb deploy status --service "${SERVICE_SLUG}" --loop --interval 5
```

## Deployment Flow Comparison

### TOML Mode (aramb.toml exists)

```
1. Validate environment
2. Detect/build static files
3. Deploy from TOML: aramb deploy --deploy-from-toml
4. Extract service slug from aramb.toml
5. Deploy static files: aramb deploy --service {slug} --static-outdir {path}
6. Return {id, url} from aramb-cli
```

### Auto Mode (no aramb.toml)

```
1. Validate environment (requires APPLICATION_ID)
2. Detect/build static files
3. Auto-generate service name
4. Create and deploy: aramb deploy --service {name} --static-outdir {path}
5. Return {id, url} from aramb-cli
```

## Detection Logic

### Framework Detection

Identify framework by checking project files:

**Next.js:**
```bash
# Check for next.config.js or next.config.mjs
[ -f "next.config.js" ] || [ -f "next.config.mjs" ]
→ Framework: Next.js, Output: out/
```

**Create React App:**
```bash
# Check package.json for react-scripts
grep -q "react-scripts" package.json
→ Framework: CRA, Output: build/
```

**Vite:**
```bash
# Check for vite.config.js/ts
[ -f "vite.config.js" ] || [ -f "vite.config.ts" ]
→ Framework: Vite, Output: dist/
```

**Vue CLI:**
```bash
# Check for vue.config.js
[ -f "vue.config.js" ]
→ Framework: Vue CLI, Output: dist/
```

**Angular:**
```bash
# Check for angular.json
[ -f "angular.json" ]
→ Framework: Angular, Output: dist/
```

**Generic/Static:**
```bash
# No framework detected, check for static files
[ -d "public" ] || [ -d "dist" ] || [ -d "build" ]
→ Use existing directory
```

### Build Decision Tree

```
Start
  ↓
Check --force-build flag?
  ├─ Yes → Build static files
  └─ No → Check for existing static files?
      ├─ Found → Use existing (skip build)
      └─ Not found → Detect framework → Build static files
```

## Service Creation

### Auto-Generated Service Name

Generate service name from project:

```bash
# Use directory name + "-web" suffix
DIR_NAME=$(basename $(pwd))
SERVICE_NAME="${DIR_NAME}-web"

# Sanitize: lowercase, replace spaces/special chars with hyphens
SERVICE_NAME=$(echo "$SERVICE_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')
```

Examples:
- `my-react-app/` → `my-react-app-web`
- `Frontend/` → `frontend-web`
- `nextjs_project/` → `nextjs-project-web`

### Service Configuration

Service created with:

```json
{
  "name": "my-app-web",
  "type": "frontend",
  "application_id": "<APPLICATION_ID>",
  "configuration": {
    "settings": {
      "staticPath": "/absolute/path/to/dist",
      "cmd": "npx http-server",
      "commandPort": 8080,
      "publicNet": true
    }
  }
}
```

## Validation Criteria

### Critical (MUST pass)

**For all deployments:**
- ARAMB_API_TOKEN environment variable set
- aramb-cli accessible in PATH
- Static files exist (built or found)
- Deployment completes without errors
- Service reports healthy status
- **deployment_id captured from aramb-cli**
- **deployment_url captured from aramb-cli**

**For TOML mode:**
- aramb.toml file exists
- TOML deployment succeeds: `aramb deploy --deploy-from-toml`
- Frontend service slug extracted from TOML
- Static files deployed to correct service

**For Auto mode:**
- APPLICATION_ID environment variable set
- Service created successfully

### Expected (SHOULD pass)

- Framework correctly detected
- Build completes without warnings
- Static files in expected location
- Service accessible via public URL

### Nice to Have

- Build optimized (minified, compressed)
- Service starts quickly
- Static files cached properly

## Output

**Required output format:**

```json
{
  "id": "deploy-abc123xyz",
  "url": "https://my-app-web.aramb.dev"
}
```

**Fields:**
- `id`: Deployment ID returned by aramb-cli
- `url`: Public URL returned by aramb-cli

**Extended output (optional):**

```json
{
  "id": "deploy-abc123xyz",
  "url": "https://my-app-web.aramb.dev",
  "deploy_mode": "toml",
  "service_slug": "my-app-web",
  "static_dir": "./dist",
  "framework": "React"
}
```

## Usage Examples

### Deploy with TOML (Recommended)

```bash
# Prerequisites: aramb.toml exists with frontend service configured
# Deploys from TOML, then deploys static files
/frontend-deployment
```

### Deploy with Auto-Build (No TOML)

```bash
# Prerequisites: APPLICATION_ID environment variable set
# Detects framework, builds, creates service, deploys
export APPLICATION_ID="app-123"
/frontend-deployment
```

### Deploy Existing Static Files

```bash
# Uses existing dist/ folder without building
# (if dist/ exists and contains files)
/frontend-local-deployment
```

### Force Rebuild

```bash
# Forces rebuild even if static files exist
/frontend-local-deployment --force-build
```

### Custom Service Name

```bash
# Creates service with custom name
/frontend-local-deployment --service-name my-custom-frontend
```

### Custom Port

```bash
# Deploys service on custom port
/frontend-local-deployment --port 3000
```

### Different Project Path

```bash
# Deploy from specific directory
/frontend-local-deployment --project-path /path/to/frontend
```

## Error Handling

### Missing APPLICATION_ID

```bash
if [ -z "$APPLICATION_ID" ]; then
  echo "Error: APPLICATION_ID environment variable not set"
  echo "Set it with: export APPLICATION_ID=your-app-id"
  exit 1
fi
```

### Build Failures

If build fails:
1. Log error with framework and build output
2. Exit without creating service
3. Provide troubleshooting guidance

### Service Creation Failures

If service creation fails:
1. Log error with API response
2. Check if service already exists
3. Suggest using different service name

### Deployment Failures

If deployment fails:
1. Log error with deployment details
2. Service may still exist (cleanup not automatic)
3. Retry deployment or delete service manually

## Framework-Specific Handling

### Next.js

```bash
# Detect
[ -f "next.config.js" ]

# Build command
npm run build

# Output directory
out/
```

### React (CRA)

```bash
# Detect
grep -q "react-scripts" package.json

# Build command
npm run build

# Output directory
build/
```

### Vite

```bash
# Detect
[ -f "vite.config.js" ]

# Build command
npm run build

# Output directory
dist/
```

### Vue CLI

```bash
# Detect
[ -f "vue.config.js" ]

# Build command
npm run build

# Output directory
dist/
```

### Angular

```bash
# Detect
[ -f "angular.json" ]

# Build command
ng build --configuration production

# Output directory
dist/<project-name>/
```

## Environment Variables

**Required:**
- `APPLICATION_ID` - Aramb application ID to deploy to
- `ARAMB_API_TOKEN` - API token for authentication

**Optional:**
- `BUILDKIT_HOST` - BuildKit server (only if custom build needed)
- `SERVICE_NAME` - Override auto-generated service name
- `PORT` - Override default port (8080)

## Best Practices

1. **Set APPLICATION_ID** before running deployment
2. **Clean build artifacts** if encountering issues (`rm -rf dist/ build/`)
3. **Use force-build** when you've made changes but static files exist
4. **Verify static files** are correctly built before deployment
5. **Test locally** with `npx http-server dist/` before deploying

## Common Scenarios

### Scenario 1: Fresh React Project

```bash
# Project has package.json, no build/ directory
/frontend-local-deployment

# Result:
# → Detects React
# → Runs npm run build
# → Creates build/ directory
# → Creates service "my-react-app-web"
# → Deploys from build/
```

### Scenario 2: Pre-built Next.js

```bash
# Project has out/ directory with files
/frontend-local-deployment

# Result:
# → Detects out/ directory
# → Skips build
# → Creates service "my-nextjs-app-web"
# → Deploys from out/
```

### Scenario 3: Static HTML Site

```bash
# Project has public/ directory with index.html
/frontend-local-deployment

# Result:
# → Detects public/ directory
# → No build needed
# → Creates service "my-site-web"
# → Deploys from public/
```

### Scenario 4: Force Rebuild

```bash
# Project has dist/ but you made changes
/frontend-local-deployment --force-build

# Result:
# → Ignores existing dist/
# → Detects framework
# → Rebuilds static files
# → Creates/updates service
# → Deploys from new dist/
```

## Differences from local-deploy

| Feature | local-deploy | frontend-local-deployment |
|---------|-------------|---------------------------|
| Requires aramb.toml | Yes | **No** |
| Backend services | Yes | **No** |
| Database services | Yes | **No** |
| Frontend services | Yes | **Yes** |
| Auto-create service | No | **Yes** |
| Build detection | Manual | **Automatic** |
| Service type | Multiple | **Frontend only** |

## Integration

### After backend-development

If backend is already deployed and you need to deploy frontend:

```bash
# 1. Backend deployed with backend-development skill
# 2. Frontend deployment (no configuration needed)
export APPLICATION_ID="app-123"
/frontend-local-deployment
```

### Standalone Frontend

For frontend-only applications (no backend):

```bash
# Just set APPLICATION_ID and deploy
export APPLICATION_ID="app-123"
/frontend-local-deployment
```

## Advanced Usage

See reference documentation:

- **Installation**: [references/installation.md](references/installation.md) - Setup guide
- **Troubleshooting**: [references/troubleshooting.md](references/troubleshooting.md) - Common issues
- **Frameworks**: [references/frameworks.md](references/frameworks.md) - Framework-specific details

## See Also

- **frontend-development**: Build frontend applications with components
- **local-deploy**: Full-stack deployment with aramb.toml
- **aramb-metadata**: Generate aramb.toml for complex deployments
