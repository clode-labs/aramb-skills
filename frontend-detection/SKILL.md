---
name: frontend-detection
description: >
  Detect which service in a docker-compose.yml is the frontend. Use when:
  (1) need to identify the UI service for tunneling, (2) need to find the
  frontend port for testing, (3) determining which service serves the
  user-facing application. NOT for: backend service detection or general
  docker-compose analysis.
---

# Frontend Detection

## Detection Strategy

Check these signals in order of reliability:

### 1. Service Name Patterns
Look for services named:
- `web`, `frontend`, `client`, `ui`, `app`, `next`, `nuxt`, `vite`
- Names containing `react`, `vue`, `angular`, `svelte`

```bash
docker compose config --services | grep -iE "^(web|frontend|client|ui|app|next|nuxt|vite)$|react|vue|angular|svelte"
```

### 2. Dockerfile Content
Check each service's Dockerfile for frontend indicators:

```bash
# Find Dockerfiles referenced in docker-compose.yml
for service in $(docker compose config --services); do
  dockerfile=$(docker compose config | yq ".services.${service}.build.dockerfile // \"Dockerfile\"")
  context=$(docker compose config | yq ".services.${service}.build.context // \".\"")

  if [ -f "${context}/${dockerfile}" ]; then
    # Check for frontend build tools
    if grep -qiE "npm run build|yarn build|vite|next|nuxt|webpack|react-scripts" "${context}/${dockerfile}"; then
      echo "FRONTEND CANDIDATE: $service (has frontend build in Dockerfile)"
    fi

    # Check for static file servers
    if grep -qiE "nginx|serve|http-server|caddy" "${context}/${dockerfile}"; then
      echo "FRONTEND CANDIDATE: $service (serves static files)"
    fi
  fi
done
```

### 3. Package.json Detection
Check if a service directory has a package.json with frontend dependencies:

```bash
# Look for React, Vue, Next.js, etc. in package.json
for dir in $(find . -name "package.json" -maxdepth 3 -not -path "*/node_modules/*"); do
  if grep -qiE "\"react\"|\"vue\"|\"next\"|\"nuxt\"|\"svelte\"|\"@angular\"" "$dir"; then
    echo "FRONTEND CANDIDATE: $dir"
  fi
done
```

### 4. Port Patterns
Common frontend ports (when other signals are ambiguous):
- `3000` — React dev server, Next.js
- `5173` / `5174` — Vite
- `8080` — Vue CLI, general dev servers
- `4200` — Angular CLI
- `80` / `443` — Nginx / production builds

```bash
# Check exposed ports in docker-compose.yml
docker compose config | yq '.services | to_entries[] | select(.value.ports) | .key + ": " + (.value.ports | join(", "))'
```

### 5. Serve Command
Check if the service runs a frontend server:

```bash
docker compose config | yq '.services | to_entries[] | .key + ": " + (.value.command // "default")'
```

Look for: `npm start`, `yarn start`, `next start`, `nuxt start`, `serve`, `nginx`, `http-server`

## Decision Logic

1. If exactly one service matches frontend signals — that's the frontend
2. If multiple match — prefer the one with the most signals, or the one exposed on the lowest port
3. If none match — report "no frontend detected" (do NOT guess)

## Output

Report:
- **Service name** — which docker-compose service is the frontend
- **Port** — which host port maps to the frontend (e.g., `3000:3000` → host port 3000)
- **Framework** — what frontend framework is detected (React, Vue, Next.js, etc.)
- **Confidence** — high (multiple signals), medium (one signal), low (port-only guess)
