---
name: frontend-development
description: Build modern frontend applications using React, Vue, or vanilla JavaScript. Use this skill for creating UI components, pages, forms, and interactive web interfaces with proper styling, accessibility, and responsive design.
category: development
tags: [frontend, react, typescript, components, ui, accessibility]
license: MIT
---

# Frontend Development

Build components following project patterns. Write accessible, responsive code with TypeScript.

## Inputs

- `requirements`: What to build
- `files_to_create`: Files to create
- `files_to_modify`: Existing files to modify
- `patterns_to_follow`: Reference patterns in codebase
- `validation_criteria`: Self-validation criteria
  - `critical`: MUST pass before completing (e.g., "TypeScript compiles", "Tests pass", "Build succeeds")
  - `expected`: SHOULD pass (log warning if not)
  - `nice_to_have`: Optional improvements

**Example validation_criteria:**
```json
{
  "critical": [
    "TypeScript compiles without errors",
    "Build completes successfully",
    "No console errors in dev mode"
  ],
  "expected": [
    "ESLint passes",
    "Components render correctly",
    "Accessibility checks pass"
  ],
  "nice_to_have": [
    "Performance optimized",
    "Animation smooth"
  ]
}
```

## Constraints

- Functional components and hooks only
- Semantic HTML elements
- **Do NOT create documentation files** unless explicitly requested
- **For new projects**: Include test dependencies in package.json (vitest, @testing-library/react)
- **Do NOT attempt deployment** - this skill is for development only

## Self-Validation

Before completing, verify `validation_criteria.critical` items pass:
1. Run each critical check (e.g., `npx tsc --noEmit`, `npm run lint`, `npm run build`)
2. If a check fails, fix and re-run
3. Only complete when all critical criteria pass

**Common validation checks:**
- TypeScript compilation: `npx tsc --noEmit`
- Linting: `npm run lint`
- Build production bundle: `npm run build`
- Run tests: `npm test`
- Start dev server locally: `npm run dev` (for manual testing only)

## Output

**Required fields:**
```json
{
  "files_created": ["src/components/Feature.tsx"],
  "files_modified": ["src/App.tsx"],
  "self_validation": {
    "critical_passed": true,
    "checks_run": ["TypeScript compiles", "ESLint passes", "Build succeeds", "Tests pass"]
  },
  "build": {
    "status": "success",
    "output_dir": "./dist",
    "bundle_size": "245KB",
    "build_time": "12s"
  }
}
```

**Output fields:**
- `files_created`: Array of new files created
- `files_modified`: Array of existing files modified
- `self_validation`: Validation results with checks run
- `build`: Build information (optional, if build was performed)
