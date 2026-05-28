---
name: aramb-tasks
description: >
  MCP toolkit for the task lifecycle (aramb_tasks.*). Use these to
  create, update, and list tasks. The task lifecycle is the team-mode
  primitive; this toolkit is hidden in solo mode by tools/list filtering.
---

# Aramb Tasks Toolkit

The `aramb_tasks.*` tools manage the task lifecycle. **You will only see these in team-mode chats** — in solo mode the toolkit is filtered out of `tools/list` and the agent runs without a task surface.

## Where the lifecycle contract lives

The **status lifecycle**, **escalation contract** (`retryable` /
`needs_master_attention` / `awaiting_user_input`), and **close mechanics**
(`outputs` shape, when to set `summary` / `artifacts`) are in the central
**TASK EXECUTOR** system prompt brahmi injects on every team-mode task
dispatch. This skill is the *syntax cookbook* for those calls — the
*semantic contract* is the TASK EXECUTOR prompt. Follow that.

## Not the same as Claude's built-in `TaskCreate`

`aramb_tasks.*` (this toolkit) and Claude's built-in `TaskCreate` / `TaskUpdate` / `TaskList` are two different systems that happen to share the word "task" — do not conflate them. `aramb_tasks.*` lives on the **brahmi MCP server**: each call writes a DB row that survives the session, is visible to other agents and the UI, and is how work is *delegated and persisted*. Claude's `TaskCreate` lives in the **LLM runtime**: it's an in-session scratchpad, gone when the run ends, visible only to you, and never reaches brahmi. Tracking your own progress → `TaskCreate`. Dispatching or persisting a real work unit → `aramb_tasks.*`. Calling `TaskCreate` dispatches nothing; calling `aramb_tasks.create` does not populate your in-session tracker.

## mcporter syntax rules

- ALL arguments MUST use `key="value"` format (NOT positional args).
- Status updates use `aramb_tasks.update` with an explicit `task_id`. There is `aramb_tasks.update_me` for the in-task self-update — pick the right one (see below).
- Your dispatch prompt contains your task's UUID. Save it the first time you see it and pass it on every `aramb_tasks.update` call.
- Correct: `npx mcporter call aramb_tasks.update project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="done"`
- WRONG: `npx mcporter call aramb_tasks.update <project_id> <task_id> done` (positional args not supported)

## Create tasks

```bash
npx mcporter call aramb_tasks.create project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" tasks='[{"unique_id": 1, "name": "Task name", "description": "Detailed description", "assigned_agent": "agent-name", "required_toolkits": ["GMAIL"]}]'
```

### Workspace subfolder convention

Build / clone / extend / deploy / test tasks MUST name the working subfolder
on line 1 of the description (`in \`<subfolder>/\``, `from \`<subfolder>/\``,
or `against \`<subfolder>/\``). The application working dir
(`/home/node/workspace/<app-slug>/`) is a **container** holding one or more
sibling subfolders — never the project itself. Sub-agents read the subfolder
name and `cd` into it before doing any work; without it they either guess
a slug or default-write at the root and clobber siblings.

- "Build a Snake game web app **in `snake-game/`**" ✅
- "Deploy the auth service **from `auth-service/`**" ✅
- "Test the checkout flow **in `storefront/`**" ✅
- "Build a Snake game web app" ❌ — sub-agent has to slugify; risks colliding with siblings

Tasks that are purely orchestrational (planning notes, scheduling, sending a
chat message) don't need a subfolder — only tasks that touch files on disk.

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

## update_me — close YOUR current task

For closing your OWN task, use `aramb_tasks.update_me`. Brahmi injects your task context from the dispatch session, so you don't pass `project_id` or `task_id`.

```bash
# In-task close with a file deliverable (chip + status + done in one call)
npx mcporter call aramb_tasks.update_me status="done" \
  summary="Top 5 stories compiled." \
  artifacts='[{"kind":"file","path":"/home/node/workspace/<YOUR_WD>/report.pdf"}]'

# In-task close with a URL deliverable
npx mcporter call aramb_tasks.update_me status="done" \
  summary="Frontend deployed." \
  artifacts='[{"kind":"url","url":"https://abc.proxy.clode.space","title":"Frontend","environment":"deployed"}]'

# Failed close — see TASK EXECUTOR for retryable=false vs default
npx mcporter call aramb_tasks.update_me status="failed" error="API quota exhausted" retryable=false

# Escalation paths (full contract in TASK EXECUTOR)
npx mcporter call aramb_tasks.update_me status="needs_master_attention" error="CORS bug only developer can fix"
npx mcporter call aramb_tasks.update_me status="awaiting_user_input"     # call aramb_chat.ask_question first

# Progress note without a status change (append description progress section)
npx mcporter call aramb_tasks.update_me description="<full new description with ## Progress section>"
```

Rules for the `artifacts` payload:
- **`kind` is required** on every entry: `"file"` or `"url"`.
- **File paths must be absolute** under `/home/node/workspace/<YOUR_WD>/`. Relative paths are rejected; paths outside your wd are rejected with a corrective error.
- **URLs auto-register the preview state** — no separate `update_preview_url` call.
- **`summary`** is markdown shown to the user when the task closes (status=done|failed only). 32KB cap.

## update — close ANOTHER task or patch metadata

`aramb_tasks.update` takes an explicit `task_id`. Use for cross-task ops (master closing a sub-agent's task, master patching another agent's task metadata, etc.):

```bash
npx mcporter call aramb_tasks.update project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="in_progress"
npx mcporter call aramb_tasks.update project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="done"
npx mcporter call aramb_tasks.update project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="failed" error="reason"
npx mcporter call aramb_tasks.update project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="blocked"
```

### Patch task metadata (any subset, no status change)

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

## Testing/QA verdict — the one gotcha

Testing tasks use `status="done"` with `outputs.verdict="pass"|"fail"`. **`status="failed"` is reserved for "the agent itself crashed"** (test runner broke, couldn't start docker). Finding bugs is a successful run — `done` with `verdict="fail"`:

```bash
# Tests pass
npx mcporter call aramb_tasks.update_me status="done" outputs='{"verdict":"pass","summary":"All tests passed"}'

# Tests fail — found bugs, agent did its job
npx mcporter call aramb_tasks.update_me status="done" outputs='{"verdict":"fail","summary":"6 tests failed","details":"full details here"}'
```

When `verdict="fail"`, brahmi triggers the feedback loop: master is called back, creates a corrective task for the right developer, and the test re-runs automatically.

## Rules

- ALWAYS include `project_id` and `task_id` on `aramb_tasks.update` (your dispatch prompt has them).
- **ALWAYS include `application_id`** on `aramb_tasks.create`. Without it, tasks land on the wrong application.
- **Declare `required_toolkits` per task** when the task will call a Composio toolkit. Slugs only, honest list, empty when no third-party tools are needed.
- Save the `task_id` UUIDs returned from `create`.
- Valid statuses: `in_progress`, `validating`, `done`, `failed`, `blocked`, `review`, `needs_master_attention`, `awaiting_user_input`.
