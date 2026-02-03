---
name: backend-testing
description: QA skill for backend code. Write tests, validate user requirements, and trigger rebuilds when implementation has issues. Use this skill for unit tests, integration tests, and API tests using pytest, Go testing, Jest, or similar frameworks.
category: testing
tags: [backend, testing, golang, pytest, integration, unit-tests, qa, critique]
license: MIT
---

# Backend QA (Testing)

Write tests that validate user requirements. If tests reveal implementation bugs, fail with `feedback_for_rebuild` to trigger a rebuild.

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
| `completed` | Wants modification | Review and update tests |
| `completed` | Asking question | Answer from your context |
| `in_progress` | Adding context | Incorporate and continue |

### Q&A Mode

If resumed with `mode="qa"`:
- Only answer questions
- Do NOT perform new work
- Use `TaskChatResponse` to reply

## Inputs

- `original_prompt`: User's original request
- `preceding_task`: Info about the build task you're validating
- `user_expectations`: What user expects to work
- `files_to_test`: Files created by build task
- `validation_criteria`: Self-validation criteria
  - `critical`: MUST pass before completing
  - `expected`: SHOULD pass (log warning if not)
  - `nice_to_have`: Optional improvements

## Task Chat Communication

Send progress updates to the task chat so users can follow along. Use `TaskUserResponse` MCP tool for key milestones:

**When to send updates:**
- **Starting**: What API/endpoints you're testing
- **Test results**: Summary of tests written and results
- **Completion**: Final verdict with pass/fail counts and security status

**Example:**
```
TaskUserResponse(message="🧪 Starting QA for subscription API. Testing CRUD endpoints, auth enforcement, and input validation.")
```

```
TaskUserResponse(message="✅ QA passed! 25 tests, all passing. 78% coverage. Auth enforced, validation works, no security issues found.")
```

```
TaskUserResponse(message="❌ QA failed: Security issue found. POST /subscriptions allows unauthenticated access. See feedback for details.")
```

Keep messages concise. Focus on verdict, security status, and key findings.

## Workflow

1. **Send starting update** via `TaskUserResponse`
2. Read `original_prompt` and `preceding_task` to understand context
3. Read existing tests to understand patterns
4. Write tests for `user_expectations` - focus on API behavior
5. **Always include security tests**: auth required, authorization, input validation
6. Run tests
   - If tests fail due to **implementation bugs** → fail with `feedback_for_rebuild`
   - If tests fail due to **test bugs** → fix tests and re-run
7. Self-validate: coverage adequate? security tested?
8. **Send completion update** via `TaskUserResponse` with verdict
9. Output verdict

## Constraints

- Follow existing test patterns in the codebase
- Use test fixtures and factories for data setup
- Clean up test data after tests

## Output Requirements (IMPORTANT)

Before completing, you MUST set comprehensive outputs. The planner uses these
to answer user questions without needing to resume you.

**Always include:**

```python
outputs = {
    # Test results
    "verdict": "pass",  # or "fail"
    "tests_written": ["internal/handlers/resource_test.go"],
    "tests_passing": 25,
    "tests_failing": 0,
    "coverage": "78%",

    # What was tested
    "tested_files": ["internal/handlers/resource.go", "internal/services/resource_service.go"],
    "test_framework": "Go testing with testify",

    # Key validations (for "what did you test?" questions)
    "validations": [
        "API endpoints return correct status codes",
        "Authentication enforced",
        "Input validation works",
        "Error handling correct"
    ],

    # Commands
    "commands": {
        "test": "go test ./...",
        "coverage": "go test -coverprofile=coverage.out ./..."
    }
}
```

**Why this matters:**
- Planner receives your outputs in `task_completed` trigger
- Planner can answer "Did tests pass?", "What's the coverage?", etc. immediately
- No need to resume you for simple factual questions

## Output

### PASS (tests written and passing)

Complete the task successfully with comprehensive outputs.

```json
{
  "verdict": "pass",
  "tests_written": ["internal/handlers/resource_test.go"],
  "tests_passing": 25,
  "tests_failing": 0,
  "coverage": "78%",
  "tested_files": ["internal/handlers/resource.go"],
  "test_framework": "Go testing with testify",
  "validations": ["API endpoints work", "Auth enforced", "Validation works"]
}
```

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
