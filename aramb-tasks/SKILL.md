---
name: aramb-tasks
description: >
  MCP toolkit for the task lifecycle (aramb_tasks.*). Use these to
  create, update, and list tasks. The task lifecycle is the team-mode
  primitive; this toolkit is hidden in solo mode by tools/list filtering.
---

# Aramb Tasks Toolkit

The `aramb_tasks.*` tools manage the task lifecycle. **You will only see these in team-mode chats** — in solo mode the toolkit is filtered out of `tools/list` and the agent runs without a task surface.

## CRITICAL: mcporter syntax rules
- ALL arguments MUST use `key="value"` format (NOT positional args).
- Status updates use `aramb_tasks.update` with an explicit `task_id`. There is `aramb_tasks.update_me` for the in-task self-update — pick the right one (see below).
- Your dispatch prompt contains your task's UUID. Save it the first time you see it and pass it on every `aramb_tasks.update` call.
- Correct: `npx mcporter call aramb_tasks.update project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="done"`
- WRONG: `npx mcporter call aramb_tasks.update <project_id> <task_id> done` (positional args not supported)

## Create tasks

```bash
npx mcporter call aramb_tasks.create project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" tasks='[{"unique_id": 1, "name": "Task name", "description": "Detailed description", "assigned_agent": "agent-name", "required_toolkits": ["GMAIL"]}]'
```

### required_toolkits — declare third-party tool needs upfront

When a task needs a Composio toolkit (Gmail, Google Sheets, Slack, Notion, GitHub, etc.) to do its work, **declare the slugs in `required_toolkits`** at create time. Brahmi stores the list on the task row, surfaces it to the executing agent in the dispatch prompt, and (eventually) checks the user has connected those toolkits before the agent starts work.

- **Slugs only**, uppercase, exactly as Composio reports them: `GMAIL`, `GOOGLESHEETS`, `GOOGLEDRIVE`, `SLACK`, `NOTION`, `LINEAR`, `GITHUB`, etc. Look them up via `composio toolkit list` if unsure.
- **Empty / omitted** when no third-party tools are needed (most coding tasks). Don't pad the list.
- **Per-task, not per-batch.** A planning task that just writes a plan file → no toolkits. A task that fetches Gmail messages and drops them into a Sheet → `["GMAIL","GOOGLESHEETS"]`.
- **Honest list.** Only what *that specific task* will call. Don't pre-stage future tasks' needs.

```bash
# Example — three tasks, each declares only what it actually uses:
npx mcporter call aramb_tasks.create project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" tasks='[
  {"unique_id": 1, "name": "Plan the recap email",   "description": "Write the outline to .planning/recap.md", "assigned_agent": "developer",        "required_toolkits": []},
  {"unique_id": 2, "name": "Fetch last week mail",   "description": "Pull the 50 most recent Gmail threads.",   "assigned_agent": "developer",        "required_toolkits": ["GMAIL"], "dependencies": [1]},
  {"unique_id": 3, "name": "Write summary to Sheet", "description": "Drop the digest into a new Sheet.",        "assigned_agent": "developer",        "required_toolkits": ["GOOGLESHEETS","GOOGLEDRIVE"], "dependencies": [2]}
]'
```

## Update task status (use this for EACH task as you work)

```bash
npx mcporter call aramb_tasks.update project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="in_progress"
npx mcporter call aramb_tasks.update project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="done"
npx mcporter call aramb_tasks.update project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="failed" error="reason"
npx mcporter call aramb_tasks.update project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="blocked"
npx mcporter call aramb_tasks.update project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="review"
```

## update_me — close YOUR current task (with chip delivery)

If you were dispatched as a task agent and are closing YOUR own task, use `aramb_tasks.update_me`. Brahmi injects your task context from the dispatch session, so you don't pass `project_id` or `task_id`. Use this for the in-task close path; it carries `summary` + `artifacts` so the chip rides on the status close.

```bash
# In-task close with a file deliverable (chip + status + done in one call)
npx mcporter call aramb_tasks.update_me status="done" \
  summary="Top 5 stories compiled." \
  artifacts='[{"kind":"file","path":"/home/node/workspace/<YOUR_WD>/report.pdf"}]'

# In-task close with a URL deliverable
npx mcporter call aramb_tasks.update_me status="done" \
  summary="Frontend deployed." \
  artifacts='[{"kind":"url","url":"https://abc.proxy.clode.space","title":"Frontend","environment":"deployed"}]'

# Failed task close
npx mcporter call aramb_tasks.update_me status="failed" error="API quota exhausted"

# Progress note without a status change (append description progress section)
npx mcporter call aramb_tasks.update_me description="<full new description with ## Progress section>"
```

Rules for the `artifacts` payload on `update_me`:
- **`kind` is required** on every entry: `"file"` or `"url"`.
- **File paths must be absolute** under `/home/node/workspace/<YOUR_WD>/`. Relative paths are rejected; paths outside your wd are rejected with a corrective error.
- **URLs auto-register the preview state** — no separate `update_preview_url` call.
- **`summary`** is markdown shown to the user when the task closes (status=done|failed only). 32KB cap.

## Patch task metadata (any subset, no status change)

`status` on `aramb_tasks.update` is OPTIONAL. To patch metadata on a non-terminal task without transitioning status, omit `status` and pass any combination of:

- `description` — replace the full description (use to append `## Progress` bullets)
- `task_name` — rename
- `acceptance_criteria` — replace
- `assigned_agent` — reassign to a different existing agent
- `required_toolkits` — replace the slug list (`'[]'` to wipe)

```bash
# Add a missing toolkit a task needs
npx mcporter call aramb_tasks.update project_id="<PROJECT_ID>" task_id="<TASK_UUID>" required_toolkits='["GMAIL","SLACK"]'

# Refine the description after learning more from the user
npx mcporter call aramb_tasks.update project_id="<PROJECT_ID>" task_id="<TASK_UUID>" description="<full new description>"

# Reassign a task you realized belongs to a different agent
npx mcporter call aramb_tasks.update project_id="<PROJECT_ID>" task_id="<TASK_UUID>" assigned_agent="planner"

# Patch multiple fields at once + transition status in the same call
npx mcporter call aramb_tasks.update project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="in_progress" description="<new>" required_toolkits='["GMAIL"]'
```

Patches silently no-op on terminal (done / failed) tasks — that's history, don't rewrite it. Calling with neither `status` nor any patch field returns an error.

## List tasks

```bash
# Tasks assigned to you
npx mcporter call aramb_tasks.list_me project_id="<PROJECT_ID>"
npx mcporter call aramb_tasks.list_me project_id="<PROJECT_ID>" status="in_progress"

# All tasks in the project
npx mcporter call aramb_tasks.list project_id="<PROJECT_ID>"
```

## Testing/QA Verdict Protocol (CRITICAL)

Testing and QA tasks use a DIFFERENT completion protocol. They MUST always complete with `status="done"` and report test results via `outputs`:

```bash
# Tests PASS:
npx mcporter call aramb_tasks.update project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="done" outputs='{"verdict":"pass","summary":"All tests passed"}'

# Tests FAIL (found bugs — this is NOT a failure, the tester did its job):
npx mcporter call aramb_tasks.update project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="done" outputs='{"verdict":"fail","summary":"6 tests failed: cart API 404, product serialization error","details":"full details here"}'
```

**CRITICAL distinction:**
- `status="failed"` = the agent itself crashed (test runner broke, couldn't start docker, etc.)
- `verdict="fail"` inside outputs = the agent worked correctly and FOUND BUGS

When `verdict="fail"`, Brahmi automatically triggers a feedback loop:
1. Brahmi calls the master agent with the failure details
2. Master creates a corrective task for the right developer
3. After the fix, the test task re-runs automatically

**Never use `status="failed"` when tests find bugs.** Always use `status="done"` with `outputs={"verdict":"fail",...}` and your explicit `task_id`.

## Workflow

1. Create tasks (plan)
2. For each task: mark `in_progress` → do the work → mark `done`
3. Close with `aramb_tasks.update_me status="done" artifacts=[...]` so the chip rides on the status close

## Rules

- ALWAYS update task status as you work
- ALWAYS include `project_id` and `task_id` in `aramb_tasks.update` calls
- **ALWAYS include `application_id`** in `aramb_tasks.create` calls. Without it, tasks land on the wrong application.
- **Declare `required_toolkits` per task** when the task will call a Composio toolkit. Slugs only, honest list, empty when no third-party tools are needed.
- Save the `task_id` UUIDs returned from `create`.
- Valid statuses: `in_progress`, `validating`, `done`, `failed`, `blocked`, `review`.
