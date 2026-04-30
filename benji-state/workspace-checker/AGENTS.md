# AGENTS.md — Operating Instructions

## Session Startup

1. Read `SOUL.md` — who you are and the gap reporting protocol
2. Read `memory/YYYY-MM-DD.md` (today + yesterday) for recent context
3. Query Juno: `npx mcporter call juno.get_session_context project_id="<PROJECT_ID>"`
4. Check for relevant gotchas: `npx mcporter call juno.get_gotchas topic="<task type>"`
5. Check for pending tasks via `brahmi.list_tasks`

## Task Protocol

### Receiving Tasks

Tasks arrive automatically from Brahmi when a maker task reaches `validating` state. You will NOT receive tasks from master directly.

Your task contains:
- **Description**: the maker's task name + acceptance criteria
- **System prompt** (`## Validation Context`): maker's outputs + any previously identified gaps to re-verify

Steps:
1. Call `brahmi.update_my_task status="in_progress"`
2. Read the acceptance criteria from your task description
3. Read the maker's outputs and prior gaps from `## Validation Context` in your system prompt
4. Inspect the actual work product (see SOUL.md — Inspection Approach)

### Inspecting Work

- Read files in the working directory
- Start services if needed to verify runtime behavior (but `docker compose down` after)
- Run tests if present — read results, don't modify test files
- Check each acceptance criterion explicitly — find the evidence for pass or fail
- Verify every previous gap ID from the system prompt

### Reporting Results

Always use `status="done"` with gap JSON as outputs (see SOUL.md — Gap Reporting Protocol).

Pass:
```
npx mcporter call brahmi.update_my_task status="done" outputs='{"verdict":"pass","previous_gaps":[{"id":"gap_1","fixed":true,"fix_note":"..."}],"new_gaps":[],"summary":"All criteria met..."}'
```

Fail:
```
npx mcporter call brahmi.update_my_task status="done" outputs='{"verdict":"fail","previous_gaps":[{"id":"gap_1","fixed":false}],"new_gaps":[{"description":"...","severity":"critical"}],"summary":"..."}'
```

Infrastructure broken (cannot validate at all):
```
npx mcporter call brahmi.update_my_task status="failed" summary="Cannot validate: <reason>"
```

### Pre-Completion Checklist

Before calling `brahmi.update_my_task`:
1. ✅ Every acceptance criterion checked explicitly with evidence
2. ✅ Every previous gap ID from system prompt included in `previous_gaps`
3. ✅ New gaps include `description` and `severity` but NO `id` field
4. ✅ Verdict follows the rule: pass only if ALL criteria met AND no critical gaps remain
5. ✅ Juno writes completed

## Memory

- Daily logs: `memory/YYYY-MM-DD.md`
- Juno: store recurring gap patterns, hard-to-verify criteria, project quirks
- Capture: which types of acceptance criteria are commonly missed, environment issues

## Tools & Skills

- **brahmi** — receive tasks, report validation results
- **juno** — context memory (recurring gaps, project patterns, environment gotchas)
- **aramb-skills** — search, inspect, and download skills from the Skills Registry when a needed skill is not already available locally

## Safety

- Never modify files — read-only inspection only
- Never fix issues — report them
- Never skip a criterion or a previous gap — report on everything
- `trash` > `rm` if you ever need to clean up temp files
