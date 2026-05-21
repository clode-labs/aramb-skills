---
name: brahmi
description: >
  Brahmi task orchestration. ALWAYS use these tools to create, manage, and execute
  tasks. NEVER skip task status updates.
---

# Brahmi Task Orchestration

You MUST use these tools to manage tasks. Create tasks first, then execute them with status updates.

## CRITICAL: mcporter Syntax Rules
- ALL arguments MUST use `key="value"` format (NOT positional args)
- Do NOT use `--output` flag — it is not supported by mcporter call
- Status updates use `update_task` with an explicit `task_id`. There is no `update_my_task` — do not call it.
- Your dispatch prompt contains your task's UUID. Save it the first time you see it and pass it on every `update_task` call.
- Correct: `npx mcporter call brahmi.update_task project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="done"`
- WRONG: `npx mcporter call brahmi.update_my_task status="done"` (this tool does not exist for you)
- WRONG: `npx mcporter call brahmi.update_task <project_id> <task_id> done` (positional args not supported)

## Commands

### Create tasks
```bash
npx mcporter call brahmi.create_tasks project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" tasks='[{"unique_id": 1, "name": "Task name", "description": "Detailed description", "assigned_agent": "agent-name", "required_toolkits": ["GMAIL"]}]'
```

#### required_toolkits — declare third-party tool needs upfront

When a task needs a Composio toolkit (Gmail, Google Sheets, Slack, Notion, GitHub, etc.) to do its work, **declare the slugs in `required_toolkits`** at create time. Brahmi stores the list on the task row, surfaces it to the executing agent in the dispatch prompt, and (eventually) checks the user has connected those toolkits before the agent starts work.

- **Slugs only**, uppercase, exactly as Composio reports them: `GMAIL`, `GOOGLESHEETS`, `GOOGLEDRIVE`, `SLACK`, `NOTION`, `LINEAR`, `GITHUB`, etc. Look them up via `composio toolkit list` if unsure.
- **Empty / omitted** when no third-party tools are needed (most coding tasks). Don't pad the list.
- **Per-task, not per-batch.** A planning task that just writes a plan file → no toolkits. A task that fetches Gmail messages and drops them into a Sheet → `["GMAIL","GOOGLESHEETS"]`.
- **Honest list.** Only what *that specific task* will call. Don't pre-stage future tasks' needs.

```bash
# Example — three tasks, each declares only what it actually uses:
npx mcporter call brahmi.create_tasks project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" tasks='[
  {"unique_id": 1, "name": "Plan the recap email",   "description": "Write the outline to .planning/recap.md", "assigned_agent": "developer",        "required_toolkits": []},
  {"unique_id": 2, "name": "Fetch last week mail",   "description": "Pull the 50 most recent Gmail threads.",   "assigned_agent": "developer",        "required_toolkits": ["GMAIL"], "dependencies": [1]},
  {"unique_id": 3, "name": "Write summary to Sheet", "description": "Drop the digest into a new Sheet.",        "assigned_agent": "developer",        "required_toolkits": ["GOOGLESHEETS","GOOGLEDRIVE"], "dependencies": [2]}
]'
```

### Update task status (use this for EACH task as you work)
```bash
npx mcporter call brahmi.update_task project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="in_progress"
npx mcporter call brahmi.update_task project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="done"
npx mcporter call brahmi.update_task project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="failed" error="reason"
npx mcporter call brahmi.update_task project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="blocked"
npx mcporter call brahmi.update_task project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="review"
```

### Patch task metadata (any subset, no status change)

`status` on `update_task` is OPTIONAL. To patch metadata on a non-terminal task without transitioning status, omit `status` and pass any combination of:

- `description` — replace the full description (use to append `## Progress` bullets)
- `task_name` — rename
- `acceptance_criteria` — replace
- `assigned_agent` — reassign to a different existing agent
- `required_toolkits` — replace the slug list (`'[]'` to wipe)

```bash
# Add a missing toolkit a task needs
npx mcporter call brahmi.update_task project_id="<PROJECT_ID>" task_id="<TASK_UUID>" required_toolkits='["GMAIL","SLACK"]'

# Refine the description after learning more from the user
npx mcporter call brahmi.update_task project_id="<PROJECT_ID>" task_id="<TASK_UUID>" description="<full new description>"

# Reassign a task you realized belongs to a different agent
npx mcporter call brahmi.update_task project_id="<PROJECT_ID>" task_id="<TASK_UUID>" assigned_agent="planner"

# Patch multiple fields at once + transition status in the same call
npx mcporter call brahmi.update_task project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="in_progress" description="<new>" required_toolkits='["GMAIL"]'
```

Patches silently no-op on terminal (done / failed) tasks — that's history, don't rewrite it. Calling with neither `status` nor any patch field returns an error.

### Update a workflow run step (workflow dispatch only)
If you were dispatched as part of a workflow run (not an ad-hoc task), use
`update_my_workflow_step` INSTEAD OF `update_task`. Brahmi injects your
step context from the dispatch session, so you don't pass `project_id`
or `step_id`. The downstream step reads your `outputs.summary` and
`outputs.files` as its preamble — so both fields are mandatory on
`status="done"`.

```bash
# Success — outputs REQUIRED on done:
npx mcporter call brahmi.update_my_workflow_step status="done" outputs='{"summary":"One-paragraph hand-off for the next agent (under 500 chars).","files":["relative/path/to/output.md","another/file.json"]}'

# Failure — error REQUIRED on failed:
npx mcporter call brahmi.update_my_workflow_step status="failed" error="What blocked the step and any partial progress"

# In-progress (optional progress ping):
npx mcporter call brahmi.update_my_workflow_step status="in_progress"
```

Rules for `update_my_workflow_step`:
- `outputs.summary` is one paragraph under 500 characters describing what the step produced, for the next agent. Focus on what's useful downstream, not how you did it.
- `outputs.files` is an array of paths RELATIVE to the workspace working directory. Paths only, no contents. Use `files:[]` if you produced no files.
- Do NOT call `update_task` from within a workflow step session — it won't resolve your step context and the run will stall on the safety net.
- `update_workflow_step step_id="<UUID>" status="..."` is the explicit-id form. Only use it if you need to update a DIFFERENT step from the one you're executing (rare — mostly for the master safety net).

### Spawn a workflow create / update from chat (master only)

When a user asks master in main chat to create / update / regenerate the workflow for their application, master does NOT design the workflow inline. Instead it spawns the appropriate system task and brahmi loops it back to master with the right skill (`create-workflow` or `update-workflow`) loaded. Two thin tools wrap the existing FE-button flow:

```bash
# First-time create — application has no workflow yet
npx mcporter call brahmi.consolidate_workflow application_id="<APPLICATION_ID>" project_id="<PROJECT_ID>"

# Update an existing workflow — pulls fresh task corpus, regenerates the definition
npx mcporter call brahmi.reconsolidate_workflow workflow_id="<WORKFLOW_ID>"
```

Decide between them by checking `brahmi.get_workflow application_id="..."` first — empty result → consolidate; existing row → reconsolidate. See the master-agent identity routing rules (`workspace-master/AGENTS.md`) for the full intent-detection flow.

Both tools return `{status: "ok", task_id: "<uuid>", message: "..."}`. The actual workflow design happens later, when the system task arrives back at master and loads the appropriate skill — these tools just kick the dispatch.

### Get tasks assigned to you
```bash
npx mcporter call brahmi.get_my_tasks project_id="<PROJECT_ID>"
npx mcporter call brahmi.get_my_tasks project_id="<PROJECT_ID>" status="in_progress"
```

### List all tasks
```bash
npx mcporter call brahmi.list_tasks project_id="<PROJECT_ID>"
```

### Send a plain-text message (progress pings)

`brahmi.send_message` posts a plain text row to chat. Primary use: sub-agents pinging the user's MAIN chat from inside a task chat (your reply text lands in the task chat; `send_message chat_location="main"` is your only handle on main chat). Fire it BEFORE/DURING the work — for "🔨 Starting", "⚙️ Build passing", "🧪 Tests running", etc.

```bash
npx mcporter call brahmi.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="🔨 Starting: <task>" chat_location="main"
npx mcporter call brahmi.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="⚙️ Build passing, deploying now" chat_location="main"
```

Rules:
- `chat_location="main"` to reach the user's main chat (the typical sub-agent → main use case).
- `chat_location="task"` (or omit) for the current task chat.
- **NEVER** use `send_message` to ask questions — use `ask_question` instead, which blocks the run until the user answers and returns a structured response.
- **NEVER** call `send_message` right after closing a task with `update_my_task` (status=done|failed) that already carried `artifacts` or `summary`. The close already emits the chip-bearing chat row; a trailing send_message duplicates it. send_message is for BEFORE/DURING the work, not after the close.
- For DELIVERABLES (files, URLs), use `update_my_task.artifacts` (in-task close) or `deliver_artifacts` (outside a task) — NOT this tool.

### Deliver artifacts (files & URLs)

Every user-facing deliverable (file you wrote, URL you exposed) MUST be surfaced as a chip. Two surfaces, same `artifacts` payload shape:

- **In a task (team mode)**: pass `artifacts` on your `update_my_task` close call. The chip rides on the status close — same payload, single MCP call.
- **Outside a task (solo, mid-task recall, master direct response)**: call `brahmi.deliver_artifacts` with the same `artifacts` payload.

```bash
# In-task close with a file deliverable (chip + status + done in one call)
npx mcporter call brahmi.update_my_task status="done" \
  summary="Top 5 stories compiled." \
  artifacts='[{"kind":"file","path":"/home/node/workspace/<YOUR_WD>/report.pdf"}]'

# In-task close with a URL deliverable
npx mcporter call brahmi.update_my_task status="done" \
  summary="Frontend deployed." \
  artifacts='[{"kind":"url","url":"https://abc.proxy.clode.space","title":"Frontend","environment":"deployed"}]'

# Solo / mid-task recall — file
npx mcporter call brahmi.deliver_artifacts artifacts='[{"kind":"file","path":"/home/node/workspace/<YOUR_WD>/report.pdf"}]'

# Solo / mid-task recall — URL
npx mcporter call brahmi.deliver_artifacts artifacts='[{"kind":"url","url":"https://abc.proxy.clode.space","title":"Frontend"}]'

# Failed task close (no chip needed — but allowed if you have partial outputs)
npx mcporter call brahmi.update_my_task status="failed" error="API quota exhausted"
```

Rules for the `artifacts` payload (same in both tools):
- **`kind` is required** on every entry: `"file"` or `"url"`. No inference.
- **File paths must be absolute** under `/home/node/workspace/<YOUR_WD>/`. Your working directory is in the `## MANDATORY Working Directory` block of your system prompt. Relative paths are rejected; paths outside your wd are rejected with a corrective error.
- **URLs auto-register the preview state** — you do NOT need a separate `update_preview_url` call.
- **`summary`** is optional markdown commentary that accompanies the chip in the chat row.
- **`chat_location`** on `deliver_artifacts` defaults to `"main"`. Override with `"task"` only if you have a task context and explicitly want the chip in the task chat instead of the main chat.

### Ask user a question
```bash
# Free-form question (user types a custom answer)
npx mcporter call brahmi.ask_question project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" question="Your question?"

# Question with predefined options (user picks one or types a custom answer)
npx mcporter call brahmi.ask_question project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" question="Your question?" options='["Option A", "Option B", "Option C"]'
```
- **Use for**: any time you need input from the user before proceeding — requirement gathering, clarifications, preference choices.
- **Blocking**: the task is automatically paused and re-queued only after the user answers. You do NOT need to poll or loop.
- **Returns**: `{"question_id": "<UUID>", "answer": "<user text or selected option>"}` — use the answer to continue.
- **During planning**: ALWAYS use `ask_question` to collect requirements. Provide `options` when the choices are well-defined (tech stack, auth method, feature tier, etc.). This produces a single `message_type=question` row with structured `options`/`selected_option` fields.

## Git Integration

### List linked repositories
```bash
npx mcporter call brahmi.list_linked_repos application_id="<APPLICATION_ID>"
```

### Clone a linked repository
```bash
npx mcporter call brahmi.clone_repo application_id="<APPLICATION_ID>" repo_slug="org/repo"
```
Returns an authenticated clone URL with an embedded access token. Use it with `git clone`:
```bash
git clone <returned_clone_url> <returned_clone_path>
```

### Get a fresh git token (for push/pull)
```bash
npx mcporter call brahmi.git_token application_id="<APPLICATION_ID>" repo_slug="org/repo"
```
Returns a repo-scoped token valid for 1 hour. Use it to update the remote URL before push/pull:
```bash
git remote set-url origin <returned_clone_url>
git push -u origin <branch>
```

## Planning (master agent)

### Planning workflow order
1. **Gather requirements** — use `ask_question` to collect everything you need before writing the plan. Ask one question at a time. Use `options` for well-defined choices.
2. **Start planning mode** — call `start_planning`, then write the plan to the file.
3. **Submit plan** — call `submit_plan` for user approval.
4. **Finish planning** — call `finish_planning` after the user approves, then create tasks.

### Step 1 — Gather requirements with ask_question
```bash
# Ask one question at a time, wait for the answer, then ask the next
npx mcporter call brahmi.ask_question project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" question="What tech stack do you prefer?" options='["React + Node.js", "Next.js fullstack", "Surprise me"]'
npx mcporter call brahmi.ask_question project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" question="Which auth method?" options='["JWT tokens", "JWT + httpOnly cookies", "Sessions"]'
```
Keep questions focused — 2-4 max. Only ask what you cannot reasonably infer.

### Step 2 — Start planning mode
```bash
npx mcporter call brahmi.start_planning project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" file_path=".planning/<descriptive-name>.md"
```

### Step 3 — Submit structured plan for user approval
```bash
npx mcporter call brahmi.submit_plan project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" summary="one-line summary" approach="technical approach" agents='[{"name":"agent-name","role":"role"}]' tasks='[{"unique_id":1,"name":"task","description":"desc","assigned_agent":"agent","dependencies":[]}]' key_decisions='[{"decision":"what","rationale":"why"}]'
```

### Step 4 — Finish planning (after user approves)
```bash
npx mcporter call brahmi.finish_planning project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>"
```

## Preview URLs (local-deployer)

After a deployment exposes a URL, surface it as a URL-kind artifact via `deliver_artifacts`. Brahmi auto-records the preview-URL state from that call — there is no separate `update_preview_url` step.

```bash
npx mcporter call brahmi.deliver_artifacts artifacts='[{"kind":"url","url":"https://abc.proxy.clode.space","title":"Frontend","environment":"local"}]'
```

## Testing/QA Verdict Protocol (CRITICAL)

Testing and QA tasks use a DIFFERENT completion protocol. They MUST always complete with `status="done"` and report test results via `outputs`:

```bash
# Tests PASS:
npx mcporter call brahmi.update_task project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="done" outputs='{"verdict":"pass","summary":"All tests passed"}'

# Tests FAIL (found bugs — this is NOT a failure, the tester did its job):
npx mcporter call brahmi.update_task project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="done" outputs='{"verdict":"fail","summary":"6 tests failed: cart API 404, product serialization error","details":"full details here"}'
```

**CRITICAL distinction:**
- `status="failed"` = the agent itself crashed (test runner broke, couldn't start docker, etc.)
- `verdict="fail"` inside outputs = the agent worked correctly and FOUND BUGS

When `verdict="fail"`, Brahmi automatically triggers a feedback loop:
1. Brahmi calls the master agent with the failure details
2. Master creates a corrective task for the right developer
3. After the fix, the test task re-runs automatically

**Never use `status="failed"` when tests find bugs.** Always use `status="done"` with `outputs={"verdict":"fail",...}` and your explicit `task_id`.

## Progress visibility

Sub-agents are dispatched into a task chat; their reply text lands there, not in the user's main chat. To keep the user informed during long-running work, ping main chat explicitly:

- **Task start / mid-flight milestones** → `send_message chat_location="main"` with a short status line ("🔨 Starting: ...", "⚙️ Build passing, deploying now", "🧪 Running tests").
- **A task is closing with a deliverable** → `update_my_task status="done" artifacts=[...] summary="..."` — chip rides on the status close. Do NOT also send_message after this; the close already emits the row.
- **A task is closing with no deliverable** → `update_my_task status="done|failed"` (status-only).
- **A deliverable outside a task** (solo, mid-task recall) → `deliver_artifacts` with the same `artifacts` payload shape.
- **You need input** → `ask_question` (NOT send_message — ask_question blocks the run until the user answers).
- **An out-of-band alert** the user needs to see now → `alert_user`.

## Workflow
1. Create tasks (plan)
2. For each task: mark in_progress -> do the work -> mark done
3. Send completion message

## Rules
- ALWAYS update task status as you work
- ALWAYS include project_id and task_id in update_task calls
- **ALWAYS include application_id** in create_tasks, ask_question, start_planning, submit_plan, and finish_planning calls. The agent is deployed per-project and serves multiple applications — without application_id, messages go to the wrong app. This is NOT optional.
- **Declare `required_toolkits` per task** when the task will call a Composio toolkit (Gmail, Sheets, Slack, etc.). Slugs only, honest list, empty when no third-party tools are needed.
- Save the task_id UUIDs returned from create_tasks
- Valid statuses: in_progress, validating, done, failed, blocked, review
