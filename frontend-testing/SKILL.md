---
name: frontend-testing
description: QA skill for frontend code. Write tests, validate user requirements, and trigger rebuilds when implementation has issues. Use this skill for unit tests, integration tests, and e2e tests using Jest, Vitest, React Testing Library, Playwright, or Cypress.
category: testing
tags: [frontend, testing, vitest, jest, playwright, react-testing-library, qa, critique]
license: MIT
---

# Frontend QA (Testing)

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
