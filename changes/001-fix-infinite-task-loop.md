# 001: Fix Infinite Task Loop from Reflection

**Date:** 2025-12-31
**Status:** Implemented
**Related:** aramb-orchestrator/changes/001-fix-infinite-task-loop.md

## Problem

The `planning` skill is used for both:
1. Initial task planning (correct) - outputs tasks
2. Reflection/evaluation (incorrect) - also outputs tasks, causing infinite loop

## Scan Results

Only `planning` skill creates tasks. All other skills output results, not new tasks:

- ✅ frontend, backend, testing, bugfix, code-review, refactoring, documentation, deployment
- ❌ **planning** - outputs `tasks` array (problematic when used for reflection)

## Solution: Simple Flow for Now

Keep it minimal:

```
Planning → Frontend → Critique (QA)
                         ↓
                    verdict: pass/fail
                         ↓
              if fail: retry frontend (max N times)
```

No code-review in the loop for now. Keep roles simple.

## Changes Required

### 1. Create New `critique` Skill

New skill: `aramb-skills/critique/skill.yaml`

Purpose: QA role that:
- Plans tests based on acceptance criteria
- Runs tests
- Calculates acceptance score
- Returns verdict (pass/fail), NOT new tasks

Output structure (verdict only, no tasks):
```yaml
output_structure:
  verdict:
    type: string
    enum: [pass, fail]
  score:
    type: integer
    minimum: 0
    maximum: 100
  tests_planned:
    type: array
  tests_passed:
    type: integer
  tests_failed:
    type: integer
  blocking_issues:
    type: array
  feedback_for_retry:
    type: string
```

### 2. Update `planning` Skill

Remove from `planning/skill.yaml`:
- Lines 104-127: "Reflection Tasks" section
- Lines 159-177: Example reflection task
- References to `reflection_mode`

Add to planning output:
- `acceptance_criteria` for each task (critical/expected/nice_to_have)

Update valid skill_ids:
- Remove `planning` from the list of skills that can be assigned to tasks
- Add `critique` as valid skill

### 3. Remove Self-Reference

The planning skill currently lists itself as a valid skill_id:
```yaml
# Line 126 - REMOVE "planning" from this list
skill_id must match exactly: frontend, backend, testing, ..., planning
```

Tasks should NEVER have `skill_id: "planning"` - planning only runs once at the start.

## Files Modified

- [x] `planning/skill.yaml` - Removed reflection pattern, added acceptance criteria, replaced `planning` with `critique` in valid skill_ids
- [x] Created `critique/skill.yaml` - New QA skill that outputs verdict (pass/fail), not new tasks

## Future Enhancements (Not Now)

- Fine-grained QA: separate test planning, test execution, scoring
- Code review as optional pre-critique step
- Multiple critique rounds with different focus areas
