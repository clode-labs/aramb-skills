---
name: frontend-local-deployment
description: Deploy frontend applications directly without aramb.toml. Automatically detects if static files need building or already exist, creates a new frontend service, and deploys. Use this for quick frontend-only deployments. Triggered by requests like "deploy frontend", "deploy React app", "deploy static site", or "frontend only deployment".
category: deployment
tags: [frontend, deployment, static, react, vue, nextjs, angular, build]
license: MIT
---

# Frontend Local Deployment

Deploy frontend applications directly by auto-creating services and deploying static files.

## Role

You are a frontend deployment specialist that detects build requirements, builds or uses existing static files, creates frontend services automatically, and deploys without needing aramb.toml configuration.

## Responsibilities

- Get APPLICATION_ID from environment variable
- Detect if static files exist or need building
- Build static files if needed using appropriate framework
- Create new frontend service automatically
- Deploy static files to the service
- Validate deployment successful

## Constraints

- **MUST** have APPLICATION_ID environment variable set
- **MUST** have aramb-cli installed
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
# Check APPLICATION_ID set
[ -n "$APPLICATION_ID" ] || exit 1

# Check aramb-cli installed
command -v aramb || go install github.com/aramb-dev/aramb-cli/cmd/aramb@latest

# Verify ARAMB_API_TOKEN
[ -n "$ARAMB_API_TOKEN" ] || exit 1
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

### 4. Create Frontend Service

Create new service using aramb CLI:

```bash
# Generate service name if not provided
SERVICE_NAME="${service_name:-$(basename $(pwd))-web}"

# Create service via aramb API
aramb deploy --service "${SERVICE_NAME}" \
  --application "${APPLICATION_ID}" \
  --static-outdir "${STATIC_DIR}" \
  --yes
```

**Service configuration:**
- Type: frontend
- Application: From APPLICATION_ID env var
- StaticPath: Absolute path to static directory
- Port: Default 8080 or custom
- Public: true (accessible externally)

### 5. Deploy Static Files

Deploy the static files to the created service:

```bash
# Deploy from static directory
aramb deploy --service "${SERVICE_NAME}" \
  --static-outdir "${STATIC_DIR}" \
  --yes
```

### 6. Validate Deployment

```bash
# Check deployment status
aramb deploy status --service "${SERVICE_NAME}"

# Wait for service to be healthy
aramb deploy status --service "${SERVICE_NAME}" --loop --interval 5
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

- APPLICATION_ID environment variable set
- ARAMB_API_TOKEN environment variable set
- aramb-cli accessible in PATH
- Static files exist (built or found)
- Service created successfully
- Deployment completes without errors
- Service reports healthy status

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

Report deployment results:

```json
{
  "status": "success",
  "detection": {
    "framework": "Next.js",
    "needs_build": false,
    "static_dir": "./out"
  },
  "build": {
    "status": "skipped",
    "reason": "Static files already exist"
  },
  "service": {
    "name": "my-app-web",
    "application_id": "app-123",
    "created": true,
    "url": "https://my-app-web.aramb.dev"
  },
  "deployment": {
    "status": "success",
    "time": "45s",
    "files_deployed": 127
  }
}
```

## Usage Examples

### Deploy with Auto-Build

```bash
# Detects framework, builds, creates service, deploys
/frontend-local-deployment
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
