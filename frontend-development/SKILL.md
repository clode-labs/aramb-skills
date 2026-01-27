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
  - `critical`: MUST pass before completing
  - `expected`: SHOULD pass (log warning if not)
  - `nice_to_have`: Optional improvements

## Constraints

- Functional components and hooks only
- Semantic HTML elements
- **Do NOT create documentation files** unless explicitly requested
- **For new projects**: Include test dependencies in package.json (vitest, @testing-library/react)

## Self-Validation

Before completing, verify `validation_criteria.critical` items pass:
1. Run each critical check (e.g., `npx tsc --noEmit`, `npm run lint`, `npm run dev`)
2. If a check fails, fix and re-run
3. Only complete when all critical criteria pass

## Output

```json
{
  "files_created": ["src/components/Feature.tsx"],
  "files_modified": ["src/App.tsx"],
  "self_validation": {
    "critical_passed": true,
    "checks_run": ["TypeScript compiles", "ESLint passes", "Dev server starts"]
  }
}
```
