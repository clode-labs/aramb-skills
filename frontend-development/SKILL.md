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

## Constraints

- Functional components and hooks only
- Semantic HTML elements
- **Do NOT create documentation files** unless explicitly requested
- **Do NOT run npm install, build, lint, or tests** - just write the code
- **Do NOT attempt deployment** - this skill is for development only

## Workflow

1. Write all required files
2. Report what was created
3. Done - user will run/test manually

## Output

```json
{
  "files_created": ["src/App.tsx", "src/components/Game.tsx"],
  "files_modified": [],
  "framework": "React 18 with TypeScript",
  "commands": {
    "install": "npm install",
    "dev": "npm run dev"
  }
}
```
