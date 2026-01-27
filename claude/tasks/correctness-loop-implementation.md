# Correctness Loop Implementation - aramb-skills

**Date:** 2025-01-27
**Status:** Planned
**Related:** `/Users/siva/workspace/claude/tasks/correctness-loop-architecture.md`

## Overview

This document outlines the changes required in `aramb-skills` to implement the correctness loop architecture. The skills are responsible for:
1. **Planners:** Creating the 2-task pattern with `critiques_tasks` relationship
2. **Critique skills:** Outputting standardized verdicts
3. **Development skills:** Using `validation_criteria` for self-validation

## Current State

The skills already have partial support:
- Planners create 2-task patterns (Build + QA)
- Critique skills output `verdict` and `feedback_for_rebuild`
- `validation_criteria` is documented but not consistently structured
- `critiques_tasks` relationship is NOT currently included in task inputs

## Changes Required

---

## Part 1: Planner Skills

### 1.1 Update `frontend-planner/SKILL.md`

**File:** `frontend-planner/SKILL.md`

**Current state:** Creates Build and QA tasks with dependencies, but QA task doesn't include `critiques_tasks` in inputs.

**Changes needed:**

1. **Add `critiques_tasks` to QA task inputs:**

```yaml
# In the task creation examples, update QA task inputs:
{
  "uniqueId": 2,
  "task_name": "QA: Test user profile page",
  "skill_id": "aramb-skills/frontend-testing",
  "logicalDependencies": [1],
  "inputs": {
    "original_prompt": "...",
    "user_expectations": ["User can upload avatar", "User can edit profile fields"],
    "critiques_tasks": ["{{task_1_uuid}}"],  # <-- ADD THIS
    "files_to_test": ["src/components/UserProfile.tsx"],
    "build_task_summary": "Built user profile page with avatar upload and editable fields"
  },
  "validation_criteria": {
    "critical": ["Tests written", "Tests execute without errors"],
    "expected": ["Edge cases covered", "Loading states tested"]
  }
}
```

2. **Document the `critiques_tasks` field:**

Add a section explaining the field:

```markdown
### The `critiques_tasks` Field

When creating a QA/critique task, include `critiques_tasks` in its inputs:

```json
"inputs": {
  "critiques_tasks": ["{{build_task_uuid}}"],
  ...
}
```

This tells the orchestrator which task(s) to retry if the QA task fails with `verdict: fail`.

**Rules:**
- Use the build task's UUID (resolved from `uniqueId` after creation)
- Can include multiple tasks: `["{{task_1_uuid}}", "{{task_2_uuid}}"]`
- Never include sub-task UUIDs - only main/parent task UUIDs
```

3. **Update validation_criteria examples:**

Ensure all examples use the standardized structure:

```json
"validation_criteria": {
  "critical": [
    "TypeScript compiles without errors",
    "No ESLint errors",
    "Dev server starts successfully"
  ],
  "expected": [
    "Components render without console errors",
    "No accessibility violations"
  ],
  "nice_to_have": [
    "All props are typed",
    "Storybook stories added"
  ]
}
```

4. **Add sub-task critique rules:**

```markdown
### Sub-tasks and Critique

**Sub-tasks CANNOT be in `critiques_tasks`.**

If a parent task has sub-tasks:
- The QA task depends on the **parent task**, not sub-tasks
- The QA task's `critiques_tasks` includes the **parent task UUID**
- If QA fails, the entire parent (with all sub-tasks) retries

Example:
```json
// Parent task
{ "uniqueId": 1, "task_name": "Build checkout flow", ... }

// QA task - critiques PARENT, not sub-tasks
{
  "uniqueId": 2,
  "task_name": "QA: Test checkout flow",
  "logicalDependencies": [1],
  "inputs": {
    "critiques_tasks": ["{{task_1_uuid}}"],  // Parent UUID only
    ...
  }
}
```
```

### 1.2 Update `backend-planner/SKILL.md`

**File:** `backend-planner/SKILL.md`

Apply the same changes as frontend-planner:

1. Add `critiques_tasks` to all QA task examples
2. Document the `critiques_tasks` field
3. Update validation_criteria to use standardized structure
4. Add sub-task critique rules

**Backend-specific validation_criteria examples:**

```json
"validation_criteria": {
  "critical": [
    "Go code compiles (go build ./...)",
    "No golangci-lint errors",
    "Server starts without panic"
  ],
  "expected": [
    "API endpoints respond to health check",
    "Database migrations apply cleanly"
  ],
  "nice_to_have": [
    "100% test coverage on new code",
    "OpenAPI spec updated"
  ]
}
```

---

## Part 2: Critique Skills

### 2.1 Update `frontend-critique/SKILL.md`

**File:** `frontend-critique/SKILL.md`

**Current state:** Outputs verdict and feedback_for_rebuild, but format may not match architecture spec.

**Changes needed:**

1. **Standardize output format:**

Update the output section to match the architecture:

```markdown
## Output Format

Your final output MUST include a structured verdict:

### On PASS:
```json
{
  "verdict": "pass",
  "score": 85,  // optional: 0-100
  "summary": "All user requirements validated successfully",
  "tests_written": ["src/components/UserProfile.test.tsx"],
  "tests_passing": ["renders user avatar", "allows profile editing", ...]
}
```

### On FAIL:
```json
{
  "verdict": "fail",
  "score": 45,  // optional: 0-100
  "feedback_for_rebuild": {
    "summary": "Avatar upload functionality not working",
    "issues": [
      {
        "what": "Upload button doesn't trigger file picker",
        "expected": "Clicking upload opens file dialog",
        "actual": "Nothing happens on click",
        "location": "src/components/AvatarUpload.tsx:45",
        "suggestion": "Add onClick handler to trigger hidden file input"
      },
      {
        "what": "Form validation missing for email field",
        "expected": "Invalid email shows error message",
        "actual": "Form submits with invalid email",
        "location": "src/components/ProfileForm.tsx:72",
        "suggestion": "Add email regex validation in handleSubmit"
      }
    ],
    "tests_written": ["src/components/AvatarUpload.test.tsx"],
    "tests_failing": ["should open file picker on click", "should validate email format"],
    "files_reviewed": ["src/components/UserProfile.tsx", "src/components/AvatarUpload.tsx"],
    "what_works": ["Profile renders correctly", "Name field saves"],
    "what_doesnt_work": ["Avatar upload", "Email validation"]
  }
}
```
```

2. **Add self-validation requirements:**

```markdown
## Self-Validation

Before outputting your verdict, validate your own work:

### Critical (Must Pass)
- [ ] Tests are written for each user requirement
- [ ] Tests execute without syntax/import errors
- [ ] You actually ran the tests (not just wrote them)

### Expected (Should Pass)
- [ ] Edge cases are covered (empty inputs, errors, loading states)
- [ ] Tests are meaningful (not just checking element existence)

If your self-validation fails, fix the issues before outputting verdict.
```

3. **Clarify when to output verdict:**

```markdown
## When to Output Verdict

**Output `verdict: pass` when:**
- All user requirements are implemented and working
- Tests pass for each requirement
- No blocking issues found during testing

**Output `verdict: fail` when:**
- Any user requirement is not implemented
- Any user requirement is implemented incorrectly
- Tests reveal bugs that prevent feature from working

**Never output verdict when:**
- You couldn't complete your validation (report error instead)
- You're unsure about requirements (ask for clarification)
```

### 2.2 Update `backend-critique/SKILL.md`

**File:** `backend-critique/SKILL.md`

Apply the same changes as frontend-critique, with backend-specific examples:

```json
{
  "verdict": "fail",
  "feedback_for_rebuild": {
    "summary": "API authentication not enforced on protected endpoints",
    "issues": [
      {
        "what": "GET /api/users returns data without auth token",
        "expected": "401 Unauthorized when no token provided",
        "actual": "200 OK with user list",
        "location": "internal/handlers/users.go:25",
        "suggestion": "Add AuthMiddleware to /api/users route",
        "severity": "security"
      }
    ],
    "tests_written": ["internal/handlers/users_test.go"],
    "tests_failing": ["TestGetUsers_RequiresAuth"]
  }
}
```

---

## Part 3: Testing Skills

### 3.1 Update `frontend-testing/SKILL.md`

**File:** `frontend-testing/SKILL.md`

**Changes needed:**

1. **Add verdict output support:**

Testing skills can also act as critique tasks. Add the verdict output format:

```markdown
## Verdict Output (When Acting as QA Task)

If this task is configured with `critiques_tasks` in inputs, output a verdict:

### Tests Pass:
```json
{
  "verdict": "pass",
  "tests_written": ["src/components/Feature.test.tsx"],
  "coverage": { "statements": 85, "branches": 78 }
}
```

### Tests Fail (Implementation Bug):
```json
{
  "verdict": "fail",
  "feedback_for_rebuild": {
    "summary": "Feature has implementation bugs",
    "issues": [/* detailed issues */],
    "tests_failing": ["test name 1", "test name 2"]
  }
}
```
```

2. **Add self-validation criteria:**

```markdown
## Self-Validation

Before completing, verify:

### Critical
- [ ] Test file(s) created and saved
- [ ] Tests run without import/syntax errors
- [ ] At least one test per user requirement

### Expected
- [ ] Edge cases covered (null, undefined, empty, error states)
- [ ] Tests are meaningful (assert behavior, not just existence)
```

### 3.2 Update `backend-testing/SKILL.md`

**File:** `backend-testing/SKILL.md`

Apply the same changes as frontend-testing with backend-specific examples.

---

## Part 4: Development Skills

### 4.1 Update `frontend-development/SKILL.md`

**File:** `frontend-development/SKILL.md`

**Changes needed:**

1. **Document validation_criteria usage:**

```markdown
## Self-Validation

Your task includes `validation_criteria` in inputs. Before completing:

### Critical Criteria (Must Pass)
These criteria MUST pass. If any fail, fix the issue before completing.

Common critical criteria:
- **TypeScript compiles**: Run `npx tsc --noEmit` and fix any errors
- **No ESLint errors**: Run `npm run lint` and fix any errors
- **Dev server starts**: Verify `npm run dev` starts without crash

### Expected Criteria (Should Pass)
These should pass. Log a warning if they don't.

### Validation Process
1. After implementing the feature, run each critical check
2. If a check fails, fix the issue
3. Re-run the check to confirm it passes
4. Only complete when all critical criteria pass
```

2. **Add outputs section:**

```markdown
## Task Outputs

Include in your final output:

```json
{
  "files_created": ["src/components/Feature.tsx", ...],
  "files_modified": ["src/App.tsx", ...],
  "self_validation": {
    "critical_passed": true,
    "checks_run": ["TypeScript compiles", "ESLint passes", "Dev server starts"]
  }
}
```
```

### 4.2 Update `backend-development/SKILL.md`

**File:** `backend-development/SKILL.md`

Apply the same changes with backend-specific validation commands:

```markdown
## Self-Validation

Common critical criteria for backend:
- **Go compiles**: Run `go build ./...` and fix any errors
- **No lint errors**: Run `golangci-lint run` and fix any errors
- **Tests pass**: Run `go test ./...` (existing tests should still pass)
- **Server starts**: Verify the server starts without panic
```

---

## Summary of File Changes

| File | Changes |
|------|---------|
| `frontend-planner/SKILL.md` | Add `critiques_tasks` to QA examples, document the field, update validation_criteria format, add sub-task rules |
| `backend-planner/SKILL.md` | Same as frontend-planner |
| `frontend-critique/SKILL.md` | Standardize verdict output format, add self-validation section |
| `backend-critique/SKILL.md` | Same as frontend-critique with backend examples |
| `frontend-testing/SKILL.md` | Add verdict output support, add self-validation section |
| `backend-testing/SKILL.md` | Same as frontend-testing |
| `frontend-development/SKILL.md` | Document validation_criteria usage, add outputs section |
| `backend-development/SKILL.md` | Same as frontend-development |

## Testing Plan

### Manual Testing

1. **Create a prompt that triggers the 2-task pattern:**
   - "Build a user profile page with avatar upload"
   - Verify planner creates Build + QA tasks
   - Verify QA task has `critiques_tasks` in inputs

2. **Test critique failure triggers retry:**
   - Introduce a bug in the build task output
   - Verify QA task outputs `verdict: fail`
   - Verify build task is retried with feedback

3. **Test self-validation:**
   - Create a build task with `validation_criteria`
   - Verify agent validates before completing
   - Verify failures are reported correctly

### Validation Checklist

- [ ] All planner examples include `critiques_tasks`
- [ ] All critique skill outputs use standardized format
- [ ] All development skills document self-validation
- [ ] Sub-task rules are documented in planners
- [ ] Verdict output format matches architecture spec

## Related Documents

- Architecture: `/Users/siva/workspace/claude/tasks/correctness-loop-architecture.md`
- Agent changes: `/Users/siva/workspace/aramb-agents/claude/tasks/correctness-loop-implementation.md`
