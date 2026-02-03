---
name: frontend-testing
description: QA skill for frontend code. Write tests, validate user requirements, and trigger rebuilds when implementation has issues. Use this skill for unit tests, integration tests, and e2e tests using Jest, Vitest, React Testing Library, Playwright, or Cypress.
category: testing
tags: [frontend, testing, vitest, jest, playwright, react-testing-library, qa, critique]
license: MIT
---

# Frontend QA (Testing)

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

## Workflow

1. Read `original_prompt` and `preceding_task` to understand context
2. Check test setup in package.json (vitest, jest, @testing-library/react)
3. Write tests for `user_expectations` - focus on user-visible behavior
4. Run tests
   - If tests fail due to **implementation bugs** → fail with `feedback_for_rebuild`
   - If tests fail due to **test bugs** → fix tests and re-run
5. Self-validate: coverage adequate? tests meaningful?
6. Output verdict

## Constraints

- Follow existing test patterns in the codebase
- **Do NOT create documentation files** - only test files
- **Do NOT set up test infrastructure from scratch** - add minimal config to existing files

## Output Requirements (IMPORTANT)

Before completing, you MUST set comprehensive outputs. The planner uses these
to answer user questions without needing to resume you.

**Always include:**

```python
outputs = {
    # Test results
    "verdict": "pass",  # or "fail"
    "tests_written": ["src/components/Feature.test.tsx"],
    "tests_passing": 15,
    "tests_failing": 0,
    "coverage": "85%",

    # What was tested
    "tested_files": ["src/components/Feature.tsx"],
    "test_framework": "Vitest with React Testing Library",

    # Key validations (for "what did you test?" questions)
    "validations": [
        "Component renders correctly",
        "User interactions work",
        "Error states handled"
    ],

    # Commands
    "commands": {
        "test": "npm test",
        "coverage": "npm test -- --coverage"
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
  "tests_written": ["src/components/Feature.test.tsx"],
  "tests_passing": 15,
  "tests_failing": 0,
  "coverage": "85%",
  "tested_files": ["src/components/Feature.tsx"],
  "test_framework": "Vitest with React Testing Library",
  "validations": ["Component renders correctly", "User interactions work"]
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
        "what": "Avatar upload doesn't work",
        "expected": "User can upload image and see preview",
        "actual": "Upload button does nothing",
        "location": "src/components/AvatarUpload.tsx",
        "suggestion": "Add onClick handler to trigger file input"
      }
    ],
    "tests_written": ["src/components/AvatarUpload.test.tsx"],
    "tests_failing": ["should open file picker when upload button clicked"]
  }
}
```
