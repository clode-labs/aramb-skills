---
name: aramb-workflows
description: >
  MCP toolkit for workflows (aramb_workflows.*). Use these to create,
  read, update, schedule, and consolidate workflows, plus to update
  workflow run steps when dispatched as a workflow step agent.
---

# Aramb Workflows Toolkit

The `aramb_workflows.*` tools cover workflow definition CRUD, schedule management, run-step updates, and "consolidate from tasks" / "update from tasks" dispatch.

**Workflows are project-scoped (appless is the norm).** A workflow's identity is
its `lineage_id` (returned as `workflow_id`); `application_id` is **optional and
usually NULL**. There is no longer a "one workflow per application" invariant — a
project can hold many workflows, most of them appless. To find what workflows
exist, query **by project** (`list project_id=…`), not by application.

## CRITICAL: mcporter syntax rules
- ALL arguments MUST use `key="value"` format.
- Do NOT use `--output` — it is not supported by mcporter call.
- Workflow run step updates use `update_step` with an explicit `step_id` (rendered into your dispatch User Message). There is no session-implicit variant.

## Find a project's workflows — start here

To answer "what workflows exist / are there any workflows?" enumerate **by
project**:

```bash
npx mcporter call aramb_workflows.list project_id="<PROJECT_ID>"
```

Returns BOTH appless and app-bound workflows for the project — an array of:

```json
[{ "workflow_id": "<lineage_id>", "name": "...", "application_id": "<uuid|null>", "status": "...", "schedule": "<cron|null>", "updated_at": "..." }]
```

`aramb_workflows.get project_id="<PROJECT_ID>"` (no `workflow_id`) also returns
the project's workflows array — so your habitual `get` reach works project-scoped
too.

**Do NOT enumerate with `get application_id=…`.** That finds at most the single
legacy app-bound row for one application and misses every appless workflow — it
will answer "none" when the project actually has workflows. Use `list project_id=`
(or `get project_id=`) for any "which workflows are there?" question.

## Workflow CRUD

### Create a workflow (consolidated definition)

```bash
npx mcporter call aramb_workflows.create \
  application_id="<APPLICATION_ID>" \
  project_id="<PROJECT_ID>" \
  name="<workflow name>" \
  description="<workflow description>" \
  nodes='[
    {"unique_id":1,"name":"Fetch","prompt":"<...>","assigned_agent":"developer","acceptance_criteria":"<...>","required_toolkits":["GMAIL"]},
    {"unique_id":2,"name":"Process","prompt":"<...>","assigned_agent":"developer","acceptance_criteria":"<...>","required_toolkits":[]}
  ]' \
  edges='[{"source":1,"target":2}]'
```

- **`project_id` is required; `application_id` is optional/legacy.** Pass `project_id` alone to create a **project-scoped / appless** workflow — this is the norm. The workflow is keyed by its own lineage (`workflow_id`) and belongs to the project, not a channel-app.
- **`application_id` (optional, legacy app-bound)** — passing it binds the workflow to one application. App-bound workflows retain the old "at most one per application" behavior, so a second `create` with the same `application_id` fails (use `aramb_workflows.update` to modify it). Appless workflows have no such limit — a project can hold many.
- Per-user **system** workflows (e.g. the discovery report) are appless workflows in the user's **private project**. They deliver output via **DM** (chil `chat.send_dm`), never a public channel-app post. `get` / `update` by `workflow_id` work identically for appless workflows. (Template imports of system workflows arrive pre-created — polish them via the `import-workflow` skill, don't `create` them.)
- **Edges are top-level**, not per-node. Do NOT emit `dependencies` or `dependsOn` on nodes.
- **Never invent or bind hidden toolkits.** Set a node's `toolkit` / `required_toolkits` only to toolkits the workspace actually exposes. Platform-internal/hidden toolkits (`composio`, `composio_search`, `browser_tool`, `slackbot`, `discord`, `discordbot`, `microsoft_teams`) are REJECTED by `aramb_workflows.create`/`update` — never bind them. For Slack/Discord/Teams messaging deliverables, deliver via chil `chat.send_dm` (no toolkit).
- `template_slug` (optional) is forwarded verbatim from a dispatched `<template-import slug="...">` block when this call originates from template import.

### Fetch a workflow's definition

```bash
# By workflow_id (the canonical identity — lineage_id)
npx mcporter call aramb_workflows.get workflow_id="<WORKFLOW_ID>"

# By project_id (no workflow_id) — returns the project's workflows array
# (appless + app-bound). Use this to enumerate; see "Find a project's workflows".
npx mcporter call aramb_workflows.get project_id="<PROJECT_ID>"

# By application_id (legacy, app-bound only) — returns the single workflow bound
# to that one application, if any. Misses appless workflows — don't use it to
# answer "what workflows exist?".
npx mcporter call aramb_workflows.get application_id="<APPLICATION_ID>"
```

A single-workflow fetch returns nodes, edges, env_variables, schedule, stateful flag, and `auto_triggerable` / `missing_required_env` status.

### Update an existing workflow (atomic full replace)

```bash
npx mcporter call aramb_workflows.update \
  workflow_id="<WORKFLOW_ID>" \
  nodes='[<full new node set>]' \
  edges='[<full new edge set>]'
```

- The full new node+edge set is provided — no incremental edits.
- If the new entry node's `assigned_agent` differs from the previously recorded one, the stateful chain is reset (returned as `stateful_continuity="reset"` with a `stateful_reset_reason`).
- Optional fields: `name`, `description`, `env_variables` — omit to keep current.

## Consolidate from tasks (chat-driven)

When the user asks master in main chat to create / update / regenerate the workflow for their application, master does NOT design the workflow inline. Instead it spawns the appropriate system task and brahmi loops it back to master with the right skill (`create-workflow` or `update-workflow`) loaded.

```bash
# First-time create — application has no workflow yet
npx mcporter call aramb_workflows.create_from_tasks application_id="<APPLICATION_ID>" project_id="<PROJECT_ID>"

# Update an existing workflow — pulls fresh task corpus, regenerates the definition
npx mcporter call aramb_workflows.update_from_tasks workflow_id="<WORKFLOW_ID>"

# Update with an explicit change request (forwarded verbatim to the dispatched skill)
npx mcporter call aramb_workflows.update_from_tasks \
  workflow_id="<WORKFLOW_ID>" \
  change_request="add a Slack DM step after the standup comment"
```

Decide between them by checking the project's workflows first (`aramb_workflows.list project_id="..."`) — no workflow for this application yet → `create_from_tasks`; an existing one → `update_from_tasks` with its `workflow_id`.

Both tools return `{status: "ok", task_id: "<uuid>", message: "..."}`. The actual workflow design happens later when the system task arrives back at master and loads the appropriate skill.

## Schedule a workflow

### Set / update schedule
```bash
npx mcporter call aramb_workflows.set_schedule \
  workflow_id="<WORKFLOW_ID>" \
  cron_expression="0 9 * * 1" \
  cron_timezone="America/Los_Angeles" \
  enabled=true
```

- Master converts natural-language schedule phrases ("every Monday at 9am Pacific") into `cron_expression` + `cron_timezone` before calling.
- Pass `enabled=false` to disable without removing fields.
- Optional `env_overrides`: cron-specific env values that override workflow defaults at fire time.
- Always tell the user which timezone you picked.

### Read schedule
```bash
npx mcporter call aramb_workflows.get_schedule workflow_id="<WORKFLOW_ID>"
```

Returns `cron_expression`, `cron_timezone`, `enabled`, `env_overrides`, `next_run_at`, paused state, and env-readiness flags.

## Update a workflow run step (workflow dispatch only)

If you were dispatched as part of a workflow run (not an ad-hoc task), use `aramb_workflows.update_step` with the `step_id` rendered into your dispatch prompt (the "## Current Context" block, `Workflow Run Step ID:` line). The downstream step reads your `outputs.summary` and `outputs.files` as its preamble — so both fields are mandatory on `status="done"`.

```bash
# Save your IDs from the User Message once and reuse them.
PROJECT_ID="<your Project ID>"
STEP_ID="<your Workflow Run Step ID>"

# Success — outputs REQUIRED on done:
npx mcporter call aramb_workflows.update_step project_id="$PROJECT_ID" step_id="$STEP_ID" status="done" outputs='{"summary":"One-paragraph hand-off for the next agent (under 500 chars).","files":["relative/path/to/output.md","another/file.json"]}'

# Failure — error REQUIRED on failed:
npx mcporter call aramb_workflows.update_step project_id="$PROJECT_ID" step_id="$STEP_ID" status="failed" error="What blocked the step and any partial progress"

# In-progress (optional progress ping):
npx mcporter call aramb_workflows.update_step project_id="$PROJECT_ID" step_id="$STEP_ID" status="in_progress"
```

Rules for `update_step`:
- `outputs.summary` is one paragraph under 500 characters describing what the step produced, for the next agent. Focus on what's useful downstream, not how you did it.
- `outputs.files` is an array of paths RELATIVE to the workspace working directory. Paths only, no contents. Use `"files":[]` if you produced no files.
- Do NOT call `aramb_tasks.update` from within a workflow step session — it targets a different domain row (tasks, not workflow run steps) and the run will stall on the safety net.
- The runtime rejects cross-step writes (`context_drift`): the `step_id` you pass MUST match the one your run was dispatched against. Copy it verbatim from your User Message — don't re-use a stale UUID.

## Checker verdict on a workflow step (maker-checker gate)

When a workflow node has the maker-checker gate enabled, Brahmi runs the node's maker, then dispatches an independent **checker review** against the same step before the step advances. The review is the step's own assigned agent re-run in a fresh, read-only session under a gatekeeper system prompt — there is no separate checker persona. If your dispatch tells you to validate a workflow step (you'll get a gatekeeper system prompt, not the maker's execution prompt), **the STATUS you write IS the verdict** — there is no `verdict` field in `outputs` anymore. A DIRTY verdict's gaps travel in a top-level `feedback` arg, not in `outputs`.

**Report via `aramb_workflows.update_step` with the `step_id` from your dispatch User Message.** Your dispatch gives you the exact command (with the real `step_id`) under "Report your verdict" — run that. Pick exactly ONE:

```bash
# CLEAN — work has integrity; the step completes and children promote:
npx mcporter call aramb_workflows.update_step project_id="<PROJECT_ID>" step_id="<STEP_UUID>" status="done" outputs='{"audit":"clean","notes":"All criteria met."}'

# DIRTY, RETRY — gaps found and rounds remain; Brahmi re-runs the maker with these gaps:
npx mcporter call aramb_workflows.update_step project_id="<PROJECT_ID>" step_id="<STEP_UUID>" status="pending" feedback='{"round":1,"previous_gaps":[{"id":"gap_1","fixed":false}],"new_gaps":[{"description":"POST /users returns 500 on valid input","severity":"critical"}]}'

# DIRTY, EXHAUSTED — gaps found and this is the final round (or Brahmi rejects your retry as budget-exhausted):
npx mcporter call aramb_workflows.update_step project_id="<PROJECT_ID>" step_id="<STEP_UUID>" status="failed" error="3 rounds; integrity gaps remain: <list>"

# CAN'T AUDIT — environment broken (working dir or files missing). Steps have NO master-escalation path, so this closes failed:
npx mcporter call aramb_workflows.update_step project_id="<PROJECT_ID>" step_id="<STEP_UUID>" status="failed" error="cannot audit: <reason>"
```

Verdict rules (same as the task checker — see the `checker-prompt` skill):
- `status="done"` only when the work has integrity and no critical gap remains.
- `status="pending"` re-runs the maker with the unfixed gaps from `feedback` injected into its prompt (capped at the round count Brahmi shows you; past the cap, write `status="failed"`).
- `status="failed"` is the DIRTY-exhausted verdict AND the can't-validate fallback (missing working dir, etc.). For a workflow step, can't-audit also closes `failed` — there is no `needs_master_attention` for steps.
- In `feedback`, `previous_gaps` must report `fixed` for every gap id you were given; `new_gaps` omit `id` (Brahmi assigns stable ids).

## Rules

- ALWAYS use the top-level `edges` array on `create` / `update`. NEVER emit per-node `dependencies` / `dependsOn`.
- ALWAYS use `aramb_workflows.update_step` with the `step_id` rendered into your dispatch User Message — there is no session-implicit variant.
- ALWAYS close a workflow step before ending the session — without it the run stalls.
