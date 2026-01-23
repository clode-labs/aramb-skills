---
name: backend-critique
description: Validate backend work against requirements and best practices. Use this skill to review any backend-related implementation including APIs, services, tests, database changes, or integrations.
category: critique
tags: [backend, api, golang, python, validation, review, qa, security]
license: MIT
---

# Backend Critique

Review and validate backend work against requirements and quality standards.

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
- Run the service/endpoints to verify they work
- Check that business logic matches requirements
- Verify security: auth, input validation, no SQL injection
- Check error handling and edge cases
- Look for common issues: missing validation, exposed secrets, improper error responses

### When validating tests (testing skills)
- Run the test suite to verify tests pass
- Check that tests actually verify the stated criteria
- Verify test quality: readable, maintainable, isolated
- Check coverage of critical paths and error cases
- Look for common issues: missing assertions, tests that don't test anything, hardcoded test data that could fail

### When validating database changes (migration skills)
- Verify migrations run successfully (up and down)
- Check schema matches requirements
- Verify indexes exist for query patterns
- Look for common issues: missing constraints, no rollback, data loss on down migration

### When validating other skill types
- Read the skill_id and task description to understand the work
- Focus on whether the output matches what the task was supposed to produce
- Apply the validation_criteria provided
- Use your judgment for domain-specific quality checks

## Workflow

1. **Understand the context**
   - Read `preceding_task` to know what skill produced the work
   - Read `original_prompt` to understand the overall goal
   - Read `validation_criteria` to know what must be verified

2. **Locate the work**
   - Find files created/modified by the preceding task
   - Read the implementation to understand what was built

3. **Prepare validation scenario**
   - Based on the skill type, determine how to validate
   - For APIs: make requests, check responses
   - For tests: run the test suite
   - For migrations: run up/down migrations
   - For other: verify output matches expectations

4. **Check criteria systematically**
   - **Critical**: All must pass for a passing verdict
   - **Expected**: Should pass for quality implementation
   - **Nice to have**: Note but don't fail for these

5. **Output structured verdict**

## Validation Reference

### For APIs/Endpoints
- Endpoints respond with correct status codes
- Request/response schemas match spec
- Authentication enforced on protected routes
- Authorization checks implemented
- Input validation on all user input
- Error responses are structured and safe

### For Tests
- All tests pass when run
- Tests verify behavior, not implementation details
- Happy path and error cases covered
- Tests are isolated and don't depend on order
- No skipped tests without justification

### For Database/Migrations
- Migration runs without errors
- Rollback works correctly
- Indexes exist for query patterns
- Constraints enforce data integrity
- No data loss scenarios

### For Services/Business Logic
- Logic matches requirements
- Edge cases handled
- Transactions used where needed
- External calls have timeouts and retries
- Sensitive data handled properly

### Security (Always Check)
- No SQL injection vulnerabilities
- No hardcoded credentials or secrets
- Passwords hashed with proper algorithm
- Sensitive data not logged
- HTTPS enforced where applicable

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
2. **Security issues are always critical** - Any security vulnerability is an automatic fail
3. **Adapt to context** - Use `preceding_task.skill_id` to apply appropriate validation
4. **Be specific** - Include file paths and line numbers in issues
5. **Be actionable** - Provide clear suggestions for how to fix issues
6. **Score objectively** - 100 = perfect, 70+ = acceptable
7. **Run the work** - Don't just read code, actually run/test it when possible
8. **Output valid JSON only**
