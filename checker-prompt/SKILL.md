---
name: checker-prompt
description: Craft a precise checker_prompt for external validation — specifies what the checker agent must verify
---

# Checker Prompt Skill

Use this skill whenever you set `enable_checker: true` on a task **or a workflow node** (the node's `checkerPrompt` setting). The `checker_prompt` is the instruction set for an independent checker review — the unit's own assigned agent re-run in a fresh, read-only session as a gatekeeper (no separate checker persona). It has no knowledge of the task/step history — it only sees what you write here. Be precise. The unit's acceptance criteria are always attached as well; the `checker_prompt`, when present, is the primary spec.

## You write the validation guideline — not the reporting instructions

The `checker_prompt` is **only** the guideline of what to verify (context + criteria, below). The gatekeeper's behavior — read-only auditing, how it decides, and how it commits the outcome — is supplied by the platform's `checker_executor` system prompt, not by you. Do NOT bake verdict-reporting or tool-call instructions into the `checker_prompt`.

For reference (so you know what the gatekeeper does with what you write): **the STATUS the checker writes IS the verdict.** There is no `verdict` field in `outputs` — the status field carries the decision, and a DIRTY verdict's gaps travel in a top-level `feedback` arg. The checker uses `aramb_tasks.update` (with `task_id`) or `aramb_workflows.update_step` (with `step_id`) — both rendered into its dispatch User Message. (Session-implicit variants no longer exist; the runtime rejects cross-task/step writes as `context_drift`.) It picks exactly one of four terminal calls:

- **CLEAN** → `aramb_tasks.update task_id="<TASK_UUID>" status="done" outputs='{"audit":"clean","notes":"<summary>"}'`
- **DIRTY, retry** (rounds remain) → task: `status="inbox"` · workflow step: `status="pending"`, with the gaps in `feedback='{"round":N,"previous_gaps":[{id,fixed,fix_note}],"new_gaps":[{description,severity}]}'`
- **DIRTY, exhausted** (final round) → `status="failed" error="<MAX> rounds; integrity gaps remain: <list>"`
- **CAN'T AUDIT** → task: `status="needs_master_attention"` · workflow step: `status="failed"` (steps have no master-escalation path), with `error="cannot audit: <reason>"`

You don't write any of these — the `checker_executor` prompt does. Your job is the validation guideline below.

## Structure

A `checker_prompt` has two parts:

### 1. Context — what was built
One sentence describing what the maker task produces. Tell the checker what to look for.

```
The maker task built a REST API endpoint POST /api/users that creates a new user and returns the user object.
```

### 2. Criteria — what to verify
Explicit, binary checks. Each one is either met or not met. One per line, starting with a dash.

```
Verify each of the following:
- POST /api/users returns HTTP 201 with a JSON body containing id, email, created_at
- POST /api/users returns HTTP 400 when email is missing or malformed
- POST /api/users returns HTTP 409 when email already exists
- Passwords are hashed — plaintext is never stored
- Unit tests exist and pass
```

## Rules

**Be binary.** "The endpoint works" is not a criterion. "GET /api/health returns HTTP 200" is.

**Specify paths and commands.** "Tests pass" is weak. "cd /workspace && npm test exits 0" is strong.

**Cover failure cases.** Don't only verify the happy path. Include error codes, edge cases, security constraints.

**Severity guide** (checker uses this to classify gaps):
- Critical — criterion not met, broken behavior, missing required output, security issue
- Minor — cosmetic, suboptimal but functional, minor deviation

**No implementation details.** The checker verifies outputs, not how the maker got there.

## Full example

Task: "Add JWT authentication to the Express API"

```
checker_prompt: |
  The maker task added JWT-based authentication to the Express API.

  Verify each of the following:
  - POST /api/auth/login with valid credentials returns HTTP 200 with a `token` field (JWT string)
  - POST /api/auth/login with invalid credentials returns HTTP 401
  - GET /api/me with a valid Bearer token returns HTTP 200 with the user object
  - GET /api/me without a token returns HTTP 401
  - GET /api/me with an expired or tampered token returns HTTP 401
  - JWT secret is loaded from environment variable JWT_SECRET, not hardcoded
  - cd /workspace && npm test exits 0
```

## When to use enable_checker

Set `enable_checker: true` and write a `checker_prompt` for tasks where:
- The output has observable, testable behavior (API endpoints, UI interactions, CLI outputs)
- Multiple criteria must ALL be met for the task to be considered complete
- The maker agent cannot reliably self-validate

Skip the checker for:
- Research or content tasks with no binary pass/fail criteria
- Tasks that are themselves validation tasks (testers, reviewers)
