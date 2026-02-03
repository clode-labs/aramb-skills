---
name: frontend-critique
description: QA skill for frontend work. Validate implementation against requirements, run/test the feature, and trigger rebuilds when issues found. Use this skill to review UI components, test functionality, verify accessibility, and ensure quality.
category: critique
tags: [frontend, react, typescript, validation, review, qa, testing]
license: MIT
---

# Frontend QA (Critique)

Validate frontend work against requirements. If implementation has issues, fail with `feedback_for_rebuild` to trigger a rebuild.

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
- **Starting**: What you're validating
- **Completion**: Verdict with what works and what doesn't

**Example:**
```
TaskUserResponse(message="🔍 Starting validation of profile page. Checking avatar upload, form editing, and save functionality.")
```

```
TaskUserResponse(message="✅ Validation passed! Score: 85/100. Feature renders, form submits correctly, avatar upload works.")
```

```
TaskUserResponse(message="❌ Validation failed: Avatar preview doesn't show after upload. Form works. See feedback for rebuild details.")
```

Keep messages concise. Focus on verdict and key findings.

## Workflow

1. **Send starting update** via `TaskUserResponse`
2. Read `original_prompt` and `preceding_task` to understand context
3. Locate and read the files (check `files_to_test` or `inputs.files_to_create`)
4. Run the feature to verify it works
5. Check against `user_expectations`
6. Self-validate your review (was it thorough? actionable?)
7. **Send completion update** via `TaskUserResponse` with verdict
8. Output verdict

## Constraints

- **Do NOT create documentation files** or write tests (that's for testing skill)
- Only run npm install if package.json was modified
- Only run build if you need to verify it compiles

## Output

### PASS (implementation works)

```json
{
  "verdict": "pass",
  "score": 85,
  "summary": "All user requirements validated successfully",
  "files_reviewed": ["src/components/Feature.tsx"],
  "what_works": ["Feature renders", "Form submits correctly"]
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
        "what": "Avatar preview doesn't show after upload",
        "expected": "Preview should appear after selecting image",
        "actual": "No preview renders",
        "location": "src/components/AvatarUpload.tsx:45",
        "suggestion": "Add useEffect to create object URL from File"
      }
    ],
    "files_reviewed": ["src/components/AvatarUpload.tsx"],
    "what_works": ["File picker opens"],
    "what_doesnt_work": ["Preview doesn't render"]
  }
}
```
