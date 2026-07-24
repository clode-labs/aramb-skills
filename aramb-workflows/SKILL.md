---
name: aramb-workflows
description: >
  MCP toolkit for workflows (aramb_workflows.*). Use these to create,
  read, update, schedule, and consolidate workflows, plus to update
  workflow run steps when dispatched as a workflow step agent.
---

# Aramb Workflows Toolkit

The `aramb_workflows.*` tools cover workflow definition CRUD, schedule management, manual run (`aramb_workflows.run` — confirm-first), run-step updates, and "consolidate from tasks" / "update from tasks" dispatch.

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

Returns BOTH appless and app-bound workflows for the project, wrapped as
`{ "workflows": [ … ], "count": N }`. Read the `workflows` array — `count: 0`
(empty array) means genuinely no workflows. Each row:

```json
{ "workflow_id": "<lineage_id>", "name": "...", "application_id": "<uuid|null>", "status": "...", "schedule": null, "callback_url": null, "updated_at": "..." }
```

`schedule` is `null` unless a cron is configured, in which case it is an object
`{ "cron_expression": "...", "cron_timezone": "...", "enabled": true, "next_run_at": "...", "random_delay_enabled": false, "random_delay_max_minutes": null }`.

`callback_url` is `null` unless a run-status webhook is set (see "Run status
callbacks" below). The signing secret is **never** returned here — only once, when
the callback is first set.

`aramb_workflows.get project_id="<PROJECT_ID>"` (no `workflow_id`) returns the
same `{ "workflows": [ … ], "count": N }` shape — so your habitual `get` reach
works project-scoped too.

**Do NOT enumerate with `get application_id=…`.** That finds at most the single
legacy app-bound row for one application and misses every appless workflow — it
will answer "none" when the project actually has workflows. Use `list project_id=`
(or `get project_id=`) for any "which workflows are there?" question.

## Workflow CRUD

### Create a workflow (consolidated definition)

```bash
npx mcporter call aramb_workflows.create \
  agent_id="<AGENT_ID>" \
  project_id="<PROJECT_ID>" \
  name="<workflow name>" \
  description="<workflow description>" \
  nodes='[
    {"unique_id":1,"name":"Fetch","prompt":"<...>","assigned_agent":"developer","acceptance_criteria":"<...>","required_toolkits":["GMAIL"]},
    {"unique_id":2,"name":"Process","prompt":"<...>","assigned_agent":"developer","acceptance_criteria":"<...>","required_toolkits":[]}
  ]' \
  edges='[{"source":1,"target":2}]'
```

- **Workflows are standalone by default; `agent_id` is an OPTIONAL binding — not a requirement.** A workflow exists in its own right (project-scoped or app-bound) exactly as it always has — creating one without `agent_id` is fully supported and is the right thing when the workflow isn't tied to a specific agent. Passing `agent_id="<agent>"` on `create` is an **additive** binding: that one call creates the workflow AND stamps the ownership edge (create-and-link in one step), after which the workflow is filed under the agent and discoverable + runnable **by that agent**. The binding constrains the *bound* workflow (one owning agent); it does NOT demote or replace standalone workflows.
  - **When you are building a workflow FOR an agent (the Architect flow), prefer binding** — pass `agent_id` so it's owned and discoverable by the agent you're building. Otherwise, omit it and create a plain standalone workflow.
  - To bind a workflow that already exists to an agent, use `aramb_agents.attach_workflow`. To keep one standalone, just don't pass `agent_id`.
- **`instruction` and `enabled` (both optional, top-level) — wire the workflow to its owning agent's invocation behavior** (the console **Tools ▸ Workflows** tab). `instruction` is free-text on HOW and WHEN the owning agent should invoke this workflow and what input to pass — surfaced **verbatim** in the agent's "## Your workflows" prompt injection. `enabled` (`true`/`false`) is a per-agent toggle: `false` hides the bound workflow from the owning agent; `true` (or omitted) surfaces it. On `update` these are **merged, not clobbering** — see the note under "Update an existing workflow".
- **`project_id` is required; `application_id` is optional/legacy.** Pass `project_id` (alongside `agent_id`) to create the workflow. The workflow is keyed by its own lineage (`workflow_id`) and belongs to its owning agent.
- **`application_id` (optional, legacy app-bound)** — passing it binds the workflow to one application. App-bound workflows retain the old "at most one per application" behavior, so a second `create` with the same `application_id` fails (use `aramb_workflows.update` to modify it). Appless workflows have no such limit — a project can hold many.
- Per-user **system** workflows (e.g. the discovery report) are appless workflows in the user's **private project**. They deliver output via **DM** (chil `chat.send_dm`), never a public channel-app post. `get` / `update` by `workflow_id` work identically for appless workflows. (Template imports of system workflows arrive pre-created — polish them via the `import-workflow` skill, don't `create` them.)
- **Edges are top-level**, not per-node. Do NOT emit `dependencies` or `dependsOn` on nodes.
- **Never invent or bind hidden toolkits.** Set a node's `toolkit` / `required_toolkits` only to toolkits the workspace actually exposes. Platform-internal/hidden toolkits (`composio`, `composio_search`, `browser_tool`, `slackbot`, `discord`, `discordbot`, `microsoft_teams`) are REJECTED by `aramb_workflows.create`/`update` — never bind them. For Slack/Discord/Teams messaging deliverables, deliver via chil `chat.send_dm` (no toolkit).
- `template_slug` (optional) is forwarded verbatim from a dispatched `<template-import slug="...">` block when this call originates from template import.
- **`agent_specs` (optional, top-level array) — inline sub-agent definitions carried WITH the workflow.** When a workflow's nodes are genuinely different roles, author each distinct role's FULL sub-agent spec here and reference it from a node by setting that node's `assigned_agent` to the spec's `name`. brahmi stores these on `workflows.agent_specs` and provisions them **deterministically at claim/run** — you do NOT route bespoke node agents through any separate agent-creation flow. Each entry is a `TemplateAgent`:
  - `name` (REQUIRED, unique) — the role identifier a node's `assigned_agent` references.
  - `displayName` — human label.
  - `identity` — who this sub-agent is (like an agent `IDENTITY.md`).
  - `soul` — how it thinks/behaves (like a `SOUL.md`).
  - `agentsDoc` — its operating playbook (like an `AGENTS.md`).
  - `skills` (optional) — registry skill ids, e.g. `["clode-labs/aramb-skills/<slug>"]`.
  - `defaultModel` (optional; `""` = inherit workflow default), `defaultBackend` (e.g. `"claude-sdk"`), `defaultThinking` (e.g. `"medium"`).

  **A node whose `assigned_agent` has no matching spec (and is not an existing roster agent) falls back to the main agent** — so only mint specs for roles that are genuinely distinct. A **single-role workflow keeps `agent_specs` empty (or omitted)** — every node runs as the main agent. See "Multi-agent workflow" below for a worked example.

### Multi-agent workflow — nodes + edges + `agent_specs` in one call

When the nodes do genuinely different work, pass `agent_specs` alongside `nodes` and `edges` in the **same** `aramb_workflows.create` call. Each node's `assigned_agent` names a spec; the spec carries that role's full identity/soul/agentsDoc:

```bash
npx mcporter call aramb_workflows.create \
  agent_id="<AGENT_ID>" \
  project_id="<PROJECT_ID>" \
  name="Blog Post Pipeline" \
  description="Research an outline, draft the sections, then copy-edit into a publishable post." \
  nodes='[
    {"unique_id":1,"name":"Research & outline","prompt":"Read <run_input> for the topic and angle. Research the topic (web search / browser) and produce a structured outline (H2/H3 headings + one-line intent per section). Save it to .planning/outline.md and, in your summary, state the topic and section count so the drafter can act on it.\n\nWhen done — record your output for the next step:\n  npx mcporter call aramb_workflows.update_step project_id=\"<your Project ID>\" step_id=\"<your Workflow Run Step ID>\" status=\"done\" outputs='"'"'{\"summary\":\"Outline for <topic>: N sections.\",\"files\":[\".planning/outline.md\"]}'"'"'","assigned_agent":"outline-writer","acceptance_criteria":"outline.md written with headings + per-section intent","required_toolkits":[]},
    {"unique_id":2,"name":"Draft sections","prompt":"Read your parent step summary + .planning/outline.md. Write full prose for every section, on-topic and in the requested voice, to .planning/draft.md. Summarize word count and any gaps.\n\nWhen done — record your output for the next step:\n  npx mcporter call aramb_workflows.update_step project_id=\"<your Project ID>\" step_id=\"<your Workflow Run Step ID>\" status=\"done\" outputs='"'"'{\"summary\":\"Draft written: ~M words across N sections.\",\"files\":[\".planning/draft.md\"]}'"'"'","assigned_agent":"section-drafter","acceptance_criteria":"draft.md covers every outlined section","required_toolkits":[]},
    {"unique_id":3,"name":"Copy-edit & polish","prompt":"Read .planning/draft.md. Tighten prose, fix grammar/flow, enforce a consistent voice, and produce the final publishable post at .planning/final.md. Summarize what you changed.\n\nWhen done — record your output for the next step:\n  npx mcporter call aramb_workflows.update_step project_id=\"<your Project ID>\" step_id=\"<your Workflow Run Step ID>\" status=\"done\" outputs='"'"'{\"summary\":\"Final post polished and saved.\",\"files\":[\".planning/final.md\"]}'"'"'","assigned_agent":"copy-editor","acceptance_criteria":"final.md is a clean, publishable post","required_toolkits":[]}
  ]' \
  edges='[{"source":1,"target":2},{"source":2,"target":3}]' \
  agent_specs='[
    {"name":"outline-writer","displayName":"Outline Writer","identity":"A content strategist who turns a raw topic into a rigorous, reader-first outline.","soul":"You think in structure. Before any prose exists you decide what the reader must learn and in what order. You research first and never invent facts; every section earns its place. You are decisive about scope — you cut sections that do not serve the core question.","agentsDoc":"1. Read <run_input> for topic, angle, and audience. 2. Research with web search / browser; capture 3-5 credible sources. 3. Produce H2/H3 headings with a one-line intent under each. 4. Write the outline to .planning/outline.md. 5. In outputs.summary, state the topic and section count. Never draft full prose — that is the drafter's job.","skills":["clode-labs/aramb-skills/aramb-browser"],"defaultModel":"","defaultBackend":"claude-sdk","defaultThinking":"medium"},
    {"name":"section-drafter","displayName":"Section Drafter","identity":"A fast, on-voice writer who turns an approved outline into full draft prose.","soul":"You expand structure into readable prose without drifting off-outline. You match the requested voice and audience, keep claims grounded in the outline research, and flag anything you could not substantiate rather than bluffing. You write to be edited — clear over clever.","agentsDoc":"1. Read the parent summary and .planning/outline.md. 2. Draft every section in order; do not add or drop sections. 3. Keep the requested voice; mark unresolved gaps inline as TODO. 4. Save to .planning/draft.md. 5. Report word count and any gaps in outputs.summary. Do not final-polish — the copy-editor owns that pass.","skills":[],"defaultModel":"","defaultBackend":"claude-sdk","defaultThinking":"medium"},
    {"name":"copy-editor","displayName":"Copy Editor","identity":"A meticulous editor who turns a rough draft into a clean, publishable post.","soul":"You protect the reader. You cut filler, fix grammar and flow, enforce one consistent voice, and never change the author's meaning while doing it. You leave the piece tighter than you found it and say exactly what you changed.","agentsDoc":"1. Read .planning/draft.md. 2. Edit for grammar, flow, concision, and voice consistency; preserve meaning. 3. Resolve or surface any TODO/gap left by the drafter. 4. Save the final post to .planning/final.md. 5. Summarize the substantive changes in outputs.summary. Do not re-research or re-outline.","skills":[],"defaultModel":"","defaultBackend":"claude-sdk","defaultThinking":"medium"}
  ]'
```

Each of the three nodes names a distinct spec via `assigned_agent`; the three `agent_specs` entries carry those roles' full identity/soul/agentsDoc and travel with the workflow. Had this been a single-role workflow (e.g. a one-node digest), `agent_specs` would be `'[]'` and every node would run as the main agent.

### Bake the fetch tool into each evaluator node prompt

When a node's `prompt` will have the runtime agent fetch external content (scoring GitHub submissions, reviewing live sites, evaluating applicants), **name the fetch tool in the prompt itself** so the evaluator doesn't rediscover tooling mid-run. Agents that "figure out" how to fetch at runtime default to the headless browser even for public files — that is the #1 cause of slow, flaky big nodes (browser calls are 30–120s and hiccup under load). Author the tool choice per role:

- **Code-evaluation roles** (Backend / Frontend / any GitHub-repo submissions) → bake in: *"Clone or curl the repo (`git clone --depth 1 https://github.com/<owner>/<repo>` or `curl -sL https://raw.githubusercontent.com/<owner>/<repo>/<branch>/<path>`). Public repos need NO auth and NO toolkit — do NOT use the browser for GitHub."*
- **Visual roles** (Product / UI/UX, design, Figma / Rive) → bake in: *"Use the browser (aramb-browser) to open and visually inspect the rendered artifact."*

**General principle (mirror in every fetch-bearing node prompt):** reach for the browser only for JS-rendered, authenticated, or visually-inspected content; fetch public/static content (repos, raw files, plain pages, JSON/APIs) with `curl` / `git clone --depth 1` / `WebFetch`.

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

A single-workflow fetch returns nodes, edges, env_variables, schedule, stateful flag, `auto_triggerable` / `missing_required_env` status, and `callback_url` (the run-status webhook, `null` if unset — the signing secret is never returned here).

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
- **`agent_specs` (optional)** — same top-level inline sub-agent array as on `create` (see the `agent_specs` field + "Multi-agent workflow" example above). Pass the full replacement array when the roles change (add / rename a spec, edit a spec's identity/soul/agentsDoc); omit to keep the current specs. A node's `assigned_agent` must match a spec `name` (or an existing roster agent) or it falls back to the main agent.
- **`instruction` and `enabled` (both optional) — the owning-agent invocation wiring** (same as on `create`; console **Tools ▸ Workflows** tab). Both are **merged, not clobbering**: passing `instruction` alone does NOT wipe `input_schema` or `enabled`, and passing `enabled` alone does NOT wipe `instruction` or `input_schema` (this fixes a prior bug where an update cleared them). Omit either to keep its current value.

```bash
# Set an invocation instruction on an existing workflow — merges, so nodes/edges/input_schema stay intact:
npx mcporter call aramb_workflows.update \
  workflow_id="<WORKFLOW_ID>" \
  instruction="Run whenever the user gives a topic; pass the topic as input." \
  enabled=true
```

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
- Optional `random_delay_enabled` (bool, default `false`) + `random_delay_max_minutes` (int, optional): jitter each fire to a random point after the scheduled tick so runs don't land on robotic exact times. Effective delay = `min(random_delay_max_minutes, 80% of the gap to the next tick)`, chosen fresh each fire — so a jittered run always lands before the next tick. Omit `random_delay_max_minutes` ⇒ cap is purely 80% of the gap. **Cron-only** — does not apply to event/toolkit triggers. The `schedule-workflow` skill owns the natural-language mapping for this.
- Always tell the user which timezone you picked.

### Read schedule
```bash
npx mcporter call aramb_workflows.get_schedule workflow_id="<WORKFLOW_ID>"
```

Returns `cron_expression`, `cron_timezone`, `enabled`, `env_overrides`, `next_run_at`, `random_delay_enabled`, `random_delay_max_minutes`, paused state, and env-readiness flags.

## Run status callbacks (workflow-level webhook)

Set an optional `callback_url` on a workflow so brahmi POSTs a signed status
payload on every **real** run — manual, cron, and event. Preview/test runs are
excluded. Each run fires twice: on **start** (`running`) and on **terminal**
(`completed` / `failed` / `cancelled`).

### Set / update the callback

```bash
npx mcporter call aramb_workflows.set_callback \
  workflow_id="<WORKFLOW_ID>" \
  callback_url="https://example.com/hooks/run-status"
```

- The response returns a **signing secret ONCE**. Surface it to the user verbatim
  and tell them it won't be shown again — they need it to verify the
  `Webhook-Signature` header. brahmi never returns the secret again (not in `get` /
  `list`), so if the user loses it they must re-set the callback to regenerate one.
- Workflow-level config (not per-node, not per-trigger). `callback_url` shows up in
  `get` / `list` output; the secret never does.

### Signed payload contract (matches brahmi exactly)

Each delivery is an HTTP POST to `callback_url`:

```
POST <callback_url>
Content-Type: application/json
Webhook-Id:        <delivery uuid>      # receiver dedup key
Webhook-Timestamp: <unix seconds>
Webhook-Signature: v1,<base64(HMAC-SHA256(secret, "{Webhook-Id}.{Webhook-Timestamp}.{raw-body}"))>

{
  "event": "running",            // running | completed | failed | cancelled
  "run_id": "<uuid>",
  "workflow_id": "<uuid>",
  "workflow_name": "<string>",
  "application_id": "<uuid>",
  "project_id": "<uuid>",
  "status": "running",           // mirrors event for terminal; "running" on start
  "trigger_type": "cron",        // cron | manual | external_event | ...
  "started_at": "2026-06-21T09:14:32Z",
  "finished_at": null,           // null on running; set on terminal
  "error_message": null,         // non-null only on failed
  "duration_ms": null            // null on running; set on terminal
}
```

The receiver verifies the HMAC over the **raw body** with its per-workflow secret.
Delivery is persisted and retried with exponential backoff, so the same
`Webhook-Id` may arrive more than once — receivers must be **idempotent on
`Webhook-Id`**.

## Publishing a workflow — rides on publishing the AGENT

A workflow is part of its owning agent, so it does NOT have a separate publish step
of its own. **`aramb_workflows.create` leaves the workflow a DRAFT — it is NOT
auto-published.** The builder TESTS the draft (via Preview / `aramb_workflows.run` —
see below), and the workflow becomes a live, frozen version **automatically when the
AGENT is published** (`aramb_agents.publish`). There is no "publish this workflow"
action for you to perform as part of building.

- **Do NOT call a workflow-publish tool as a build step.** Publishing is a property
  of the agent: publish the agent and its workflow(s) freeze into the published
  version alongside it. Never tell the user to "publish the workflow from the
  Workflows tab" either — that step does not exist in this model.
- **Test the draft with Preview.** While the workflow is a draft, the builder
  validates it by running/previewing it — `aramb_workflows.run` works on the draft
  (see "Running an existing workflow"). Iterate on the draft until it does what the
  user wants; publishing the agent is what makes it live for end-users.
- **Toolkit connections still matter for a run to succeed**, but they are no longer a
  publish gate you operate. If a node needs a toolkit the user hasn't connected, the
  run surfaces that — verify connections up front (`aramb_toolkits.check_connection`)
  and tell the user which to connect, rather than calling any publish tool.

## Running an existing workflow (manual run)

When the user asks to run a workflow that already exists — "run X", "run the X
workflow", "execute X", "kick off X", "trigger X now", "start X" — kick off a
single manual run with `aramb_workflows.run`. **Policy: ALWAYS confirm the specific
workflow before running, even on an exact name match.** The flow is
list → fuzzy-match → confirm → run.

### 1. List + match
```bash
npx mcporter call aramb_workflows.list project_id="<PROJECT_ID>"
```
Fuzzy-match the user's phrase against the returned `name`s (partial / typo /
synonym is fine — you do the matching).

### 2. Confirm — ALWAYS, before running
State the matched workflow's **exact `name`** (note its `status`, and
`application_id` if app-bound) and ask the user to confirm:

> About to run **Daily Digest** (id `<workflow_id>`). Confirm?

- **Multiple plausible matches** → list them and ask which one.
- **No match** → say so and offer to list what exists. Never invent a `workflow_id`.
- **A `draft` workflow IS runnable** (run tests the draft) — only a paused workflow
  won't fire as-is; surface that in the confirmation if so.

### 3. Run — only after explicit confirmation
```bash
npx mcporter call aramb_workflows.run \
  workflow_id="<WORKFLOW_ID>" \
  custom_instruction="<optional per-run context the user gave>"
```
`aramb_workflows.run` takes **`workflow_id`** (required) and **`custom_instruction`**
(optional). On success it returns `{ "run_id", "status" }`.

`custom_instruction` is optional free-form text passed into the workflow's first
step (`<run_input>`) — include it only if the user supplied extra instructions for
this run; omit it otherwise.

**Running never blocks on publish.** `aramb_workflows.run` runs the **draft** if the
agent is unpublished, or the **published version** if the agent has been published —
either way the run just works, with no separate publish call. So during building the
Architect can rely on `run` (Preview) to test the draft. If a node needs a toolkit
the user hasn't connected, the run surfaces that (no `run_id`) — verify connections
up front and tell the user which to connect (see step 4).

### 4. Report — only what the tool actually returned
Read `aramb_workflows.run`'s result before you say anything:
- **Success (a `run_id` came back):** echo the `run_id`, say the run started, and
  then **hand off to the run** — the system posts real progress and the final
  success/failure note to the conversation on its own. Tell the user updates will
  arrive there; do NOT promise to babysit it.
- **Error (no `run_id`):** report the error to the user **verbatim and plainly**
  (e.g. "not published yet", "wrong id"). Do **NOT** say "it's running", "kicked
  off", or "working now" when the call failed — that is a lie the user will catch
  the moment they look at the empty Runs tab.

### 5. After the run starts — let the system report; never fabricate progress
Once a run is kicked off, brahmi posts **real** run progress and the terminal
result to the conversation automatically. So your job is to hand work to the run,
not to narrate it:

- **Do NOT invent progress.** Never say "4/382 scored, nodes working through the
  rest in parallel batches", "almost done", or any per-batch/per-item count the
  system's posted updates didn't state. You have no live view of step internals
  between dispatch and completion — making numbers up produces optimistic fiction
  while a run may actually be failing. The system's own messages are the source of
  truth.
- **When the user asks "what's the status?", point at the run's own updates.** The
  conversation thread is the source of truth for run/step progress — brahmi posts it
  there as it happens. So acknowledge the run is in progress and that its updates
  (and the final result) arrive here automatically. `aramb_workflows.get` / `list`
  do **not** return run progress — they return the workflow's **definition and
  lifecycle** state (`status` is the workflow's `draft`/`active`/paused state, plus
  schedule/nodes/edges), not per-step run state. Use them only to answer
  *workflow*-level questions ("is it published / scheduled?"), and say plainly that
  that's workflow status, not run progress. Never dress a workflow-level `active`
  up as "the run is going fine," and never substitute a fabricated progress number.
- If the system's posted updates show the run failed or is stuck, relay that plainly
  — don't paper over it with reassuring narration.

**Guardrails:**
- Never call `aramb_workflows.run` without an explicit user confirmation of the
  specific workflow.
- Never guess a `workflow_id` — always resolve via `aramb_workflows.list` first.
- **Run exactly the workflow the user named.** If it can't run (unpublished, wrong
  status, error), say so — NEVER substitute a different, runnable workflow to make
  the action appear to succeed. Running the wrong workflow and reporting success is
  a serious failure.
- One run per confirmation — don't batch-run multiple workflows off one "run X"
  unless the user asked for that.

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
