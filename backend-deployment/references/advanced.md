# Advanced Usage

Advanced topics for local-deploy skill.

## Registry Configuration

### Using Private Registries

Configure private Docker registry for image storage:

```bash
# Set registry URL
export DOCKER_REGISTRY="registry.example.com"

# Login to registry
docker login registry.example.com

# Build and push
/local-deploy --push-registry
```

### Multiple Registries

Use different registries for different services:

```toml
# In aramb.toml
[[services]]
name = "backend-api"
type = "backend"

[services.configuration.settings]
image = "registry1.example.com/backend:latest"

[[services]]
name = "worker"
type = "backend"

[services.configuration.settings]
image = "registry2.example.com/worker:latest"
```

### Registry Authentication

**Basic Authentication:**
```bash
export DOCKER_USERNAME="user"
export DOCKER_PASSWORD="pass"
docker login $DOCKER_REGISTRY -u $DOCKER_USERNAME -p $DOCKER_PASSWORD
```

**Token Authentication:**
```bash
echo $REGISTRY_TOKEN | docker login $DOCKER_REGISTRY --username oauth2accesstoken --password-stdin
```

## Build Optimization

### Docker Layer Caching

Optimize Dockerfile for layer caching:

```dockerfile
# GOOD: Copy dependencies first
FROM golang:1.21-alpine
WORKDIR /app
COPY go.mod go.sum ./    # ← Only changes when deps change
RUN go mod download       # ← Cached unless deps change
COPY . .                  # ← Source changes don't invalidate cache
RUN go build -o main .

# BAD: Copy everything first
FROM golang:1.21-alpine
WORKDIR /app
COPY . .                  # ← Any change invalidates entire cache
RUN go mod download
RUN go build -o main .
```

### BuildKit Cache Mounts

Use BuildKit cache mounts for faster builds:

```dockerfile
# Go modules cache
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# NPM cache
RUN --mount=type=cache,target=/root/.npm \
    npm ci
```

### Parallel Builds

Build multiple services in parallel:

```bash
# Build services concurrently
aramb build --name backend --tag v1 &
aramb build --name worker --tag v1 &
wait

# Deploy after all builds complete
aramb deploy --deploy-from-toml
```

## Selective Deployment

### Deploy Specific Services

Deploy only services that changed:

```bash
# Deploy only backend and frontend
/local-deploy --services backend-api,frontend-web

# Skip database (already running)
/local-deploy --services backend-api
```

### Skip Builds

Deploy existing artifacts without rebuilding:

```bash
# Use existing images
/local-deploy --skip-build
```

### Conditional Deployment

Deploy based on git changes:

```bash
# Get changed services
CHANGED=$(git diff --name-only HEAD~1 | grep -E '^(backend|frontend)/' | cut -d/ -f1 | sort -u | tr '\n' ',')

# Deploy only changed services
/local-deploy --services $CHANGED
```

## Environment Management

### Multiple Environments

Manage different environments with separate configurations:

```bash
# Development
cp aramb.dev.toml aramb.toml
/local-deploy

# Staging
cp aramb.staging.toml aramb.toml
/local-deploy --push-registry

# Production
cp aramb.prod.toml aramb.toml
/local-deploy --push-registry
```

### Environment Variables

Override environment variables per deployment:

```bash
# Set environment-specific vars
export DATABASE_URL="postgres://localhost:5432/dev"
export API_KEY="dev-api-key"

# Deploy with custom vars
/local-deploy
```

### Secrets Management

Use external secrets management:

```bash
# Load secrets from vault
export $(vault kv get -format=json secret/app | jq -r '.data | to_entries[] | "\(.key)=\(.value)"')

# Deploy with secrets
/local-deploy
```

## Advanced Build Strategies

### Multi-Platform Builds

Build for multiple architectures:

```bash
# Build for amd64 and arm64
docker buildx build --platform linux/amd64,linux/arm64 -t backend:latest .

# Push multi-arch image
docker buildx build --platform linux/amd64,linux/arm64 -t registry.example.com/backend:latest --push .
```

### Build Arguments

Pass build-time variables:

```dockerfile
# Dockerfile
ARG VERSION=latest
ARG ENVIRONMENT=production

FROM node:20-alpine
ENV VERSION=${VERSION}
ENV ENVIRONMENT=${ENVIRONMENT}
```

```bash
# Build with custom args
docker build --build-arg VERSION=v1.2.3 --build-arg ENVIRONMENT=staging -t backend:v1.2.3 .
```

### Custom Dockerfile

Use different Dockerfiles for different environments:

```bash
# Development
docker build -f Dockerfile.dev -t backend:dev .

# Production
docker build -f Dockerfile.prod -t backend:prod .
```

## Monitoring and Observability

### Build Metrics

Track build performance:

```bash
# Time builds
time aramb build --name backend --tag v1

# Monitor build size
docker images | grep backend
```

### Deployment Monitoring

Monitor deployment progress:

```bash
# Watch deployment status
watch -n 2 'aramb deploy status --service backend-api'

# Follow logs
aramb logs --service backend-api --follow

# Check health endpoints
curl http://localhost:8080/health
```

### Alerting

Set up alerts for deployment failures:

```bash
#!/bin/bash
# deploy-with-alert.sh

/local-deploy

if [ $? -ne 0 ]; then
  # Send alert
  curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
    -H 'Content-Type: application/json' \
    -d '{"text":"Deployment failed!"}'
fi
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Go
        uses: actions/setup-go@v4
        with:
          go-version: '1.21'

      - name: Install aramb-cli
        run: go install github.com/aramb-dev/aramb-cli/cmd/aramb@latest

      - name: Deploy
        env:
          BUILDKIT_HOST: ${{ secrets.BUILDKIT_HOST }}
          ARAMB_API_TOKEN: ${{ secrets.ARAMB_API_TOKEN }}
          ARAMB_SERVICE_ID: ${{ secrets.ARAMB_SERVICE_ID }}
        run: |
          export PATH=$PATH:$(go env GOPATH)/bin
          aramb deploy --deploy-from-toml
```

### GitLab CI

```yaml
deploy:
  stage: deploy
  image: golang:1.21
  before_script:
    - go install github.com/aramb-dev/aramb-cli/cmd/aramb@latest
    - export PATH=$PATH:$(go env GOPATH)/bin
  script:
    - aramb deploy --deploy-from-toml
  only:
    - main
```

## Performance Tuning

### Build Cache Configuration

```bash
# Enable inline cache
docker buildx build --cache-to type=inline --cache-from type=registry,ref=backend:cache .

# Use registry cache
docker buildx build --cache-from type=registry,ref=backend:cache --cache-to type=registry,ref=backend:cache .
```

### Resource Limits

Set resource limits for builds:

```bash
# Limit memory
docker build --memory 2g -t backend:latest .

# Limit CPUs
docker build --cpus 2 -t backend:latest .
```

### Concurrent Builds

Control parallel build processes:

```bash
# Set max parallel builds
export DOCKER_BUILDKIT_MAX_PARALLELISM=4

# Build with concurrency
aramb build --name backend --tag v1 --parallel 4
```

## Custom Workflows

### Pre-Deploy Hooks

Run scripts before deployment:

```bash
#!/bin/bash
# pre-deploy.sh

# Run tests
npm test

# Run migrations
npm run migrate

# Deploy
/local-deploy
```

### Post-Deploy Hooks

Run scripts after deployment:

```bash
#!/bin/bash
# post-deploy.sh

# Deploy
/local-deploy

# Smoke tests
curl http://localhost:8080/health

# Notify team
curl -X POST $SLACK_WEBHOOK -d '{"text":"Deployment complete"}'
```

### Rollback Strategy

Implement automated rollback:

```bash
#!/bin/bash
# deploy-with-rollback.sh

# Save current state
PREVIOUS_IMAGE=$(docker inspect backend:current --format='{{.Config.Image}}')

# Deploy new version
/local-deploy

# Health check
sleep 10
if ! curl -f http://localhost:8080/health; then
  echo "Health check failed, rolling back..."
  docker tag $PREVIOUS_IMAGE backend:latest
  aramb deploy --deploy-from-toml
fi
```

## Advanced Service Configuration

### Custom Networks

Configure custom Docker networks:

```yaml
# docker-compose.yml
networks:
  frontend-net:
    driver: bridge
  backend-net:
    driver: bridge
    internal: true

services:
  backend:
    networks:
      - backend-net
      - frontend-net

  postgres:
    networks:
      - backend-net  # isolated from frontend
```

### Volume Management

Manage persistent data:

```bash
# Backup volumes before deploy
docker run --rm -v postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres-backup.tar.gz /data

# Deploy
/local-deploy

# Restore if needed
docker run --rm -v postgres_data:/data -v $(pwd):/backup alpine tar xzf /backup/postgres-backup.tar.gz -C /
```

### Health Checks

Configure advanced health checks:

```yaml
services:
  backend:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

## Debugging

### Enable Debug Mode

```bash
# Enable verbose output
export DEBUG=1
export BUILDKIT_PROGRESS=plain

# Deploy with debug info
/local-deploy
```

### Inspect Build Context

```bash
# Check what's being sent to Docker
docker build --no-cache --progress=plain -t backend:debug . 2>&1 | tee build.log
```

### Container Inspection

```bash
# Inspect running container
docker exec -it <container> /bin/sh

# Check environment
docker exec <container> env

# View logs
docker logs -f <container>
```

## Best Practices

1. **Use .dockerignore** - Exclude unnecessary files from build context
2. **Multi-stage builds** - Keep final images small
3. **Layer caching** - Order Dockerfile commands by change frequency
4. **Health checks** - Always define health check endpoints
5. **Resource limits** - Set memory and CPU limits
6. **Version tagging** - Use semantic versioning for images
7. **Backup before deploy** - Backup databases before deploying
8. **Monitor deployments** - Watch deployment status until complete
9. **Test locally** - Always test builds locally before CI/CD
10. **Document changes** - Keep deployment notes in version control
