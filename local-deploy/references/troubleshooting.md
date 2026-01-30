# Troubleshooting Guide

Common issues and solutions for local-deploy.

## aramb-cli Not Found

### Symptom
```
bash: aramb: command not found
```

### Solution

1. **Download aramb-cli binary:**

   Visit: https://github.com/aramb-ai/release-beta/releases/tag/v0.0.11-beta1

   **Linux:**
   ```bash
   curl -LO https://github.com/aramb-ai/release-beta/releases/download/v0.0.11-beta1/aramb-linux-amd64
   chmod +x aramb-linux-amd64
   sudo mv aramb-linux-amd64 /usr/local/bin/aramb
   ```

   **macOS (Intel):**
   ```bash
   curl -LO https://github.com/aramb-ai/release-beta/releases/download/v0.0.11-beta1/aramb-darwin-amd64
   chmod +x aramb-darwin-amd64
   sudo mv aramb-darwin-amd64 /usr/local/bin/aramb
   ```

   **macOS (Apple Silicon):**
   ```bash
   curl -LO https://github.com/aramb-ai/release-beta/releases/download/v0.0.11-beta1/aramb-darwin-arm64
   chmod +x aramb-darwin-arm64
   sudo mv aramb-darwin-arm64 /usr/local/bin/aramb
   ```

2. **Verify installation:**
   ```bash
   which aramb
   aramb --version
   ```

## Build Failures

### Symptom
```
Error: failed to build image
```

### Diagnosis

1. **Check BuildKit connection:**
   ```bash
   docker buildx ls
   echo $BUILDKIT_HOST
   ```

2. **Verify Dockerfile exists:**
   ```bash
   ls -la Dockerfile
   cat Dockerfile
   ```

3. **Check build logs:**
   ```bash
   aramb build --name myservice --tag test 2>&1 | tee build.log
   ```

### Common Causes

**Missing Dockerfile:**
- Ensure Dockerfile exists in the build path
- Use backend-development skill to create Dockerfile

**BuildKit not running:**
```bash
# Start BuildKit
docker buildx create --use

# Verify
docker buildx ls
```

**Invalid BUILDKIT_HOST:**
```bash
# Test connection
curl -v $BUILDKIT_HOST

# Reset to local
export BUILDKIT_HOST="tcp://localhost:1234"
```

**Dockerfile syntax errors:**
```bash
# Validate Dockerfile
docker build --dry-run -f Dockerfile .
```

## Deployment Failures

### Symptom
```
Error: deployment failed for service backend-api
```

### Diagnosis

1. **Check deployment status:**
   ```bash
   aramb deploy status --service backend-api
   ```

2. **View deployment history:**
   ```bash
   aramb deploy history --service backend-api --limit 10
   ```

3. **Check service configuration:**
   ```bash
   cat aramb.toml | grep -A 20 "name = \"backend-api\""
   ```

4. **Verify aramb-cli connectivity:**
   ```bash
   echo $ARAMB_API_TOKEN
   echo $ARAMB_SERVICE_ID
   aramb --help
   ```

### Common Causes

**Invalid service configuration:**
- Verify aramb.toml syntax: `aramb deploy --deploy-from-toml --dry-run`
- Check service references are valid
- Ensure uniqueIdentifiers are sequential

**Missing environment variables:**
```bash
# Check all required vars set
env | grep ARAMB

# Set missing vars
export ARAMB_API_TOKEN="your-token"
export ARAMB_SERVICE_ID="your-service-id"
```

**API authentication issues:**
```bash
# Test API connectivity
curl -H "Authorization: Bearer $ARAMB_API_TOKEN" https://jumbo.aramb.dev/health

# Refresh token if expired
# Contact aramb support for new token
```

**Service not ready:**
- Services may take time to become healthy
- Monitor with: `aramb deploy status --loop --interval 5`
- Check for dependency issues

## Missing Environment Variables

### Symptom
```
Error: BUILDKIT_HOST not set
Error: ARAMB_API_TOKEN not set
```

### Solution

1. **Check current environment:**
   ```bash
   env | grep -E 'BUILDKIT_HOST|ARAMB_API_TOKEN|ARAMB_SERVICE_ID'
   ```

2. **Set required variables:**
   ```bash
   export BUILDKIT_HOST="tcp://localhost:1234"
   export ARAMB_API_TOKEN="your-token"
   export ARAMB_SERVICE_ID="your-service-id"
   ```

3. **Make permanent:**
   ```bash
   cat >> ~/.bashrc <<EOF
   export BUILDKIT_HOST="tcp://localhost:1234"
   export ARAMB_API_TOKEN="your-token"
   export ARAMB_SERVICE_ID="your-service-id"
   EOF

   source ~/.bashrc
   ```

4. **Verify:**
   ```bash
   echo $BUILDKIT_HOST
   echo $ARAMB_API_TOKEN
   echo $ARAMB_SERVICE_ID
   ```

## aramb.toml Not Found

### Symptom
```
Error: aramb.toml not found
```

### Solution

1. **Check if file exists:**
   ```bash
   ls -la aramb.toml
   pwd
   ```

2. **Generate aramb.toml:**
   ```bash
   # Use aramb-metadata skill
   /aramb-metadata
   ```

3. **Verify structure:**
   ```bash
   cat aramb.toml
   ```

4. **Validate syntax:**
   ```bash
   # Test parsing
   python3 -c "import toml; toml.load('aramb.toml')"
   ```

## Docker Permission Denied

### Symptom
```
permission denied while trying to connect to Docker daemon
```

### Solution

1. **Add user to docker group:**
   ```bash
   sudo usermod -aG docker $USER
   newgrp docker
   ```

2. **Restart Docker daemon:**
   ```bash
   sudo systemctl restart docker
   ```

3. **Verify:**
   ```bash
   docker ps
   ```

## Frontend Build Failures

### Symptom
```
Error: frontend build failed
```

### Diagnosis

1. **Check framework detection:**
   ```bash
   ls -la package.json
   cat package.json | grep scripts
   ```

2. **Verify dependencies installed:**
   ```bash
   ls -la node_modules/
   npm install
   ```

3. **Test build manually:**
   ```bash
   npm run build
   ```

### Common Causes

**Missing dependencies:**
```bash
npm install
# or
yarn install
```

**Build script not found:**
- Check package.json has "build" script
- Verify framework-specific build command

**Node version mismatch:**
```bash
node --version
nvm use 20  # or required version
```

## Service Communication Issues

### Symptom
```
Error: backend cannot connect to database
Error: service unhealthy
```

### Diagnosis

1. **Check docker-compose networks:**
   ```bash
   docker network ls
   docker network inspect <network-name>
   ```

2. **Verify service dependencies:**
   ```bash
   cat aramb.toml | grep -A 5 "depends_on"
   ```

3. **Check service health:**
   ```bash
   aramb deploy status --service <name>
   docker ps
   ```

### Solution

1. **Ensure services in same network:**
   - Check docker-compose.yml network configuration
   - Verify aramb.toml service references

2. **Check service order:**
   - Database should start before backend
   - Verify depends_on in configuration

3. **Test connectivity:**
   ```bash
   # From backend container
   docker exec <backend-container> ping postgres
   docker exec <backend-container> nc -zv postgres 5432
   ```

## Registry Push Failures

### Symptom
```
Error: failed to push image to registry
```

### Diagnosis

1. **Check registry credentials:**
   ```bash
   docker login $DOCKER_REGISTRY
   ```

2. **Verify registry URL:**
   ```bash
   echo $DOCKER_REGISTRY
   ```

3. **Check image tag format:**
   ```bash
   # Should be: registry.example.com/image:tag
   docker images | grep <your-image>
   ```

### Solution

1. **Login to registry:**
   ```bash
   docker login registry.example.com
   # Enter username and password
   ```

2. **Set registry credentials:**
   ```bash
   export DOCKER_REGISTRY="registry.example.com"
   export DOCKER_USERNAME="your-username"
   export DOCKER_PASSWORD="your-password"
   ```

3. **Verify image name:**
   ```bash
   # Image must be tagged with registry prefix
   aramb build --name myservice --tag v1 --push
   ```

## Performance Issues

### Symptom
```
Build taking too long
Deployment hanging
```

### Solution

1. **Enable build caching:**
   ```bash
   export DOCKER_BUILDKIT=1
   ```

2. **Use .dockerignore:**
   ```bash
   # Create .dockerignore
   cat > .dockerignore <<EOF
   node_modules
   .git
   .env
   *.log
   EOF
   ```

3. **Parallel builds:**
   - Build services concurrently if independent
   - Use `--parallel` flag if available

4. **Check resource limits:**
   ```bash
   docker info | grep -E 'CPUs|Memory'
   ```

## Getting Help

If issues persist:

1. **Check logs:**
   ```bash
   aramb deploy history --service <name> --output json
   docker logs <container-name>
   ```

2. **Enable debug mode:**
   ```bash
   export DEBUG=1
   /local-deploy
   ```

3. **Verify all prerequisites:**
   - See [installation.md](installation.md) for setup checklist

4. **Contact support:**
   - GitHub Issues: https://github.com/aramb-dev/aramb-cli/issues
   - Include error messages and logs
   - Provide aramb.toml (redact sensitive data)
