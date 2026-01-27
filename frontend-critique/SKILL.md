---
name: frontend-critique
description: Validate frontend work against requirements and best practices. Use this skill to review any frontend-related implementation including UI components, tests, styling, or integrations.
category: critique
tags: [frontend, react, typescript, validation, review, qa]
license: MIT
---

# Frontend Critique

Review and validate frontend work against requirements and quality standards.

## Inputs

You will receive:
- `original_prompt`: The user's original request (overall goal)
- `preceding_task`: Information about the task you're validating:
  - `skill_id`: Which skill produced this work (tells you what type of work to validate)
  - `task_name`: What the task was called
  - `description`: What the task was supposed to do
- `validation_criteria`: Specific criteria to check (critical, expected, nice_to_have)

## Context-Aware Validation

**Read `preceding_task.skill_id` to understand what you're validating.** Different types of work require different validation approaches:

### When validating code implementation (development skills)
- Run/render the implementation to verify it works
- Check that it meets the functional requirements
- Verify code quality, patterns, and conventions
- Check accessibility and responsiveness
- Look for common issues: missing error states, hardcoded values, etc.

### When validating tests (testing skills)
- Run the test suite to verify tests pass
- Check that tests actually verify the stated criteria
- Verify test quality: readable, maintainable, no false positives
- Check coverage of critical paths
- Look for common issues: missing assertions, flaky tests, implementation testing vs behavior testing

### When validating other skill types
- Read the skill_id and task description to understand the work
- Focus on whether the output matches what the task was supposed to produce
- Apply the validation_criteria provided
- Use your judgment for domain-specific quality checks

## Workflow

1. **Understand the context** (read only, no commands)
   - Read `preceding_task` to know what skill produced the work
   - Read `original_prompt` to understand the overall goal
   - Read `validation_criteria` to know what must be verified

2. **Locate the work efficiently**
   - Check `inputs.files_to_create` or `inputs.files_to_modify` if available
   - Otherwise, use targeted glob patterns (don't scan entire codebase)
   - Read only the files relevant to validation

3. **Validate with minimal commands**
   - **Only run npm install if package.json was modified** by the preceding task
   - **Only run build if you need to verify it compiles** - skip if just reviewing code
   - **For tests**: run `npm test` once - don't run multiple times
   - If tests already pass (from testing task), focus on test quality review instead of re-running

4. **Check criteria as a checklist** (be concise)
   - **Critical**: Quick pass/fail check for each
   - **Expected**: Note status briefly
   - **Nice to have**: Only mention if notably present or absent

5. **Output structured verdict** (JSON only, no prose explanation)

## Validation Reference

### For UI Components
- Renders without errors
- Handles user interactions correctly
- Loading and error states work
- Accessible (semantic HTML, labels, focus states)
- Responsive across breakpoints

### For Tests
- All tests pass when run
- Tests verify behavior, not implementation details
- Critical user paths are covered
- No skipped tests without justification
- Tests are readable and maintainable

### For Styling/CSS
- Styles apply correctly
- No layout issues or overflow
- Works across target browsers
- Follows design system if one exists

### For State Management
- State updates correctly on actions
- No stale state issues
- Handles async operations properly
- Edge cases handled (empty, loading, error)

## Output Format

```json
{
  "verdict": "pass | fail",
  "score": 85,
  "context": {
    "validating": "<skill_id from preceding_task>",
    "task": "<task_name from preceding_task>"
  },
  "summary": "Brief overall assessment of the work",
  "critical_issues": [
    {
      "criterion": "Which criterion failed",
      "issue": "What's wrong",
      "location": "File and line if applicable",
      "suggestion": "How to fix"
    }
  ],
  "expected_issues": [...],
  "nice_to_have_suggestions": [...],
  "feedback_for_retry": "Clear instructions if verdict is fail - what specifically needs to change"
}
```

## Rules

1. **Critical issues = fail** - Any critical criterion not met results in fail verdict
2. **Adapt to context** - Use `preceding_task.skill_id` to apply appropriate validation
3. **Be specific** - Include file paths and line numbers in issues
4. **Be actionable** - Provide clear suggestions for how to fix issues
5. **Score objectively** - 100 = perfect, 70+ = acceptable
6. **Run only what's necessary** - Don't reinstall packages or rebuild unless needed to verify a specific criterion
7. **Output valid JSON only** - No prose before or after the JSON block
8. **Be efficient** - A critique should take less time than the work it's validating
