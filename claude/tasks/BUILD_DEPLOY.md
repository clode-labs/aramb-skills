# Build & Deploy Commands

## Build Command

Build container images or static frontend applications.

### Docker Image Builds

```bash
# Build image from current directory
aramb build

# Build and push to registry
aramb build --push

# Build, push, and deploy
aramb build --push --deploy

# Build with custom tag
aramb build --tag v1.0.0 --push

# Build with custom name
aramb build --name myapp --push

# Build from specific path
aramb build ./myapp
```

**Flags:**
- `--tag, -t` - Additional image tag (default: commit SHA if in git repo)
- `--name, -n` - Image name (default: directory name)
- `--push` - Push image to registry after building
- `--no-push` - Skip pushing image to registry
- `--deploy` - Deploy service after building (requires --push)
- `--no-deploy` - Skip deployment after building

**Requirements:**
- `BUILDKIT_HOST` - BuildKit server endpoint
- `ARAMB_SERVICE_ID` - Required for --deploy flag
- `ARAMB_API_TOKEN` - Required for deployment tracking

### Static Site Builds

Build frontend applications (React, Vue, Next.js, Angular, Vite).

```bash
# Build static files to ./dist
aramb build --static-outdir ./dist

# Build React/Vue/Next.js to custom output
aramb build --static-outdir ./public

# Build from specific path
aramb build ./frontend --static-outdir ./dist
```

**Flags:**
- `--static-outdir` - Build static files to specified directory (auto-detects framework)

**Supported Frameworks:**
- Next.js → `out/`
- Create React App → `build/`
- Vite (React/Vue) → `dist/`
- Vue CLI → `dist/`
- Angular → `dist/`
- Generic (npm build) → `dist/`

**Note:** Static builds cannot be used with `--push`, `--deploy`, or `--tag` flags.

---

## Deploy Command

Deploy services using Docker images, static files, or TOML configuration.

### Deploy from TOML

Deploy all services defined in `aramb.toml`:

```bash
aramb deploy --deploy-from-toml
```

### Deploy with Docker Image

Deploy a specific service with a Docker image:

```bash
# Interactive selection
aramb deploy --image nginx:latest

# Specify service by slug
aramb deploy --service backend-api --image myapp:v1.0

# Auto-confirm prompts
aramb deploy --service backend-api --image myapp:v1.0 --yes
```

**Flags:**
- `--image` - Docker image to deploy (e.g., nginx:latest, registry.example.com/app:v1.0)
- `--yes, -y` - Automatically confirm prompts

### Deploy Static Files

Deploy static files from local directory or archive:

```bash
# From local directory
aramb deploy --service frontend-web --static-outdir ./dist

# From archive file
aramb deploy --service frontend-web --archive-path ./build.tar.gz

# From URL (with authentication)
aramb deploy --service frontend-web \
  --archive-path https://example.com/build.tar.gz \
  --http-bearer "token123"

# From registry
aramb deploy --service frontend-web \
  --archive-path registry.example.com/app:v1.0 \
  --registry-auth "token123"
```

**Flags:**
- `--static-outdir` - Deploy static files from local directory
- `--archive-path` - Deploy from archive (file/URL/registry)
- `--http-bearer` - HTTP bearer token for URL authentication
- `--http-basic` - HTTP basic auth (base64 encoded username:password)
- `--registry-auth` - Registry authentication token

### Interactive Deploy

Deploy services with interactive browser:

```bash
# Browse and select service
aramb deploy

# Pre-select service by slug or UUID
aramb deploy --service backend-api

# Pre-select multiple services (comma-separated)
aramb deploy --service backend-api,frontend-web

# Pre-select application
aramb deploy --application my-app
```

**Flags:**
- `--service, -s` - Service identifier(s) - single or comma-separated (slug or UUID)
- `--application, -a` - Application identifier (slug or UUID)

---

## Deploy Subcommands

### Deployment History

View deployment history for a service:

```bash
# Interactive selection
aramb deploy history

# Specify service
aramb deploy history --service backend-api

# Pagination
aramb deploy history --service backend-api --page 2 --limit 50

# Output formats
aramb deploy history --service backend-api --output json
aramb deploy history --service backend-api --output yaml
```

**Flags:**
- `--service, -s` - Service identifier (slug or UUID)
- `--page, -p` - Page number (default: 1)
- `--limit, -l` - Items per page (default: 20)
- `--output, -o` - Output format: json, table, yaml (default: table)

### Deployment Status

View current deployment status:

```bash
# Interactive selection
aramb deploy status

# Specify service
aramb deploy status --service backend-api

# Continuous polling (every 5 seconds)
aramb deploy status --service backend-api --loop

# Custom poll interval (10 seconds)
aramb deploy status --service backend-api --loop --interval 10
```

**Flags:**
- `--service, -s` - Service identifier (slug or UUID)
- `--loop, -l` - Continuously poll deployment status
- `--interval, -i` - Poll interval in seconds (default: 5, requires --loop)

### Deployment Details

View detailed information about a deployment:

```bash
# Interactive selection
aramb deploy details

# Specify service and deployment
aramb deploy details --service backend-api --deployment <deployment-id>

# Output formats
aramb deploy details --service backend-api --deployment <deployment-id> --output json
```

**Flags:**
- `--service, -s` - Service identifier (slug or UUID)
- `--deployment, -d` - Deployment ID (UUID)
- `--output, -o` - Output format: json, table, yaml (default: yaml)

---

## Environment Variables

**Authentication:**
- `ARAMB_API_TOKEN` - API token for Aramb services
- `ARAMB_SERVICE_ID` - Service ID for build tracking and deployment

**Docker Registry:**
- `DOCKER_REGISTRY` - Docker registry URL
- `DOCKER_USERNAME` - Docker registry username
- `DOCKER_PASSWORD` - Docker registry password

**Build Configuration:**
- `BUILDKIT_HOST` - BuildKit server endpoint (required)

**Service URLs:**
- `JUMBO_URL` - Jumbo API endpoint (default: https://jumbo.aramb.dev)
- `HATHI_URL` - Hathi API endpoint (default: https://hathi.aramb.dev)
