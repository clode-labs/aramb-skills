---
name: aramb-chat
description: >
  MCP toolkit for the chat surface (aramb_chat.*). Use these to send
  messages, ask the user questions, alert them, surface artifacts
  (files & URLs) outside a task, work with linked GitHub repos, drive
  the planning flow, and read the current chat's mode (solo vs team).
---

# Aramb Chat Toolkit

The `aramb_chat.*` tools cover everything the agent says or shows to the user **outside the task lifecycle**: progress pings, questions, alerts, artifact delivery, repo access, planning, and mode introspection.

## CRITICAL: mcporter syntax rules
- ALL arguments MUST use `key="value"` format (NOT positional args).
- Do NOT use `--output` — it is not supported by mcporter call.
- **ALWAYS include `application_id`** in `ask_question`, `start_planning`, `submit_plan`, `finish_planning`, and `get_mode`. The agent is deployed per-project and serves multiple applications — without it, messages go to the wrong app.

## Send a plain-text message (progress pings)

`aramb_chat.send_message` posts a plain text row to chat. Primary use: sub-agents pinging the user's MAIN chat from inside a task chat (your reply text lands in the task chat; `send_message chat_location="main"` is your only handle on main chat). Fire it BEFORE/DURING the work — for "🔨 Starting", "⚙️ Build passing", "🧪 Tests running", etc.

```bash
npx mcporter call aramb_chat.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="🔨 Starting: <task>" chat_location="main"
npx mcporter call aramb_chat.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="⚙️ Build passing, deploying now" chat_location="main"
```

Rules:
- `chat_location="main"` to reach the user's main chat (the typical sub-agent → main use case).
- `chat_location="task"` (or omit) for the current task chat.
- **NEVER** use `send_message` to ask questions — use `ask_question` instead.
- **NEVER** call `send_message` right after closing a task with `aramb_tasks.update` (status=done|failed) that carried `artifacts` or `summary`. The close already emits the chip-bearing chat row.
- For DELIVERABLES (files, URLs), use `aramb_tasks.update.artifacts` (in-task close) or `aramb_chat.deliver_artifacts` (outside a task) — NOT this tool.

## Ask the user a question (blocking)

> **CRITICAL — never use the built-in/native `AskUserQuestion` popup.** It renders
> ONLY in the web UI and never reaches Slack (or any chat surface), so a Slack user
> sees nothing and the run blocks forever on an answer they cannot give. ALWAYS ask
> via `aramb_chat.ask_question` below — it routes to the user's actual surface
> (Slack thread → interactive buttons, or web) and resumes the turn on their answer.

```bash
# Free-form question (user types a custom answer)
npx mcporter call aramb_chat.ask_question project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" question="Your question?"

# Question with predefined options (user picks one or types a custom answer)
npx mcporter call aramb_chat.ask_question project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" question="Your question?" options='["Option A", "Option B", "Option C"]'
```

- **Use for**: any time you need input from the user — requirement gathering, clarifications, preference choices.
- **Blocking**: the task is automatically paused and re-queued only after the user answers. You do NOT need to poll or loop.
- **Returns**: `{"question_id": "<UUID>", "answer": "<user text or selected option>"}`.

## Send an alert (out-of-band)

```bash
npx mcporter call aramb_chat.alert_user project_id="<PROJECT_ID>" title="Quota exceeded" details="<full context + recommended action>"
```

Use when automated resolution has failed and human intervention is required.

## Deliver artifacts (files & URLs) — out-of-task surface

Every user-facing deliverable (file you wrote, URL you exposed) MUST be surfaced as a chip. Two surfaces, same `artifacts` payload shape:

- **In a task (team mode)**: pass `artifacts` on your `aramb_tasks.update` close call (with the explicit `task_id` from your User Message). See the `aramb-tasks` skill for that path.
- **Outside a task (solo, mid-task recall, master direct response)**: call `aramb_chat.deliver_artifacts` with the same `artifacts` payload.

```bash
# Solo / mid-task recall — file. project_id + application_id are REQUIRED
# (copy from your User Message's "## Current Context" block) — the URL-kind
# preview-URL side-effect lands on application_id, so a wrong/missing id
# silently mutates the wrong app. The platform rejects calls without it.
npx mcporter call aramb_chat.deliver_artifacts \
  project_id="<PROJECT_ID>" \
  application_id="<APPLICATION_ID>" \
  artifacts='[{"kind":"file","path":"/home/node/workspace/<YOUR_WD>/report.pdf"}]'

# Solo / mid-task recall — URL
npx mcporter call aramb_chat.deliver_artifacts \
  project_id="<PROJECT_ID>" \
  application_id="<APPLICATION_ID>" \
  artifacts='[{"kind":"url","url":"https://abc.proxy.clode.space","title":"Frontend"}]'

# Solo / mid-task recall — blob (downloadable file delivery; same path
# as kind=file, but the result is a download URL that works on any
# surface — web chat, Slack, exports). Use when the user is reading from
# somewhere other than the workspace tab.
npx mcporter call aramb_chat.deliver_artifacts \
  project_id="<PROJECT_ID>" \
  application_id="<APPLICATION_ID>" \
  artifacts='[{"kind":"blob","path":"/home/node/workspace/<YOUR_WD>/report.pdf","name":"report.pdf","mime_hint":"application/pdf"}]'
```

Rules for the `artifacts` payload (same in both surfaces):
- **`kind` is required** on every entry: `"file"`, `"url"`, or `"blob"`. No inference.
- **`"blob"`** mirrors `"file"` (same `path` argument, same wd rules) but the platform stages the bytes so consumers fetch a public download URL — pick it whenever the deliverable needs to reach a non-web surface (Slack, email, share link). `name` and `mime_hint` are optional but encouraged.
- **File paths must be absolute** under `/home/node/workspace/<YOUR_WD>/`. Your working directory is in the `## MANDATORY Working Directory` block of your system prompt. Relative paths are rejected; paths outside your wd are rejected with a corrective error.
- **URLs auto-register the preview state** — there is no separate `update_preview_url` step. The URL chip IS the preview registration.
- **`summary`** is optional markdown commentary that accompanies the chip in the chat row.
- **`chat_location`** on `deliver_artifacts` defaults to `"main"`. Override with `"task"` only if you have a task context and want the chip in the task chat instead.

## Git integration

GitHub is NOT on `aramb_chat`. All git work goes through the `aramb-toolkits`
skill: call `aramb_toolkits.execute` `{tool:"GITHUB_GET_GIT_CREDENTIAL"}` to mint
a token (under `result`), export it as `GH_TOKEN`, then use native `git` / `gh`
CLI for everything. If the user has no github connection in scope, call
`aramb_toolkits.connect toolkit="github"` and share the returned `redirect_url`.

See the `aramb-toolkits` skill for the full workflow.

## Planning (master agent)

### Planning workflow order
1. **Gather requirements** — use `ask_question` to collect everything you need before writing the plan. Ask one question at a time. Use `options` for well-defined choices.
2. **Start planning mode** — call `start_planning`, then write the plan to the file.
3. **Submit plan** — call `submit_plan` for user approval.
4. **Finish planning** — call `finish_planning` after the user approves. In team mode, follow up by creating tasks via `aramb_tasks.create`; in solo mode, just start executing.

### Step 1 — Gather requirements with ask_question
```bash
# Ask one question at a time, wait for the answer, then ask the next
npx mcporter call aramb_chat.ask_question project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" question="What tech stack do you prefer?" options='["React + Node.js", "Next.js fullstack", "Surprise me"]'
npx mcporter call aramb_chat.ask_question project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" question="Which auth method?" options='["JWT tokens", "JWT + httpOnly cookies", "Sessions"]'
```
Keep questions focused — 2-4 max. Only ask what you cannot reasonably infer.

### Step 2 — Start planning mode
```bash
npx mcporter call aramb_chat.start_planning project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" file_path=".planning/<descriptive-name>.md"
```

### Step 3 — Submit structured plan for user approval

The plan is **mode-agnostic** — it carries the user-visible decision summary only. Task creation (team mode) happens AFTER approval, in the post-approval skill, NOT in this call.

```bash
npx mcporter call aramb_chat.submit_plan project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" summary="one-line summary" approach="technical approach" key_decisions='[{"decision":"what","rationale":"why"}]'
```

### Step 4 — Finish planning (after user approves)
```bash
npx mcporter call aramb_chat.finish_planning project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>"
```

After this call:
- **Team mode**: use `aramb_tasks.create` to spawn the task list the plan implies.
- **Solo mode**: just start executing — no task surface available.

If you have access to chat-toolkit tools either way and need to branch, use `get_mode` (next section).

## Read the chat mode (solo vs team)

`aramb_chat.get_mode` returns `{"mode":"solo"}` or `{"mode":"team"}` for the application. Useful when the same skill is invoked in both modes and the post-approval branch differs.

```bash
npx mcporter call aramb_chat.get_mode application_id="<APPLICATION_ID>"
```

- **Use sparingly.** Most skills are assigned per-persona (solo persona vs team personas) and don't see both surfaces. Reach for `get_mode` only when a single skill must branch.
- **Returned shape**: `{"mode":"solo"}` or `{"mode":"team"}`. Lowercase, exactly.

## Progress visibility

Sub-agents dispatched into a task chat have their reply text land there, not in the user's main chat. To keep the user informed during long-running work:

- **Task start / mid-flight milestones** → `aramb_chat.send_message chat_location="main"` with a short status line ("🔨 Starting: ...", "⚙️ Build passing, deploying now", "🧪 Running tests").
- **A task is closing with a deliverable** → `aramb_tasks.update project_id="$PROJECT_ID" task_id="$TASK_ID" status="done" artifacts=[...] summary="..."`. Do NOT also `send_message` after this.
- **A deliverable outside a task** → `aramb_chat.deliver_artifacts` with the same `artifacts` payload shape.
- **You need input** → `aramb_chat.ask_question` (NOT `send_message` — `ask_question` blocks the run until the user answers).
- **An out-of-band alert** → `aramb_chat.alert_user`.
