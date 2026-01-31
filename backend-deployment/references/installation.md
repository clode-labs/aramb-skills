# Installation Guide

Complete setup instructions for local-deploy skill.

## Prerequisites

### Required Tools

- **aramb-cli** - Aramb command-line tool (from GitHub release)
- **Docker** - For building images
- **BuildKit** - For advanced Docker builds

### Required Environment Variables

- `BUILDKIT_HOST` - BuildKit server endpoint (for Docker builds)
- `ARAMB_API_TOKEN` - API token for Aramb services
- `ARAMB_SERVICE_ID` - Service ID for deployment tracking

### Optional Environment Variables

- `DOCKER_REGISTRY` - Docker registry URL
- `DOCKER_USERNAME` - Docker registry username
- `DOCKER_PASSWORD` - Docker registry password
- `JUMBO_URL` - Jumbo API endpoint (default: https://jumbo.aramb.dev)
- `HATHI_URL` - Hathi API endpoint (default: https://hathi.aramb.dev)

## Quick Setup

### Step 1: Install aramb-cli

Download the appropriate binary for your platform from the GitHub release:

**Release:** https://github.com/aramb-ai/release-beta/releases/tag/v0.0.11-beta1

**Linux (amd64):**
```bash
# Download binary
curl -LO https://github.com/aramb-ai/release-beta/releases/download/v0.0.11-beta1/aramb-linux-amd64

# Make executable
chmod +x aramb-linux-amd64

# Move to PATH
sudo mv aramb-linux-amd64 /usr/local/bin/aramb

# Verify installation
aramb --version
```

**macOS (amd64/Intel):**
```bash
# Download binary
curl -LO https://github.com/aramb-ai/release-beta/releases/download/v0.0.11-beta1/aramb-darwin-amd64

# Make executable
chmod +x aramb-darwin-amd64

# Move to PATH
sudo mv aramb-darwin-amd64 /usr/local/bin/aramb

# Verify installation
aramb --version
```

**macOS (arm64/Apple Silicon):**
```bash
# Download binary
curl -LO https://github.com/aramb-ai/release-beta/releases/download/v0.0.11-beta1/aramb-darwin-arm64

# Make executable
chmod +x aramb-darwin-arm64

# Move to PATH
sudo mv aramb-darwin-arm64 /usr/local/bin/aramb

# Verify installation
aramb --version
```

**Windows:**
```powershell
# Download from:
# https://github.com/aramb-ai/release-beta/releases/download/v0.0.11-beta1/aramb-windows-amd64.exe

# Rename to aramb.exe and add to PATH
```

### Step 2: Set Environment Variables

**Temporary (current session only):**
```bash
export BUILDKIT_HOST="tcp://your-buildkit-host:1234"
export ARAMB_API_TOKEN="your-api-token"
export ARAMB_SERVICE_ID="your-service-id"
```

**Permanent (all sessions):**
```bash
# Add to ~/.bashrc or ~/.zshrc
cat >> ~/.bashrc <<EOF
export BUILDKIT_HOST="tcp://your-buildkit-host:1234"
export ARAMB_API_TOKEN="your-api-token"
export ARAMB_SERVICE_ID="your-service-id"
EOF

# Reload
source ~/.bashrc
```

**Verify:**
```bash
echo $BUILDKIT_HOST
echo $ARAMB_API_TOKEN
echo $ARAMB_SERVICE_ID
```

### Step 3: Generate aramb.toml

If you don't have an aramb.toml file:

```bash
# Use the aramb-metadata skill
/aramb-metadata
```

This will analyze your project and generate the configuration.

### Step 4: Verify Setup

Run all verification checks:

```bash
# Check aramb-cli installation
aramb --version

# Check Docker installation
docker version

# Check BuildKit connection
docker buildx ls

# Verify environment variables
env | grep -E 'BUILDKIT_HOST|ARAMB_API_TOKEN|ARAMB_SERVICE_ID'

# Verify aramb.toml exists
ls -la aramb.toml
```

## Updating aramb-cli

To update to the latest version, download the new binary from GitHub releases:

```bash
# Check current version
aramb --version

# Download new version from:
# https://github.com/aramb-ai/release-beta/releases

# Replace existing binary
sudo mv aramb-<platform> /usr/local/bin/aramb
aramb --version
```

## Docker Setup

### Install Docker

**Ubuntu/Debian:**
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker
```

**macOS:**
```bash
brew install --cask docker
```

**Windows:**
Download Docker Desktop from https://www.docker.com/products/docker-desktop/

### Configure BuildKit

BuildKit is included in Docker 18.09+:

```bash
# Enable BuildKit
export DOCKER_BUILDKIT=1

# Or set permanently
echo 'export DOCKER_BUILDKIT=1' >> ~/.bashrc
```

For remote BuildKit:
```bash
export BUILDKIT_HOST="tcp://your-buildkit-server:1234"
```

## Registry Configuration

If using a private Docker registry:

```bash
# Login to registry
docker login registry.example.com

# Or set credentials
export DOCKER_REGISTRY="registry.example.com"
export DOCKER_USERNAME="your-username"
export DOCKER_PASSWORD="your-password"
```

## Verification Checklist

- [ ] aramb-cli v0.0.11-beta1 installed and in PATH
- [ ] Docker installed and running
- [ ] BuildKit configured
- [ ] BUILDKIT_HOST environment variable set
- [ ] ARAMB_API_TOKEN environment variable set
- [ ] ARAMB_SERVICE_ID environment variable set
- [ ] aramb.toml exists in project root
- [ ] Can run: `aramb --version`
- [ ] Can run: `docker ps`
- [ ] Can run: `aramb build --help`

## Next Steps

Once setup is complete:

1. Verify your aramb.toml configuration
2. Run a test build: `aramb build --name test --tag v1`
3. Run a test deployment: `/local-deploy --skip-build` (if you have existing images)
4. Run a full build and deploy: `/local-deploy`
