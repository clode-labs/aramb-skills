# Troubleshooting Guide

Common issues and solutions for frontend-local-deployment.

## APPLICATION_ID Not Set

### Symptom
```
Error: APPLICATION_ID environment variable not set
```

### Solution

1. **Get application ID:**
   ```bash
   # List available applications
   aramb application list

   # Or create new application
   aramb application create --name "My App"
   ```

2. **Set environment variable:**
   ```bash
   export APPLICATION_ID="app-abc123"

   # Verify
   echo $APPLICATION_ID
   ```

3. **Make permanent:**
   ```bash
   echo 'export APPLICATION_ID="app-abc123"' >> ~/.bashrc
   source ~/.bashrc
   ```

## Build Failures

### Symptom
```
Error: Build failed
npm ERR! Failed to compile
```

### Diagnosis

1. **Check dependencies installed:**
   ```bash
   ls node_modules/
   npm install
   ```

2. **Verify build script:**
   ```bash
   cat package.json | grep '"build"'
   ```

3. **Test build manually:**
   ```bash
   npm run build
   ```

### Common Causes

**Missing dependencies:**
```bash
rm -rf node_modules package-lock.json
npm install
```

**Node version mismatch:**
```bash
node --version
nvm install 20
nvm use 20
```

**TypeScript errors:**
```bash
# Check for errors
npm run type-check

# Fix errors or skip (not recommended)
export SKIP_TYPE_CHECK=true
npm run build
```

## Service Creation Failures

### Symptom
```
Error: Failed to create service
```

### Diagnosis

1. **Check API token:**
   ```bash
   echo $ARAMB_API_TOKEN

   # Test authentication
   aramb application list
   ```

2. **Check application exists:**
   ```bash
   aramb application get --id $APPLICATION_ID
   ```

3. **Check service name conflicts:**
   ```bash
   aramb service list --application $APPLICATION_ID
   ```

### Solutions

**Invalid API token:**
```bash
# Get new token from dashboard
export ARAMB_API_TOKEN="new-token"
```

**Service already exists:**
```bash
# Use custom name
/frontend-local-deployment --service-name my-frontend-v2
```

**Application not found:**
```bash
# Create application
aramb application create --name "My App"
export APPLICATION_ID="<new-app-id>"
```

## Static Files Not Found

### Symptom
```
Error: No static files found
```

### Diagnosis

1. **Check for static directories:**
   ```bash
   ls -la dist/ build/ out/ public/
   ```

2. **Check framework detection:**
   ```bash
   ls -la package.json next.config.js vite.config.js
   ```

### Solutions

**Force build:**
```bash
/frontend-local-deployment --force-build
```

**Build manually first:**
```bash
npm run build
/frontend-local-deployment
```

**Specify static directory:**
```bash
# If using non-standard directory
mkdir -p dist
cp -r public/* dist/
/frontend-local-deployment
```

## Framework Not Detected

### Symptom
```
Warning: Could not detect framework
```

### Solution

1. **Check project files:**
   ```bash
   ls -la package.json *.config.js
   ```

2. **Install framework:**
   ```bash
   # For Vite
   npm install --save-dev vite

   # For Next.js
   npm install next react react-dom
   ```

3. **Create config file:**
   ```bash
   # Vite
   echo 'export default {}' > vite.config.js

   # Next.js
   echo 'module.exports = {}' > next.config.js
   ```

## Deployment Takes Too Long

### Symptom
```
Deployment hanging...
Service status: deploying
```

### Diagnosis

1. **Check deployment status:**
   ```bash
   aramb deploy status --service <service-name>
   ```

2. **Check service logs:**
   ```bash
   aramb logs --service <service-name>
   ```

### Solutions

**Large files:**
- Check file sizes: `du -sh dist/*`
- Minimize and compress assets
- Use CDN for large media files

**Network issues:**
- Check internet connection
- Verify API endpoint accessible: `curl https://jumbo.aramb.dev/health`

**Service startup issues:**
- Check service configuration
- Verify static files are valid HTML/JS/CSS

## Permission Denied

### Symptom
```
Error: EACCES: permission denied
```

### Solution

1. **Check file permissions:**
   ```bash
   ls -la dist/
   chmod -R 755 dist/
   ```

2. **Check directory ownership:**
   ```bash
   ls -ld .
   sudo chown -R $USER:$USER .
   ```

## aramb-cli Not Found

### Symptom
```
bash: aramb: command not found
```

### Solution

See [installation.md](installation.md) for complete setup instructions.

Quick fix:
```bash
go install github.com/aramb-dev/aramb-cli/cmd/aramb@latest
export PATH=$PATH:$(go env GOPATH)/bin
```

## Build Output in Wrong Directory

### Symptom
```
Error: Static files not found in expected location
```

### Diagnosis

1. **Check build output:**
   ```bash
   npm run build
   ls -la
   ```

2. **Check framework config:**
   ```bash
   # Next.js
   cat next.config.js | grep distDir

   # Vite
   cat vite.config.js | grep outDir
   ```

### Solution

Update framework config to use standard output:

**Next.js:**
```js
// next.config.js
module.exports = {
  distDir: 'out'
}
```

**Vite:**
```js
// vite.config.js
export default {
  build: {
    outDir: 'dist'
  }
}
```

## Service Not Accessible

### Symptom
```
Deployment successful but cannot access service URL
```

### Diagnosis

1. **Check service status:**
   ```bash
   aramb deploy status --service <service-name>
   ```

2. **Verify service URL:**
   ```bash
   aramb service get --name <service-name>
   ```

3. **Test URL:**
   ```bash
   curl -I https://<service-name>.aramb.dev
   ```

### Solutions

**Service still starting:**
- Wait 1-2 minutes for service to fully start
- Monitor: `aramb deploy status --service <name> --loop`

**DNS propagation:**
- DNS may take a few minutes to propagate
- Try accessing via direct IP if available

**Static files invalid:**
- Verify index.html exists in root
- Check browser console for errors

## Multiple Services Created

### Symptom
```
Multiple services with similar names exist
```

### Solution

1. **List services:**
   ```bash
   aramb service list --application $APPLICATION_ID
   ```

2. **Delete unwanted services:**
   ```bash
   aramb service delete --name <unwanted-service>
   ```

3. **Use explicit service name:**
   ```bash
   /frontend-local-deployment --service-name my-final-name
   ```

## Getting Help

If issues persist:

1. **Enable verbose output:**
   ```bash
   export DEBUG=1
   /frontend-local-deployment
   ```

2. **Check logs:**
   ```bash
   aramb logs --service <service-name> --follow
   ```

3. **Gather diagnostic info:**
   ```bash
   # System info
   node --version
   npm --version
   aramb --version
   echo $APPLICATION_ID

   # Project info
   ls -la
   cat package.json
   ```

4. **Contact support:**
   - GitHub Issues: https://github.com/aramb-dev/aramb-cli/issues
   - Include error messages and diagnostic info
