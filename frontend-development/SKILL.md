---
name: frontend-development
description: Build modern frontend applications using React, Vue, or vanilla JavaScript. Use this skill for creating UI components, pages, forms, and interactive web interfaces with proper styling, accessibility, and responsive design.
category: development
tags: [frontend, react, typescript, components, ui, accessibility]
license: MIT
---

# Frontend Development

Build components following project patterns. Write accessible, responsive code with TypeScript.

**CRITICAL DEPLOYMENT REQUIREMENT**: This skill MUST deploy using `aramb` CLI only. Get APPLICATION_ID from environment variable. Never deploy locally or create new applications. Always include deployment_url and deployment_id in outputs.

## Inputs

- `requirements`: What to build
- `files_to_create`: Files to create
- `files_to_modify`: Existing files to modify
- `patterns_to_follow`: Reference patterns in codebase
- `service_name`: (Optional) Name for the deployed service (default: auto-generate)
- `validation_criteria`: Self-validation criteria
  - `critical`: MUST pass before completing (e.g., "TypeScript compiles", "Deployed via aramb-cli", "deployment_url accessible")
  - `expected`: SHOULD pass (log warning if not)
  - `nice_to_have`: Optional improvements

**Example validation_criteria for deployment:**
```json
{
  "critical": [
    "TypeScript compiles without errors",
    "APPLICATION_ID environment variable is set",
    "aramb-cli deployment completed successfully",
    "deployment_url is accessible",
    "deployment_id received from aramb-cli"
  ],
  "expected": [
    "Build optimized for production",
    "Static files served correctly",
    "Service responds with 200 OK"
  ],
  "nice_to_have": [
    "Fast page load time",
    "Assets cached properly"
  ]
}
```

## Constraints

- Functional components and hooks only
- Semantic HTML elements
- **Do NOT create documentation files** unless explicitly requested
- **For new projects**: Include test dependencies in package.json (vitest, @testing-library/react)

### Deployment Constraints

- **MUST** use `aramb` CLI for deployment - NEVER deploy locally or use other methods
- **MUST** get APPLICATION_ID from environment variable - NEVER create a new application
- **MUST** verify APPLICATION_ID is set before deployment: `[ -n "$APPLICATION_ID" ]`
- **MUST** use `aramb deploy` commands exclusively for deployment
- **Do NOT** run local servers (like `npm run dev`) as deployment
- **Do NOT** create Docker containers manually
- **Do NOT** use other deployment tools (vercel, netlify, etc.)

## Self-Validation

Before completing, verify `validation_criteria.critical` items pass:
1. Run each critical check (e.g., `npx tsc --noEmit`, `npm run lint`, `npm run dev`)
2. If a check fails, fix and re-run
3. Only complete when all critical criteria pass

## Deployment

**IMPORTANT**: Use aramb-cli ONLY for deployment. Never deploy locally.

### Prerequisites

1. **Verify APPLICATION_ID is set:**
   ```bash
   if [ -z "$APPLICATION_ID" ]; then
     echo "ERROR: APPLICATION_ID environment variable not set"
     exit 1
   fi
   ```

2. **Verify aramb-cli is installed:**
   ```bash
   command -v aramb || {
     echo "ERROR: aramb-cli not found. Install from:"
     echo "https://github.com/aramb-ai/release-beta/releases/tag/v0.0.11-beta1"
     exit 1
   }
   ```

### Deployment Steps

**For static file deployment:**
```bash
# Build static files first
npm run build

# Deploy using aramb-cli (captures output for URL and ID)
aramb deploy --service <service-name> \
  --application "$APPLICATION_ID" \
  --static-outdir ./dist \
  --yes
```

**The aramb deploy command will output:**
- `deployment_id`: Unique deployment identifier
- `deployment_url`: Public URL where the app is accessible

**Capture the output** and include it in your task output.

### Example Deployment

```bash
# Build
npm run build

# Deploy
DEPLOY_OUTPUT=$(aramb deploy --service my-frontend \
  --application "$APPLICATION_ID" \
  --static-outdir ./dist \
  --yes 2>&1)

# Parse deployment ID and URL from output
# aramb-cli returns these values
```

### What NOT to Do

- ❌ Do NOT run `npm run dev` and call it deployment
- ❌ Do NOT start local servers
- ❌ Do NOT use Docker commands directly
- ❌ Do NOT create APPLICATION_ID (it must exist in env)
- ❌ Do NOT use vercel, netlify, or other platforms

### Verify Deployment

After deployment, verify it was successful:

```bash
# Check deployment status
aramb deploy status --service <service-name>

# Should show: status = "deployed" or "running"
```

**Critical validation:**
- Deployment command completed without errors
- deployment_id received from aramb-cli
- deployment_url received from aramb-cli
- Service is accessible at deployment_url

## Output

**Required fields:**
```json
{
  "files_created": ["src/components/Feature.tsx"],
  "files_modified": ["src/App.tsx"],
  "self_validation": {
    "critical_passed": true,
    "checks_run": ["TypeScript compiles", "ESLint passes", "Dev server starts"]
  },
  "deployment": {
    "deployment_id": "deploy-abc123",
    "deployment_url": "https://my-frontend.aramb.dev",
    "application_id": "app-xyz789",
    "service_name": "my-frontend",
    "status": "deployed"
  }
}
```

**Deployment fields MUST be included:**
- `deployment_id`: ID returned by aramb-cli
- `deployment_url`: Public URL returned by aramb-cli
- `application_id`: APPLICATION_ID from environment
- `service_name`: Name of the deployed service
- `status`: Deployment status (deployed, failed, pending)
