# Installation Guide

Setup guide for frontend-local-deployment skill.

## Prerequisites

### Required Tools

- **aramb-cli v0.0.11-beta1** - Aramb command-line tool (from GitHub release)
- **Node.js 16+** - For building frontend applications (if build needed)

### Required Environment Variables

- `APPLICATION_ID` - Aramb application ID
- `ARAMB_API_TOKEN` - API authentication token

## Quick Setup

### Step 1: Install aramb-cli

Download the appropriate binary for your platform:

**Release:** https://github.com/aramb-ai/release-beta/releases/tag/v0.0.11-beta1

**Linux (amd64):**
```bash
curl -LO https://github.com/aramb-ai/release-beta/releases/download/v0.0.11-beta1/aramb-linux-amd64
chmod +x aramb-linux-amd64
sudo mv aramb-linux-amd64 /usr/local/bin/aramb
aramb --version
```

**macOS (Intel):**
```bash
curl -LO https://github.com/aramb-ai/release-beta/releases/download/v0.0.11-beta1/aramb-darwin-amd64
chmod +x aramb-darwin-amd64
sudo mv aramb-darwin-amd64 /usr/local/bin/aramb
aramb --version
```

**macOS (Apple Silicon):**
```bash
curl -LO https://github.com/aramb-ai/release-beta/releases/download/v0.0.11-beta1/aramb-darwin-arm64
chmod +x aramb-darwin-arm64
sudo mv aramb-darwin-arm64 /usr/local/bin/aramb
aramb --version
```

**Windows:**
Download from: https://github.com/aramb-ai/release-beta/releases/download/v0.0.11-beta1/aramb-windows-amd64.exe

### Step 2: Get Application ID

Get your application ID from Aramb dashboard:

```bash
# List applications
aramb application list

# Or create new application
aramb application create --name "My Frontend App"

# Set APPLICATION_ID
export APPLICATION_ID="app-abc123"
```

### Step 3: Set API Token

```bash
# Set authentication token
export ARAMB_API_TOKEN="your-api-token-here"
```

### Step 4: Verify Setup

```bash
# Check environment
echo $APPLICATION_ID
echo $ARAMB_API_TOKEN

# Test aramb-cli
aramb --help

# Test Node.js (if building needed)
node --version
npm --version
```

## Environment Variable Setup

### Temporary (Current Session)

```bash
export APPLICATION_ID="app-abc123"
export ARAMB_API_TOKEN="your-token"
```

### Permanent (All Sessions)

**Bash:**
```bash
cat >> ~/.bashrc <<EOF
export APPLICATION_ID="app-abc123"
export ARAMB_API_TOKEN="your-token"
EOF

source ~/.bashrc
```

**Zsh:**
```bash
cat >> ~/.zshrc <<EOF
export APPLICATION_ID="app-abc123"
export ARAMB_API_TOKEN="your-token"
EOF

source ~/.zshrc
```

### Per-Project (.env file)

```bash
# Create .env file in project root
cat > .env <<EOF
APPLICATION_ID=app-abc123
ARAMB_API_TOKEN=your-token
EOF

# Load before deployment
export $(cat .env | xargs)
/frontend-local-deployment
```

## Node.js Setup

### Install Node.js

**Ubuntu/Debian:**
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
```

**macOS:**
```bash
brew install node@20
```

**Using nvm (recommended):**
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 20
nvm use 20
```

### Verify Installation

```bash
node --version
npm --version
```

## Project Setup

### Initialize Frontend Project

**React:**
```bash
npx create-react-app my-app
cd my-app
```

**Next.js:**
```bash
npx create-next-app@latest my-app
cd my-app
```

**Vue:**
```bash
npm create vue@latest my-app
cd my-app
```

**Vite:**
```bash
npm create vite@latest my-app
cd my-app
```

### Install Dependencies

```bash
npm install
```

## Verification Checklist

- [ ] aramb-cli v0.0.11-beta1 installed and in PATH
- [ ] Node.js 16+ installed
- [ ] APPLICATION_ID environment variable set
- [ ] ARAMB_API_TOKEN environment variable set
- [ ] Can run: `aramb --version`
- [ ] Can run: `node --version`
- [ ] Can run: `aramb application list`

## Next Steps

Once setup is complete:

1. Navigate to your frontend project
2. Set APPLICATION_ID: `export APPLICATION_ID=app-123`
3. Run deployment: `/frontend-local-deployment`
