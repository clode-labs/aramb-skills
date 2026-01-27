---
name: backend-critique
description: QA skill for backend work. Validate implementation against requirements, run/test APIs, check security, and trigger rebuilds when issues found. Use this skill to review services, test endpoints, verify database operations, and ensure quality.
category: critique
tags: [backend, api, golang, python, validation, review, qa, security, testing]
license: MIT
---

# Backend QA (Critique)

Validate backend work against requirements. Check security. If implementation has issues, fail with `feedback_for_rebuild` to trigger a rebuild.

## Inputs

- `original_prompt`: User's original request
- `preceding_task`: Info about the build task you're validating
- `user_expectations`: What user expects to work
- `files_to_test`: Files created by build task
- `validation_criteria`: Self-validation criteria
  - `critical`: MUST pass before completing
  - `expected`: SHOULD pass (log warning if not)
  - `nice_to_have`: Optional improvements

## Workflow

1. Read `original_prompt` and `preceding_task` to understand context
2. Locate and read the files
3. Test API endpoints with curl/requests
4. Check security: auth required? input validation? no SQL injection?
5. Verify database state after operations
6. Self-validate your review
7. Output verdict

## Constraints

- **Do NOT create documentation files** or write tests (that's for testing skill)
- **Always check security**: auth, authz, input validation

## Output

### PASS (implementation works)

```json
{
  "verdict": "pass",
  "score": 90,
  "summary": "All user requirements validated, security checks pass",
  "files_reviewed": ["internal/handlers/subscription_handlers.go"],
  "security_verified": ["Auth enforced", "Input validation present"],
  "what_works": ["API endpoints respond correctly", "Auth middleware functioning"]
}
```

### FAIL (triggers correctness loop)

```json
{
  "verdict": "fail",
  "feedback_for_rebuild": {
    "summary": "Brief description of what's broken",
    "issues": [
      {
        "what": "Subscription endpoint allows unauthenticated access",
        "expected": "POST /api/v1/subscriptions requires auth",
        "actual": "Endpoint returns 201 without auth token",
        "location": "internal/handlers/subscription_handlers.go:34",
        "suggestion": "Add auth middleware to subscription routes",
        "severity": "security"
      }
    ],
    "files_reviewed": ["internal/handlers/subscription_handlers.go"],
    "what_works": ["Migration runs"],
    "what_doesnt_work": ["Auth missing"]
  }
}
```
