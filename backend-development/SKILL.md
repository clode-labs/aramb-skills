---
name: backend-development
description: Build backend services, APIs, and server-side applications. Use this skill for creating REST/GraphQL APIs, database integrations, authentication systems, and server-side business logic in Go, Python, or Node.js.
category: development
tags: [backend, api, rest, golang, python, nodejs, database]
license: MIT
---

# Backend Development

Build APIs following project patterns. Implement proper validation, error handling, and security.

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

- Always validate input data
- Use parameterized queries (never string concatenation for SQL)
- Follow OWASP security guidelines
- **Do NOT create documentation files** unless explicitly requested

## Self-Validation

Before completing, verify `validation_criteria.critical` items pass:
1. Run each critical check (e.g., `go build ./...`, `go test ./...`, start server)
2. If a check fails, fix and re-run
3. Only complete when all critical criteria pass

## Output

```json
{
  "files_created": ["internal/handlers/resource.go", "migrations/00X_create_resource.sql"],
  "files_modified": ["internal/routes/routes.go"],
  "self_validation": {
    "critical_passed": true,
    "checks_run": ["Go compiles", "Tests pass", "Server starts", "Migrations run"]
  }
}
```
