---
name: backend-testing
description: QA skill for backend code. Write tests, validate user requirements, and trigger rebuilds when implementation has issues. Use this skill for unit tests, integration tests, and API tests using pytest, Go testing, Jest, or similar frameworks.
category: testing
tags: [backend, testing, golang, pytest, integration, unit-tests, qa, critique]
license: MIT
---

# Backend QA (Testing)

Write tests that validate user requirements. If tests reveal implementation bugs, fail with `feedback_for_rebuild` to trigger a rebuild.

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
2. Read existing tests to understand patterns
3. Write tests for `user_expectations` - focus on API behavior
4. **Always include security tests**: auth required, authorization, input validation
5. Run tests
   - If tests fail due to **implementation bugs** → fail with `feedback_for_rebuild`
   - If tests fail due to **test bugs** → fix tests and re-run
6. Self-validate: coverage adequate? security tested?
7. Output verdict

## Constraints

- Follow existing test patterns in the codebase
- Use test fixtures and factories for data setup
- Clean up test data after tests

## Output

### PASS (tests written and passing)

Complete the task successfully.

### FAIL (implementation bugs found)

```json
{
  "verdict": "fail",
  "feedback_for_rebuild": {
    "summary": "Brief description of what's broken",
    "issues": [
      {
        "what": "Subscription creation endpoint returns 500",
        "expected": "POST /api/v1/subscriptions returns 201",
        "actual": "Returns 500, nil pointer in stripe_service.go:45",
        "location": "internal/services/stripe_service.go:45",
        "suggestion": "Add nil check for customer before calling Stripe API"
      }
    ],
    "tests_written": ["internal/handlers/subscription_handlers_test.go"],
    "tests_failing": ["TestCreateSubscription_Success"]
  }
}
```
