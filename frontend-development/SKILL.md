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

## Task Chat Communication

Send progress updates to the task chat so users can follow along. Use `TaskUserResponse` MCP tool for key milestones:

**When to send updates:**
- **Starting**: Brief summary of what you're about to build
- **Key milestones**: After completing significant components or steps
- **Completion**: Summary of what was accomplished with key details

**Example:**
```
TaskUserResponse(message="🚀 Starting to build the calculator. Creating Calculator, Display, ButtonPanel, and Button components with TypeScript.")
```

```
TaskUserResponse(message="✅ Calculator complete! Created 4 components with full arithmetic logic, keyboard support, and error handling. Run `npm run dev` to test.")
```

Keep messages concise (1-2 sentences). Focus on what the user cares about.

## Workflow

1. **Send starting update** via `TaskUserResponse`
2. Write all required files
3. **Send completion update** via `TaskUserResponse` with summary
4. Report what was created in outputs

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
