# Framework-Specific Guide

Detailed information for each supported frontend framework.

## Next.js

### Detection

```bash
# Checks for Next.js config files
[ -f "next.config.js" ] || [ -f "next.config.mjs" ]
```

### Build Command

```bash
npm run build
```

### Output Directory

```
out/
```

### Configuration

**next.config.js:**
```js
module.exports = {
  output: 'export',  // Static export
  distDir: 'out'     // Output directory
}
```

### Common Issues

**Static export error:**
```bash
# Next.js requires static export config
echo "module.exports = { output: 'export' }" > next.config.js
```

**API routes not supported:**
- Static export doesn't support API routes
- Move API logic to separate backend

**Image optimization:**
```js
// next.config.js
module.exports = {
  output: 'export',
  images: {
    unoptimized: true  // Required for static export
  }
}
```

## Create React App (CRA)

### Detection

```bash
# Checks for react-scripts in package.json
grep -q "react-scripts" package.json
```

### Build Command

```bash
npm run build
```

### Output Directory

```
build/
```

### Configuration

**package.json:**
```json
{
  "scripts": {
    "build": "react-scripts build"
  }
}
```

### Common Issues

**Public URL:**
```bash
# Set homepage in package.json
npm pkg set homepage="https://my-app.aramb.dev"
```

**Environment variables:**
```bash
# Must start with REACT_APP_
export REACT_APP_API_URL="https://api.example.com"
npm run build
```

**Build size warnings:**
```bash
# Analyze bundle
npm install --save-dev source-map-explorer
npm run build
npx source-map-explorer 'build/static/js/*.js'
```

## Vite (React/Vue)

### Detection

```bash
# Checks for Vite config
[ -f "vite.config.js" ] || [ -f "vite.config.ts" ]
```

### Build Command

```bash
npm run build
```

### Output Directory

```
dist/
```

### Configuration

**vite.config.js:**
```js
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  build: {
    outDir: 'dist'
  }
})
```

### Common Issues

**Base path:**
```js
// vite.config.js
export default defineConfig({
  base: '/my-app/'  // If not at root
})
```

**Environment variables:**
```bash
# Must start with VITE_
export VITE_API_URL="https://api.example.com"
npm run build
```

**Asset handling:**
```js
// vite.config.js
export default defineConfig({
  build: {
    assetsDir: 'assets',
    rollupOptions: {
      output: {
        manualChunks: undefined
      }
    }
  }
})
```

## Vue CLI

### Detection

```bash
# Checks for Vue config
[ -f "vue.config.js" ]
```

### Build Command

```bash
npm run build
```

### Output Directory

```
dist/
```

### Configuration

**vue.config.js:**
```js
module.exports = {
  outputDir: 'dist',
  publicPath: '/'
}
```

### Common Issues

**Public path:**
```js
// vue.config.js
module.exports = {
  publicPath: process.env.NODE_ENV === 'production'
    ? '/my-app/'
    : '/'
}
```

**Environment variables:**
```bash
# Must start with VUE_APP_
export VUE_APP_API_URL="https://api.example.com"
npm run build
```

## Angular

### Detection

```bash
# Checks for Angular config
[ -f "angular.json" ]
```

### Build Command

```bash
ng build --configuration production
# or
npm run build
```

### Output Directory

```
dist/<project-name>/
```

### Configuration

**angular.json:**
```json
{
  "projects": {
    "my-app": {
      "architect": {
        "build": {
          "options": {
            "outputPath": "dist/my-app"
          }
        }
      }
    }
  }
}
```

### Common Issues

**Base href:**
```bash
ng build --base-href /my-app/
```

**Environment variables:**
```typescript
// environment.prod.ts
export const environment = {
  production: true,
  apiUrl: 'https://api.example.com'
};
```

**Output path:**
```json
// angular.json - set simple output path
{
  "outputPath": "dist"
}
```

## Svelte

### Detection

```bash
# Checks for Svelte config
[ -f "svelte.config.js" ]
```

### Build Command

```bash
npm run build
```

### Output Directory

```
public/build/  # or dist/
```

### Configuration

**rollup.config.js:**
```js
export default {
  output: {
    dir: 'public/build'
  }
}
```

## Static HTML

### Detection

```bash
# Checks for static files
[ -d "public" ] || [ -d "dist" ] || [ -f "index.html" ]
```

### No Build Required

Static HTML sites don't need building.

### Structure

```
public/
├── index.html
├── css/
│   └── style.css
├── js/
│   └── script.js
└── images/
    └── logo.png
```

## Framework Comparison

| Framework | Build Tool | Output Dir | Config File | Env Prefix |
|-----------|-----------|------------|-------------|------------|
| Next.js | Next.js | `out/` | next.config.js | NEXT_PUBLIC_ |
| CRA | Webpack | `build/` | package.json | REACT_APP_ |
| Vite | Vite | `dist/` | vite.config.js | VITE_ |
| Vue CLI | Webpack | `dist/` | vue.config.js | VUE_APP_ |
| Angular | Angular CLI | `dist/` | angular.json | - |
| Svelte | Rollup/Vite | `public/` | svelte.config.js | - |

## Build Optimization

### General Tips

1. **Minification** - Enabled by default in production builds
2. **Tree shaking** - Remove unused code
3. **Code splitting** - Split into smaller chunks
4. **Asset optimization** - Compress images, fonts

### Next.js Optimization

```js
// next.config.js
module.exports = {
  compiler: {
    removeConsole: true  // Remove console.log in production
  },
  images: {
    unoptimized: true
  }
}
```

### Vite Optimization

```js
// vite.config.js
export default defineConfig({
  build: {
    minify: 'terser',
    terserOptions: {
      compress: {
        drop_console: true
      }
    }
  }
})
```

### Webpack Optimization (CRA/Vue)

```js
// webpack.config.js
module.exports = {
  optimization: {
    minimize: true,
    splitChunks: {
      chunks: 'all'
    }
  }
}
```

## Environment Variables

### Framework-Specific Prefixes

Each framework requires specific prefixes for client-side environment variables:

**Next.js:**
```bash
NEXT_PUBLIC_API_URL=https://api.example.com
```

**Create React App:**
```bash
REACT_APP_API_URL=https://api.example.com
```

**Vite:**
```bash
VITE_API_URL=https://api.example.com
```

**Vue CLI:**
```bash
VUE_APP_API_URL=https://api.example.com
```

### Using .env Files

```bash
# .env.production
VITE_API_URL=https://api.example.com
VITE_APP_NAME=My App
```

Load before build:
```bash
export $(cat .env.production | xargs)
npm run build
```

## Testing Locally

Before deployment, test the built files locally:

### Using http-server

```bash
npm install -g http-server

# Serve from output directory
http-server dist/
# or
http-server build/
# or
http-server out/
```

### Using serve

```bash
npm install -g serve

serve -s dist/
```

### Using Python

```bash
cd dist/
python3 -m http.server 8000
```

## Framework Selection Guide

### Use Next.js when:
- Need SSR/SSG capabilities
- Building large applications
- Want file-based routing
- Need image optimization

### Use CRA when:
- Quick React prototypes
- Don't need server features
- Want zero configuration

### Use Vite when:
- Want fast development
- Modern build tooling
- React or Vue projects
- Need plugin ecosystem

### Use Vue CLI when:
- Building Vue applications
- Need Vue ecosystem integration
- Want established tooling

### Use Angular when:
- Enterprise applications
- Need TypeScript
- Want opinionated framework
- Need comprehensive tooling

### Use Static HTML when:
- Simple websites
- No framework needed
- Maximum performance
- Minimal complexity
