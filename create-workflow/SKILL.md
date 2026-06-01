---
name: create-workflow
description: >
  Author a brand-new workflow definition (no workflow exists yet). Works in two
  dispatch modes: (1) task dispatch — master consolidates an application's
  completed tasks into a reusable workflow; (2) chat dispatch — solo authors from
  the user's explicit description or from the work done so far in this conversation.
  Use when: asked to create a workflow from completed tasks, "build a workflow
  that…", "create a workflow based on the work done so far in this chat", or told
  to use the create-workflow skill. NOT for: editing an existing workflow (use
  update-workflow), polishing a template import (use import-workflow), executing
  or scheduling workflows.
---

# Create Workflow

Construct a brand-new workflow and save it with `aramb_workflows.create`. **The
workflow does NOT exist yet** — brahmi creates the row + nodes atomically on that
one call. Don't ask for a `workflow_id`; you don't have one and don't need one.
The response tells you the id brahmi assigned.

> **If asked to UPDATE an existing workflow, use the `update-workflow` skill. If
> polishing a template-import draft, use `import-workflow`.** This skill only
> handles first-time creation.

## Which dispatch mode am I in? — read this first

Look at your extra-system-prompt for a brahmi **task id** block.

- **Task dispatch (you are master / a team agent).** Brahmi dispatched you as a
  system task with a "Your task id" block giving you `application_id`,
  `project_id`, and `task_id`. Your spec source is the application's **completed
  tasks** — fetch them via `aramb_tasks.list`. You report progress by appending
  to the task description and close yourself out with `aramb_tasks.update`. Each
  node carries a team persona as `assigned_agent` and a `source_task_id`.
- **Chat dispatch (you are solo).** There is **no `task_id`** — you were invoked
  as an ordinary chat turn. Your spec source is either the user's explicit
  description or the work done so far in THIS conversation. You don't have
  `aramb_tasks.*` at all (it's filtered out of your tool list), so you report
  progress and close out by **replying in chat** (brahmi persists your final
  assistant text as the chat row). Each node's `assigned_agent` is `"solo"`
  unless you provisioned sub-agents for differentiated roles, and `source_task_id`
  is omitted.

The `task_id` that selects the mode is **brahmi's** task id from the dispatch
block — NOT Claude's built-in `TaskCreate`. The two are unrelated; a built-in
`TaskCreate` entry does not make this a task dispatch. If there is no brahmi
"Your task id" block in your system prompt, you are in chat dispatch.

Everything else — node schema, `required_toolkits`, the per-step `toolkit`
field, the closing-instruction template, `default_node_settings`, the
no-placeholders / no-`env_variables` rules, the one-shot `aramb_workflows.create`
rule — is identical across both modes. The mode only changes (a) where the spec
comes from, (b) `assigned_agent` / `source_task_id` on nodes, and (c) how you
report progress and close out.

## MUST rules — read before anything else

1. **Every node in `aramb_workflows.create` MUST carry `required_toolkits`.** Copy the array from each source task's `required_toolkits` (task dispatch) or infer it from the action the node performs (chat dispatch). Use `[]` (not omitted) when the node touches no third-party service.
   - **Failure mode:** Omitting `required_toolkits` means workflow Evaluate cannot flag missing connections at publish time, and the Required-toolkits row in the FE node panel renders empty. Empty array `[]` is correct when the node touches no third-party service — never omit the field.
2. **Every node that touches a third-party service MUST carry a singular `toolkit`** — its *primary* toolkit slug, used for trigger-binding. The invariant brahmi enforces: **`toolkit` MUST be a member of that node's `required_toolkits`.** A Gmail-fetch node is `toolkit:"GMAIL", required_toolkits:["GMAIL"]`; a node that reads Drive then writes Sheets is `toolkit:"GOOGLESHEETS", required_toolkits:["GOOGLEDRIVE","GOOGLESHEETS"]` (pick the one the trigger would bind to — usually the action the workflow is "about"). Omit `toolkit` (or pass `null`) only when `required_toolkits` is `[]`. The brahmi MCP schema rejects a `toolkit` that isn't in `required_toolkits`.
3. **Ground every toolkit + trigger slug in the real catalog — never hallucinate.** Before drafting, call `aramb_tools.list_toolkits` to confirm the exact uppercase slugs (and, when the workflow will be event-triggered, `aramb_tools.list_triggers("<TOOLKIT>")` for trigger slugs). Do NOT infer slugs from prose. See "Ground the slugs" below.
4. **No placeholder syntax in any node `prompt`.** No `{{env.KEY}}`, no `{{input.KEY}}`, no template substitution of any kind. There is no substitution layer — a literal `{{env.FOO}}` reaches the agent as the literal string `{{env.FOO}}`. The brahmi MCP schema **rejects** any prompt matching `{{ env.… }}`. Write what the agent should do with the context that arrives in `<run_input>` instead (see "Run input — the only per-run channel" below).
5. **Do NOT declare `env_variables`.** Omit the field from the `aramb_workflows.create` call entirely. The column has no runtime path in v2 — declaring entries reads as "I wired up your API_KEY" when nothing consumes it. The brahmi MCP schema rejects a non-empty `env_variables` map. Secrets/credentials are connected through the Composio account, not declared on the workflow.
6. **Every node's `prompt` MUST end with the workflow-step closing instruction** so the executing agent calls `aramb_workflows.update_step` (with the explicit `step_id` rendered into its dispatch) at the end of its run. See "Closing instruction per node" below for the exact template.
   - **Failure mode:** Without the closing instruction, the agent finishes its LLM session and brahmi's safety net auto-closes the step, but `outputs` stays NULL. The downstream step's `## Upstream context` preamble then shows "(no summary)" instead of the real hand-off — the chain works visually but with zero context flowing between steps. Outputs are load-bearing.
7. **Call `aramb_workflows.create` exactly once.** Success or failure — never retry.
8. **Close out cleanly.** Task dispatch: always close with `aramb_tasks.update` (`status=done` on success, `status=failed` on any error) — never leave the task `in_progress`. Chat dispatch: confirm in your reply text (success or failure). There is no task to close in chat dispatch.

## Run input — the only per-run channel

A workflow run receives ALL of its per-run context in a single `<run_input>`
block that brahmi renders into the **first step's** prompt at dispatch. It holds
either the user's free-form instruction (manual run) or the trigger payload JSON
(trigger run) — same slot either way. There are no declared input variables, no
typed form, no substitution. The agent reads `<run_input>` and figures out what
to do.

This shapes how you write prompts:

- **Don't parameterize inputs with placeholders.** Where you'd once have written
  `Fix the issue at {{env.ISSUE_URL}}`, now write: *"The user's instruction or the
  trigger payload arrives in `<run_input>`. Extract the issue URL, repo, and any
  details from it, then open a PR that fixes the issue."* Trust the agent to parse
  JSON or free text.
- **Step 1 is the funnel.** `<run_input>` renders on the FIRST step only.
  Downstream steps see only their parent's `outputs.summary` + `outputs.files`.
  So **step 1's prompt MUST instruct the agent to distill the relevant input into
  its `outputs.summary`** — e.g. *"Pull the issue number, title, and repo out of
  `<run_input>` and state them in your summary so later steps can act on them."*
  If step 1 doesn't propagate it, step N never sees it.
- **Fail late, gracefully.** If `<run_input>` is empty (a manual run with no text),
  the step should fail with a clear *"I don't have anything to work on — give me an
  issue URL / instruction"* rather than guess. Don't add pre-flight gates; the
  agent surfaces the failure in the run history. Write step-1 prompts that say so.

## Ground the slugs — call aramb_tools before drafting

The slugs you stamp on `toolkit` / `required_toolkits` (and any trigger you wire)
MUST be real catalog values. Don't infer them from prose. Look them up:

```bash
# Confirm toolkit slugs (uppercase, exactly as the catalog reports them)
npx mcporter call aramb_tools.list_toolkits

# When the workflow is meant to fire on an event, read the trigger catalog for
# that toolkit so you ground the trigger slug too (the configure-trigger skill
# does the actual wiring — you just confirm the slug exists):
npx mcporter call aramb_tools.list_triggers toolkit="GITHUB"
```

`aramb_tools.*` returns toolkit + trigger slugs already normalized to uppercase —
use them verbatim. A `toolkit` or `required_toolkits` entry that isn't a real
catalog slug fails pre-flight (no connected account) and the run never starts.

## 1. Get the spec

### Task dispatch — fetch the completed tasks

Append a "Fetching completed tasks" `## Progress` bullet to the task description, then:

```bash
npx mcporter call aramb_tasks.list \
  application_id="<application_id>" \
  status="done"
```

The result is a JSON array of task objects, each with: `task_id`, `name`,
`description`, `acceptance_criteria`, `assigned_agent`, `depends_on`,
`required_toolkits` (Composio toolkit slugs the task used), `outputs`.

**Read `required_toolkits` on every task you fetch.** You copy these into the
corresponding workflow node in step 3 — losing them here loses them forever.

Ignore tasks where `task_kind == "system"` — those are internal bookkeeping
(including the very task you're running). Consolidate only `task_kind == "user"`
tasks. The list is NOT in your prompt by design — fetching it yourself keeps the
dispatch small and gives you full task detail.

### Chat dispatch — classify the message, then gather

First **classify the user's message**:

- *Explicit description* (e.g. "build a workflow that fetches today's emails…"): the spec **is** the message. Don't analyze conversation history. Skip ahead to step 2.
- *History-derived* (e.g. "create a workflow based on the work done so far", "based on what we just did, build a workflow", or any phrasing that points at the conversation as the evidence): consolidate from your own session. This is the same role the task-dispatch path plays — but the evidence is your conversation history, not completed tasks.

For history-derived intent, walk back through the conversation and produce, in your reasoning:

(a) ordered list of meaningful steps you/the user took,
(b) the explicit and implicit data hand-offs between them,
(c) the Composio toolkit slugs you actually called (Gmail, Sheets, Slack, etc. — be honest, infer from real tool calls),
(d) any constants or specific values that should NOT be re-parameterized (recipe baked-in vs. genuine env-vars).

**Generalize, don't transcribe.** A workflow is a *learned recipe* that should run again. If you fetched yesterday's emails as a one-off, the node should be "fetch the most recent day's emails", not "fetch emails dated 2026-05-04". Same for sheet ranges, time windows, recipient lists — bake the *shape*, not the *specifics* of this one run.

If under-specified (either path), ask **1–2** specific clarifying questions via `aramb_chat.ask_question` BEFORE designing; pick sensible defaults for the rest and tell the user what you picked. Common reasons to clarify: identity (which account / inbox / sheet / channel), notification target, cadence vs trigger (if they want a schedule, capture the cron phrase verbatim — you'll wire it in via `aramb_workflows.set_schedule` after save).

```bash
npx mcporter call aramb_chat.ask_question \
  project_id="<PROJECT_ID>" \
  application_id="<APPLICATION_ID>" \
  question="Which Gmail account should the workflow read from — the one connected to this app, or a different one?"
```

## Progress reports — do this throughout

**Task dispatch.** The user sees your task card in the chat sidebar. If you don't
update the task description they stare at a spinner. Append a short `## Progress`
bullet before each major step — before fetching, before designing, before saving.
Three updates is usually right; don't spam. Preserve the original description text
(append, don't replace).

```bash
npx mcporter call aramb_tasks.update \
  task_id="<your task_id>" \
  description="<full current description, including any Progress so far>
## Progress
- Fetched 5 completed tasks
- Analyzing dependencies and agent assignments"
```

**Chat dispatch.** The user sees chat, not a task card. Write short progress
narration in your reply text at three checkpoints (brahmi saves your final
assistant text as the chat row — no MCP call needed):
1. Restate the workflow you're about to build **and which evidence source you're using** ("Building from your description: 3-step Gmail → Sheet → email digest" / "Consolidating from the work we did earlier in this chat: 3 steps — fetch, write, notify").
2. When you start designing nodes ("Designing 3 nodes — Gmail fetch → Sheet append → notify").
3. Just before save ("Saving workflow…").

## 2. Analyze the spec

Study the spec (completed tasks, the explicit description, or the conversation
work). Understand: what each step accomplishes, how steps depend on each other,
which agent does each (task dispatch — keep the original assignment unless a
better fit; chat dispatch — `"solo"` by default, or a sub-agent you provision),
and what inputs/outputs flow between steps.

For chat dispatch this is also the **merge / generalize / split** pass: combine
adjacent same-agent calls into one node where it makes the workflow cleaner;
split steps that mixed responsibilities; rename concrete one-off artefacts ("the
email about Q3 review") into the recurring shape they represent.

## 3. Design the workflow

Update progress: "Designing workflow graph — N nodes, M levels".

- **Merge or split** steps where it makes the workflow cleaner. Not every source task becomes a node.
- **Concrete prompts** — each node's `prompt` carries the real business context baked in. This is a learned recipe, not a blank template. Distill what actually worked but keep the concrete subject matter.
- **Preserve dependencies** — give each node a sequential `unique_id` (integers starting at 1), then express dependencies as a separate top-level `edges` array: `{ "source": <upstream unique_id>, "target": <downstream unique_id> }`. Do NOT put `dependencies`, `depends_on`, or `dependsOn` on node objects — brahmi rejects that shape.
- **`assigned_agent` per node:**
  - *Task dispatch:* keep the source task's agent unless a different existing agent fits the generalized version better.
  - *Chat dispatch:* default to `"solo"`. If the workflow has differentiated step roles (triage → implement → verify → publish, research → draft → review), provision sub-agents with `create-agent` — one per distinct role — and stamp the matching sub-agent name on each node. Only collapse to a single `"solo"` graph when every step is the same kind of work. Never stamp a team-mode persona (`developer`, `aramb-deployer`, `local-deployer`, …) that doesn't actually exist in your image — either it's `"solo"` or a sub-agent you created in this run.
- **Carry `required_toolkits` per node — MANDATORY, never omit.** List the Composio toolkit slugs that node will call (`["GMAIL"]`, `["GOOGLESHEETS","GOOGLEDRIVE"]`, etc.). Task dispatch: source from each task's `required_toolkits` field (primary) and the tool calls you observe in outputs (cross-check). Chat dispatch: infer from the action — Gmail action → `["GMAIL"]`, Sheets append → `["GOOGLESHEETS"]`, Slack DM → `["SLACK"]`. Empty array (`[]`) when a node only writes files / orchestrates — `[]` is REQUIRED, not optional. Slugs are uppercase and **grounded via `aramb_tools.list_toolkits`** (see "Ground the slugs"), not guessed from prose. Brahmi snapshots this list onto every run step at trigger time and the Evaluate step uses it to surface missing-connection warnings before publish.
- **Carry a singular `toolkit` per node that has any toolkits — MANDATORY when `required_toolkits` is non-empty.** It is the node's *primary* toolkit (the one a trigger would bind to). Invariant: `toolkit ∈ required_toolkits`. Single-toolkit node → `toolkit` equals the one slug. Multi-toolkit node → pick the slug the node's job is "about" (the action it exists to perform, not an incidental read). Omit `toolkit` (or `null`) only when `required_toolkits` is `[]`. Brahmi rejects a `toolkit` that isn't in `required_toolkits`.
- **Write prompts against `<run_input>`, never placeholders.** Each node's `prompt` describes what to do with the context it receives — for step 1 that context is the `<run_input>` block (see "Run input — the only per-run channel"); for later steps it's the parent's `outputs.summary`. No `{{env.KEY}}` / `{{input.KEY}}` anywhere. Step 1's prompt must explicitly tell the agent to distill the relevant input into its `outputs.summary` for downstream steps.
- **Set `default_node_settings` on the workflow.** Always emit a sensible defaults block — see "Default node settings — workflow-level". Don't leave it empty: the FE renders the settings tray off these values.
- **Per-node `settings` typically stays empty (`{}`)** — defaults inherit from the workflow. Exception: if a node does something destructive or externally visible (posts to Linear, sends email, writes to a customer DB, deletes files), set that one node's `settings.approval_mode = "manual"`. Use sparingly — over-gating turns every run into a clickfest.
- **Per-node attachments** only when the user explicitly mentioned files in chat. Never invent attachments — empty `input_attachments` is the default.
- **End every node `prompt` with the closing-instruction template** (next section). The agent has no other path to populate `outputs`.

## Closing instruction per node — MANDATORY

Every node's `prompt` MUST end with this exact block, with `<summary>` and `<files>` substituted to match what the node will actually produce. Treat it the way the task-description template treats the closing `aramb_tasks.update` call — non-negotiable, baked into every prompt at authoring time.

Append this to every node's `prompt`:

```
When done — record your output for the next step:
  npx mcporter call aramb_workflows.update_step \
    project_id="<your Project ID from User Message>" \
    step_id="<your Workflow Run Step ID from User Message>" \
    status="done" \
    outputs='{"summary":"<one-paragraph hand-off, under 500 chars>","files":["relative/path/to/output.json"]}'

If you can't complete the step:
  npx mcporter call aramb_workflows.update_step \
    project_id="<your Project ID from User Message>" \
    step_id="<your Workflow Run Step ID from User Message>" \
    status="failed" \
    error="<concise reason + any partial progress>"
```

Why both `summary` and `files`:
- `summary` is a paragraph the next agent reads as preamble — the hand-off vocabulary that makes the chain coherent. Keep it under 500 chars; focus on what's useful downstream, not how the work was done.
- `files` is a list of paths (relative to the workspace working directory) the next agent reads to dig deeper. Empty array `[]` is correct when the node only sends a message / posts to an external service and produces no files.

Notes:
- The agent reads its `project_id` and `step_id` from the User Message under "## Current Context" (`Project ID:` and `Workflow Run Step ID:` lines) at dispatch time. Brahmi rejects cross-step writes (`context_drift`), so the agent MUST copy these UUIDs verbatim into the close call.
- Do NOT instruct the agent to call `aramb_tasks.update` from a workflow-step prompt — that targets the tasks domain (different DB rows) and the run will stall on the safety net. Only `aramb_workflows.update_step` closes a workflow run step.

## Default node settings — workflow-level

Every workflow carries a `default_node_settings` JSONB block on the workflow itself. The FE renders the workflow settings tray from these values, and brahmi merges them per-step at dispatch time (workflow defaults ⊕ node overrides). Always emit it — leaving it `{}` makes the FE render blanks and the runtime fall back to coarse defaults.

Sensible default block to emit unless the user said otherwise:

```json
{
  "model": "claude-sonnet-4-6",
  "effort": "medium",
  "thinking": "adaptive",
  "max_turns": 35,
  "admin": false,
  "budget_usd": 25.0,
  "approval_mode": "auto",
  "instructions": ""
}
```

Field-by-field guidance:

- `model` — workflow-wide model. Sonnet 4.6 is the everyday default; promote to `claude-opus-4-7` only if the user said "use Opus", or the work obviously needs heavier reasoning. Demote to `claude-haiku-4-5` only on explicit user request.
- `effort` — `medium` is the default. Bump to `high` if the user emphasized care / depth, drop to `low` for trivially mechanical workflows.
- `thinking` — `adaptive` is the default; only flip if the user said something specific ("turn extended thinking off", "always think hard").
- `max_turns` — `35` is the default per step. Raise (60–80) only for steps the user explicitly described as long / iterative.
- `admin` — `false`. Don't enable graph-edit privilege without an explicit user ask.
- `budget_usd` — `25.0` is the workflow-wide ceiling. Increase only when the user named a higher number.
- `approval_mode` — `auto` workflow-wide. Manual gating belongs on individual node `settings`, not the workflow default.
- `instructions` — usually `""`. Fill from chat if the user expressed a *cross-workflow* style preference ("respond in IST", "use markdown for replies", "always cite sources"). The string is appended to every step's prompt at dispatch, so it should be voice / format / locale guidance — never task-specific content.

Per-node `settings` overrides only fire when the user asked for variation. Common patterns:
- "the synth step should use Opus" → that one node's `settings.model = "claude-opus-4-7"`.
- a destructive / external-effect step → that node's `settings.approval_mode = "manual"`.
- a step the user said is bigger → that node's `settings.max_turns = 80`.

Otherwise leave each node's `settings: {}`.

## 4. Bake context into prompts — do NOT declare env_variables

The workflow is a *learned recipe*. Bake business context, topic, tone, target
audience, identity, endpoints — every concrete value the recipe needs — directly
into the relevant node's prompt. There is no `env_variables` channel in v2:

- **Omit `env_variables` from the `aramb_workflows.create` call entirely.** The
  column has no runtime path — nothing reads it. Declaring entries misleads the
  user ("I added your API_KEY" — but nothing consumes it). The brahmi MCP schema
  rejects a non-empty `env_variables` map.
- **Secrets / credentials are NOT declared here.** Third-party auth (API keys,
  OAuth tokens) is supplied through the Composio connected account for the
  node's `toolkit` — that's what `required_toolkits` + the pre-flight connection
  check are for. The workflow definition never carries a secret.
- **Per-run inputs are NOT declared here either.** Anything that varies per run
  (the issue to fix, the recipient, the date window) arrives in `<run_input>` at
  run time — the agent reads it from there. See "Run input — the only per-run
  channel". Do NOT invent placeholders for these.

So: constant recipe values → bake into the prompt. Per-run values → read from
`<run_input>`. Secrets → Composio connection. Nothing goes in `env_variables`.

## 5. Save the workflow

Update progress: "Saving workflow to brahmi".

Call `aramb_workflows.create` with `application_id` + `project_id` (both in your
session metadata / dispatch block). Brahmi creates the workflow row + nodes
atomically in a single transaction.

**Pre-flight checklist — verify before calling `aramb_workflows.create`.** For every node:

- `unique_id` — sequential integer starting at 1
- `name` — short label
- `prompt` — concrete instruction with business context baked in **AND ending with the closing-instruction template**
- `assigned_agent` — task dispatch: an existing team persona. Chat dispatch: `"solo"` or a sub-agent you provisioned this run. Never `null`, empty, or a non-existent persona.
- `acceptance_criteria` — how to know the step succeeded
- **`required_toolkits`** — grounded via `aramb_tools.list_toolkits`; copied from the source task (task dispatch) or inferred-then-grounded (chat dispatch). `[]` for orchestration / file-only nodes; never omit.
- **`toolkit`** — the node's primary toolkit slug; MUST be a member of `required_toolkits`. Omit (or `null`) only when `required_toolkits` is `[]`.
- **`prompt`** — no `{{env.…}}` / `{{input.…}}` placeholders anywhere; step 1's prompt instructs the agent to read `<run_input>` and distill the relevant bits into its `outputs.summary`.
- **`source_task_id`** — **task dispatch only:** the `task_id` of the originating user task from `aramb_tasks.list`. Required whenever the node consolidates from one user task; omit only for glue / orchestration nodes you invented. Powers the FE "show me the task that produced this node" link and cost reconciliation. **Chat dispatch:** omit the field entirely (or pass `null`) — solo has no source tasks. Brahmi accepts both.
- **`settings`** — JSONB; usually `{}`. Set keys only when this node deviates from the workflow defaults.

And on the call itself:

- **`default_node_settings`** — the workflow-wide defaults block. Emit it; don't leave it empty.
- **No `env_variables`** — omit the field entirely (the schema rejects a non-empty map).

Bugs that silently break downstream behaviour — fix the payload before calling:
1. Missing `required_toolkits` — kills Evaluate's missing-connection warnings.
2. `toolkit` not in `required_toolkits` (or missing on a toolkit-using node) — brahmi rejects the call.
3. A `{{env.KEY}}` / `{{input.KEY}}` placeholder in any prompt — brahmi rejects the call.
4. Missing `source_task_id` (task dispatch) — once saved, the link to the originating user task is gone for good.
5. Missing closing instruction in `prompt` — `outputs` stays NULL, downstream sees "(no summary)" preamble.

**Each node's `prompt` should look like this (markdown, multi-line) before you JSON-encode it.** This is step 1, so it reads `<run_input>` and distills it for downstream:

```
Read `<run_input>` — it carries the user's instruction (or a trigger payload)
for this run. Extract the target day / calendar from it (default to the primary
calendar and today if it's empty; if there's nothing usable, stop and report
"I don't have anything to work on"). Fetch that day's events and save them as
JSON to .planning/calendar.json. In your summary, state the day and event count
so the next step doesn't have to re-read the input.

When done — record your output for the next step:
  npx mcporter call aramb_workflows.update_step \
    project_id="<your Project ID from User Message>" \
    step_id="<your Workflow Run Step ID from User Message>" \
    status="done" \
    outputs='{"summary":"Fetched N calendar events for today; saved JSON.","files":[".planning/calendar.json"]}'

If you can't complete the step:
  npx mcporter call aramb_workflows.update_step \
    project_id="<your Project ID from User Message>" \
    step_id="<your Workflow Run Step ID from User Message>" \
    status="failed" \
    error="<concise reason>"
```

The instruction body (top paragraph) is per-node business context. The `When done` / `If you can't complete` blocks are the closing template — identical structure across every node, only the `summary` / `files` content differs. Compose both halves, then JSON-encode the full string into the node's `prompt`.

**`aramb_workflows.create` skeleton — task dispatch** (each node carries `source_task_id`):

```bash
npx mcporter call aramb_workflows.create \
  application_id="<application_id>" \
  project_id="<project_id>" \
  name="Descriptive Workflow Name" \
  description="What this workflow does in 1-2 sentences" \
  default_node_settings='{"model":"claude-sonnet-4-6","effort":"medium","thinking":"adaptive","max_turns":35,"admin":false,"budget_usd":25.0,"approval_mode":"auto","instructions":""}' \
  nodes='[
    {"unique_id": 1, "name": "Fetch calendar events", "prompt": "<reads <run_input> + closing template>", "assigned_agent": "developer", "acceptance_criteria": "events array fetched and logged", "required_toolkits": ["GOOGLECALENDAR"], "toolkit": "GOOGLECALENDAR", "source_task_id": "<task_id from aramb_tasks.list>", "settings": {}},
    {"unique_id": 2, "name": "Summarize",             "prompt": "<body + closing template>",            "assigned_agent": "developer", "acceptance_criteria": "summary text produced",          "required_toolkits": [],                "source_task_id": "<task_id from aramb_tasks.list>", "settings": {}},
    {"unique_id": 3, "name": "Email the summary",     "prompt": "<body + closing template>",            "assigned_agent": "developer", "acceptance_criteria": "Gmail returned a message id",  "required_toolkits": ["GMAIL"],         "toolkit": "GMAIL", "source_task_id": "<task_id from aramb_tasks.list>", "settings": {"approval_mode":"manual"}}
  ]' \
  edges='[
    {"source": 1, "target": 2},
    {"source": 2, "target": 3}
  ]'
```

**Chat dispatch** is identical except every node's `assigned_agent` is `"solo"`
(or a sub-agent you provisioned) and `source_task_id` is omitted:

```bash
  nodes='[
    {"unique_id": 1, "name": "Fetch calendar events", "prompt": "<reads <run_input> + closing template>", "assigned_agent": "solo", "acceptance_criteria": "events array fetched and logged", "required_toolkits": ["GOOGLECALENDAR"], "toolkit": "GOOGLECALENDAR", "settings": {}},
    {"unique_id": 2, "name": "Summarize",             "prompt": "<body + closing template>",            "assigned_agent": "solo", "acceptance_criteria": "summary text produced",          "required_toolkits": [],                "settings": {}},
    {"unique_id": 3, "name": "Email the summary",     "prompt": "<body + closing template>",            "assigned_agent": "solo", "acceptance_criteria": "Gmail returned a message id",  "required_toolkits": ["GMAIL"],         "toolkit": "GMAIL", "settings": {"approval_mode":"manual"}}
  ]'
```

In both examples, node 3 carries `settings.approval_mode = "manual"` because it sends an external-facing message — exactly the per-node manual-approval heuristic. Nodes 1 and 2 keep `settings: {}` and inherit the workflow defaults.

Node objects carry ONLY the node fields. Dependencies live in the separate top-level `edges` array — each edge is `{source: <unique_id>, target: <unique_id>}`, "target depends on source." A cycle fails the save. For a linear 3-step workflow: `[{"source":1,"target":2},{"source":2,"target":3}]`. Fan-out where 1 feeds both 2 and 3: `[{"source":1,"target":2},{"source":1,"target":3}]`. Single node: omit `edges` (or pass `'[]'`).

The response includes `workflow_id` and `node_count`. If `node_count` matches the number of nodes you sent, the save succeeded.

**Never retry `aramb_workflows.create`.** If the first call succeeds you're done — calling again fails with "workflow already exists for this application". If the first call errors (bad payload, cycle in deps), do NOT retry with a modified payload — close out as failed (task dispatch) or tell the user the concise reason and what they could change (chat dispatch). The user can click Create Workflow again for a fresh attempt.

## 6. Close out

### Task dispatch — close the task

On success, use the `workflow_id` brahmi returned:

```bash
npx mcporter call aramb_tasks.update \
  task_id="<your task_id>" \
  status="done" \
  outputs='{"workflow_id":"<workflow_id from aramb_workflows.create response>","node_count":<number>,"summary":"Consolidated N tasks into M nodes across L levels."}'
```

**Compound-schedule / trigger handoff.** If the user's original create message
*also* asked for a firing condition, this skill does NOT wire it in task dispatch
— it hands off so the right skill runs next. Distinguish by the kind of condition:

- **Wall-clock schedule** ("a daily standup workflow that runs at 9am") → cron →
  `schedule-workflow`. Add a `schedule_hint`.
- **Event trigger** ("…and fire it whenever a new GitHub issue is created") →
  `composio_event` → `configure-trigger`. Add a `trigger_hint`.

```bash
outputs='{"workflow_id":"<id>","node_count":<n>,"summary":"...","schedule_hint":"User also asked for a schedule: \"daily at 9am IST\". Run schedule-workflow next with workflow_id=<id> and the user phrase verbatim."}'
# or, for an event condition:
outputs='{"workflow_id":"<id>","node_count":<n>,"summary":"...","trigger_hint":"User also asked to fire on \"a new GitHub issue\". Run configure-trigger next with workflow_id=<id> and the user phrase verbatim."}'
```

Omit both hints if there was no firing-condition intent.

On failure (aramb_tasks.list error, aramb_workflows.create error, cycle detected, …):

```bash
npx mcporter call aramb_tasks.update \
  task_id="<your task_id>" \
  status="failed" \
  rejection_reason="<concise one-line reason>"
```

**CRITICAL: After calling `aramb_tasks.update`, STOP. Do not send any follow-up messages.**

### Chat dispatch — confirm in chat, schedule if asked

On success, write a one-line confirmation in your reply text (brahmi saves it as the chat row):

```
Workflow created — "<name>" (<workflow_id>) — <n> steps. View it in the Workflows tab.
```

**If the user's original message also contained a scheduling phrase** ("a daily
standup that runs at 9am IST"), don't surface a hint — **just do it.** Immediately
after `aramb_workflows.create` succeeds, call `aramb_workflows.set_schedule`
yourself (it's not gated; the `schedule-workflow` skill has cron-format guidance
if you need it):

```bash
npx mcporter call aramb_workflows.set_schedule \
  workflow_id="<workflow_id>" \
  cron_expression="0 8 * * *" \
  cron_timezone="Asia/Kolkata" \
  enabled=true
```

Then bundle the schedule into your confirmation line ("Workflow created and scheduled for 8am IST every weekday."). On `aramb_workflows.create` error, tell the user the concise reason and what they could change, then stop — don't retry.

**If instead the user asked for an event trigger** ("…and fire it whenever a new
GitHub issue is created"), that's not a cron schedule — use the `configure-trigger`
skill (in your loadout) to wire the `composio_event` trigger after the create
succeeds, then bundle the result into your confirmation. Don't try to express an
event condition as a cron schedule.

## Rules

- Each node's `prompt` carries real business context baked in.
- **Each node's `prompt` MUST end with the closing-instruction template** so the executing agent calls `aramb_workflows.update_step` (with the explicit `step_id` rendered into its dispatch User Message) at the end of its run. Without it, `outputs` stays NULL and the upstream-context hand-off chain shows "(no summary)".
- **Always emit `default_node_settings`** with the full sensible-defaults block; never leave it empty.
- **Per-node `settings`** stays `{}` unless the user asked for variation. Manual approval gating goes on individual node settings, never on the workflow default.
- **`assigned_agent`** — task dispatch: existing team persona. Chat dispatch: `"solo"` or a sub-agent you provisioned this run; never a team-mode persona that doesn't exist in the solo image.
- **`source_task_id`** — task dispatch: copy the literal `task_id` UUID from `aramb_tasks.list` (omit only for invented glue nodes). Chat dispatch: omit (or `null`) — solo has no source tasks.
- **`required_toolkits` per node is an honest list** of Composio slugs the node actually calls, grounded via `aramb_tools.list_toolkits`; `[]` when it touches no third-party service; never omit.
- **`toolkit` per node** is the primary slug for trigger-binding; it MUST be a member of `required_toolkits`; omit (or `null`) only when `required_toolkits` is `[]`.
- **No placeholder syntax in prompts** — no `{{env.KEY}}`, no `{{input.KEY}}`. There is no substitution layer; brahmi rejects prompts containing `{{ env.… }}`. Per-run values arrive in `<run_input>` (step 1 only); the agent reads them there.
- **Do NOT declare `env_variables`** — omit the field. The column has no runtime path in v2 and the schema rejects a non-empty map. Constant recipe values bake into prompts; secrets come from the Composio connection.
- **Step 1's prompt must distill `<run_input>` into its `outputs.summary`** — downstream steps see only the parent's summary, never `<run_input>`.
- **For history-derived chat dispatch, generalize** — strip one-off dates / values; the recipe should run again with fresh inputs.
- `unique_id` values are sequential integers starting at 1 (never 0).
- Dependencies are expressed ONLY via the top-level `edges` array; never put `dependencies` / `depends_on` / `dependsOn` on node objects.
- `edges` must be a DAG — no cycles. Single-node workflow: pass `'[]'` or omit.
- Give the workflow a clear, descriptive name (not "Workflow 1").
- Never call `aramb_workflows.create` more than once — one shot, success or failure.
- **Close out:** task dispatch — always `aramb_tasks.update` (`done` or `failed`), then STOP; never leave `in_progress`. Chat dispatch — confirm inline in your reply text (success or failure), and call `aramb_workflows.set_schedule` yourself if the user also asked for a schedule.
