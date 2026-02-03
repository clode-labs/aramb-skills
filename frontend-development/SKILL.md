---
name: frontend-development
description: Build modern frontend applications using React, Vue, or vanilla JavaScript. Use this skill for creating UI components, pages, forms, and interactive web interfaces with proper styling, accessibility, and responsive design.
category: development
tags: [frontend, react, typescript, components, ui, accessibility]
license: MIT
---

# Frontend Development

Build components following project patterns. Write accessible, responsive code with TypeScript.

## Session Continuity

Your session persists. You may be started fresh OR resumed with new context.

### Trigger Types

| Trigger | Meaning |
|---------|---------|
| `start` | Normal task execution (first time) |
| `resume` | User provided additional context |
| `task_chat` | Direct message from task chat UI |

### Resume Trigger Format

When resumed, you receive:
```
## Task Resumed

The user has provided additional context:

<user's message>

Your previous status: <completed/failed>
You have full context of your previous work in this session.
```

### How to Handle Resume

| Previous Status | User Intent | Action |
|-----------------|-------------|--------|
| `failed` | Providing fix info | Retry with new context |
| `completed` | Wants modification | Review and update |
| `completed` | Asking question | Answer from your context |
| `in_progress` | Adding context | Incorporate and continue |

### Q&A Mode

If resumed with `mode="qa"`:
- Only answer questions
- Do NOT perform new work
- Use `TaskChatResponse` to reply

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

## Output Requirements (IMPORTANT)

Before completing, you MUST set comprehensive outputs. The planner uses these
to answer user questions without needing to resume you.

**Always include:**

```python
outputs = {
    # URLs and identifiers
    "url": "https://app.example.com",
    "deployment_id": "dep-123",

    # Files created/modified
    "files_created": ["src/App.tsx", "src/components/Button.tsx"],
    "files_modified": ["package.json", "src/index.tsx"],

    # Technology choices
    "framework": "React 18 with TypeScript",
    "styling": "Tailwind CSS",
    "state_management": "Zustand",

    # Key decisions (for "why did you..." questions)
    "key_decisions": "Used Zustand over Redux for simpler state management",

    # How to use/run
    "commands": {
        "dev": "npm run dev",
        "build": "npm run build",
        "test": "npm test"
    },

    # Any other values the user might ask about
    "port": 3000,
    "api_endpoint": "/api/v1"
}
```

**Why this matters:**
- Planner receives your outputs in `task_completed` trigger
- Planner can answer "What's the URL?", "What framework?", etc. immediately
- No need to resume you for simple factual questions
- Only complex "how/why" questions require resume with mode="qa"

## Output

**Required fields:**
```json
{
  "files_created": ["src/components/Feature.tsx"],
  "files_modified": ["src/App.tsx"],
  "framework": "React 18 with TypeScript",
  "styling": "Tailwind CSS",
  "commands": {
    "dev": "npm run dev",
    "build": "npm run build",
    "test": "npm test"
  },
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
- `framework`: Framework and language used
- `styling`: Styling approach used
- `commands`: How to run dev, build, test
- `self_validation`: Validation results with checks run
- `build`: Build information (optional, if build was performed)
