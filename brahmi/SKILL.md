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
- Prefer `update_my_task` over `update_task` — it requires fewer arguments and automatically knows your context
- Correct: `npx mcporter call brahmi.update_my_task status="done"`
- WRONG: `npx mcporter call brahmi.update_task <project_id> <task_id> done`

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

### Update your own task (agent context)
```bash
npx mcporter call brahmi.update_my_task status="in_progress"
npx mcporter call brahmi.update_my_task status="done"
npx mcporter call brahmi.update_my_task status="failed" error="reason"
```

### Update a workflow run step (workflow dispatch only)
If you were dispatched as part of a workflow run (not an ad-hoc task), use
`update_my_workflow_step` INSTEAD OF `update_my_task` / `update_task`. Brahmi
injects your step context from the dispatch session, so you don't pass
`project_id` or `step_id`. The downstream step reads your `outputs.summary`
and `outputs.files` as its preamble — so both fields are mandatory on
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
- Do NOT call `update_task` or `update_my_task` from within a workflow step session — they won't resolve your step context and the run will stall on the safety net.
- `update_workflow_step step_id="<UUID>" status="..."` is the explicit-id form. Only use it if you need to update a DIFFERENT step from the one you're executing (rare — mostly for the master safety net).

### Get tasks assigned to you
```bash
npx mcporter call brahmi.get_my_tasks project_id="<PROJECT_ID>"
npx mcporter call brahmi.get_my_tasks project_id="<PROJECT_ID>" status="in_progress"
```

### List all tasks
```bash
npx mcporter call brahmi.list_tasks project_id="<PROJECT_ID>"
```

### Send message to user
```bash
npx mcporter call brahmi.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="Message text"
npx mcporter call brahmi.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="Message text" chat_location="main"
```
- `chat_location`: `"main"` sends to the user's main chat, `"task"` sends to your current task chat. Default: auto (task chat if you are in a task context, main otherwise).
- **Use for**: one-way notifications only — progress updates, status reports, task started/done/failed announcements.
- **NEVER use** `send_message` to ask questions or gather input. Use `ask_question` instead. Using `send_message` for questions causes duplicate messages because the adapter saves your `finalText` on run completion in addition to the explicit tool call write — two rows, same content.

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
- **During planning**: ALWAYS use `ask_question` (not `send_message`) to collect requirements. Provide `options` when the choices are well-defined (tech stack, auth method, feature tier, etc.). This produces a single `message_type=question` row with structured `options`/`selected_option` fields — no duplicates.

#### send_message vs ask_question — when to use which

| | `send_message` | `ask_question` |
|---|---|---|
| Purpose | One-way notification | Gather user input |
| Awaits reply | No | Yes — task pauses until answered |
| DB `message_type` | `text` | `question` |
| Causes duplicate messages | Yes, if used for questions | No |
| Use during planning | Progress/status only | Requirement gathering |
| Supports options | No | Yes (`options` array) |

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
1. **Gather requirements** — use `ask_question` (NOT `send_message`) to collect everything you need before writing the plan. Ask one question at a time. Use `options` for well-defined choices.
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

### Update preview URLs after deployment
```bash
npx mcporter call brahmi.update_preview_url application_id="<APPLICATION_ID>" preview_url='{"frontend":"https://abc.proxy.clode.space"}'
```

## Testing/QA Verdict Protocol (CRITICAL)

Testing and QA tasks use a DIFFERENT completion protocol. They MUST always complete with `status="done"` and report test results via `outputs`:

```bash
# Tests PASS:
npx mcporter call brahmi.update_my_task status="done" outputs='{"verdict":"pass","summary":"All tests passed"}'

# Tests FAIL (found bugs — this is NOT a failure, the tester did its job):
npx mcporter call brahmi.update_my_task status="done" outputs='{"verdict":"fail","summary":"6 tests failed: cart API 404, product serialization error","details":"full details here"}'
```

**CRITICAL distinction:**
- `status="failed"` = the agent itself crashed (test runner broke, couldn't start docker, etc.)
- `verdict="fail"` inside outputs = the agent worked correctly and FOUND BUGS

When `verdict="fail"`, Brahmi automatically triggers a feedback loop:
1. Brahmi calls the master agent with the failure details
2. Master creates a corrective task for the right developer
3. After the fix, the test task re-runs automatically

**Never use `status="failed"` when tests find bugs.** Always use `status="done"` with `outputs={"verdict":"fail",...}`.

## Progress Reporting (MANDATORY)

You MUST report progress to BOTH the task chat AND the main chat. The user watches the main chat — if you only send to the task chat, they have no visibility into what is happening.

### When to report to main chat
Send short progress summaries to the main chat at these moments:
1. **Task started**: `npx mcporter call brahmi.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="🔨 Starting: <task name>" chat_location="main"`
2. **Important milestones**: `npx mcporter call brahmi.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="✅ <task name>: <milestone>" chat_location="main"`
3. **Task completed**: `npx mcporter call brahmi.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="✅ Done: <task name> — <one-line summary>" chat_location="main"`
4. **Task failed/blocked**: `npx mcporter call brahmi.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="❌ <task name>: <what went wrong>" chat_location="main"`

### Rules
- Main chat messages: SHORT (1-2 sentences max). No code blocks, no long explanations.
- Task chat messages: detailed — include code snippets, error logs, reasoning.
- Default `send_message` (no `chat_location`) goes to your task chat automatically.
- Always use `chat_location="main"` explicitly when reporting to the main chat.

## Workflow
1. Create tasks (plan)
2. For each task: mark in_progress -> do the work -> mark done
3. Send completion message

## Rules
- ALWAYS update task status as you work
- ALWAYS include project_id and task_id in update_task calls
- **ALWAYS include application_id** in create_tasks, send_message, ask_question, start_planning, submit_plan, and finish_planning calls. The agent is deployed per-project and serves multiple applications — without application_id, messages go to the wrong app. This is NOT optional.
- **Declare `required_toolkits` per task** when the task will call a Composio toolkit (Gmail, Sheets, Slack, etc.). Slugs only, honest list, empty when no third-party tools are needed.
- Save the task_id UUIDs returned from create_tasks
- Valid statuses: in_progress, validating, done, failed, blocked, review
