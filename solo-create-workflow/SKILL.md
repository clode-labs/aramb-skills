---
name: solo-create-workflow
description: >
  Author a new workflow — for solo agent. Triggered either by an explicit user
  request ("build a workflow that…") or by the canned button-driven message
  ("create a workflow based on the work done so far in this chat"). NOT for:
  dispatching as a task, consolidating completed tasks (use `create-workflow`
  in task mode instead), executing workflows, or editing existing workflows
  (use `solo-update-workflow`).
---

# Solo Create Workflow

You are solo. The user wants you to author a new workflow. The spec comes
from one of two sources: an explicit description in their message, or the
work you've already done in this conversation. Identify which, then design
and save.

> **If asked to update an existing workflow instead, use the `solo-update-workflow` skill.**
> This skill only handles the first-time creation flow (no workflow exists yet).

## MUST rules — read before anything else

1. **Every node in `save_workflow` MUST carry `required_toolkits`.** Use `[]` (not omitted) when the node touches no third-party service.
   - **Failure mode:** Omitting `required_toolkits` from `save_workflow` nodes means workflow Evaluate cannot flag missing connections at publish time, and the Required-toolkits row in the FE node panel renders empty. Empty array `[]` is correct when the node touches no third-party service — never omit the field.
2. **Every node's `prompt` MUST end with a one-line output contract** — one line describing what the next step should expect to find in `outputs.summary` and `outputs.files`. See "Output contract per node" below.
3. **Every node's `assigned_agent` MUST be `"solo"`.** Do not pick `developer`, `aramb-deployer`, `local-deployer`, or any other persona — those exist only in team mode. Solo has one agent, and that agent (you) executes every step.
   - **Failure mode:** Stamping a team-mode persona on a solo workflow makes brahmi try to provision an agent that doesn't exist in the solo image. Dispatch fails when the step tries to spin up the named persona. The string `"solo"` is the only valid value for `assigned_agent` in this skill — `null`, empty string, omitted field, or any team-mode persona name will be rejected at save time.
4. Call `save_workflow` exactly once. Success or failure — never retry.

## Where the spec comes from

You're running as solo in a regular chat dispatch. There's no `task_id`. The
workflow spec comes from one of:

- **(a) The user's explicit description** in their most recent message — e.g. "build a workflow that fetches today's emails, writes them to a sheet, and emails me when done". The spec **is** the message.
- **(b) The work already done in this chat** — when the user's message is the canned button phrase ("create a workflow based on the work done so far in this chat", "based on what we just did, build a workflow", or any phrasing that points at the conversation as the evidence). The spec is **this conversation**: the ordered tool calls you made, the files written, the toolkits touched. This is the same role master's `create-workflow` plays today — but the evidence is your conversation history, not completed tasks.

**The workflow does NOT exist yet.** Brahmi creates it atomically when you
call `save_workflow`.

## Progress updates — keep the user in the loop

The user does not see a task card; they see chat. Stream short progress
updates via `brahmi.send_message` at three checkpoints:
1. Restate the workflow you're about to build **and which evidence source you're using** ("Building from your description: 3-step Gmail → Sheet → email digest" / "Consolidating from the work we did earlier in this chat: 3 steps I see — fetch, write, notify").
2. When you start designing nodes ("Designing 3 nodes — Gmail fetch → Sheet append → notify").
3. Just before save ("Saving workflow…").

```bash
npx mcporter call brahmi.send_message \
  message="<one-line update>" \
  chat_location="main"
```

Three messages is usually right. Don't spam.

## Workflow

### 1. Identify spec source, then gather it

First, **classify the user's message**:

- *Explicit description* (e.g. "build a workflow that fetches today's emails…"): the spec **is** the message. Don't analyze conversation history. Skip ahead to designing.
- *History-derived* (e.g. "create a workflow based on the work done so far", "based on what we just did, build a workflow", or any phrasing that points at the conversation as the evidence): consolidate from your own session. Identify the ordered steps you took, the tool calls made, the files written, the toolkits touched. This is the same role master's `create-workflow` plays today — but the evidence is your conversation history, not completed tasks.

For history-derived intent, walk back through the conversation and produce, in your reasoning:

(a) ordered list of meaningful steps the user/you took,
(b) the explicit and implicit data hand-offs between them,
(c) the Composio toolkit slugs you actually called (Gmail, Sheets, Slack, etc. — be honest, infer from real tool calls),
(d) any constants or specific values that should NOT be re-parameterized (the recipe baked-in vs. the env-vars you genuinely need).

**Generalize, don't transcribe.** A workflow is a *learned recipe* that should run again. If you fetched yesterday's emails for the user as a one-off, the workflow node should be "fetch the most recent day's emails", not "fetch emails dated 2026-05-04". Same for sheet ranges, time windows, recipient lists — bake the *shape* of the recipe, not the *specifics* of this one run.

If under-specified (either path), ask **1–2** specific clarifying questions via `brahmi.ask_question` BEFORE designing. Don't ask more than 2; pick sensible defaults for the rest and tell the user what you picked when you confirm.

```bash
npx mcporter call brahmi.ask_question \
  question="Which Gmail account should the workflow read from — the one connected to this app, or a different one?"
```

Common reasons to clarify:
- Identity: which account / inbox / sheet / channel
- Notification target: who gets emailed / DM'd at the end
- Cadence vs trigger: is this on-demand only, or should it run on a schedule? (If they want a schedule, capture the cron phrase verbatim — you'll wire it in via `set_workflow_schedule` after save.)

If the spec is clear, skip the questions and go straight to design.

### 2. Decompose the spec into ordered steps

Solo mode has one agent. Decomposition is about ordering work and picking
toolkits, not about picking a persona — every node will carry
`assigned_agent: "solo"` (see MUST rule #3).

In your reasoning, decompose the spec into ordered steps. For each step
identify:
- What data flows in (from the user / from the previous step)
- What the step produces
- Which Composio toolkit slugs it touches (`["GMAIL"]`, `["GOOGLESHEETS"]`, `[]` for orchestration-only)

For history-derived intent, this is the **merge / generalize / split** pass:
combine adjacent same-agent calls into one node where it makes the workflow
cleaner; split steps that mixed responsibilities; rename concrete one-off
artefacts ("the email about Q3 review") into the recurring shape they
represent ("the most recent end-of-quarter email").

### 3. Design the workflow

Send a progress update: "Designing workflow graph — N nodes, M levels".

- **Concrete prompts** — each node's `prompt` carries the real business context baked in. This is a learned recipe, not a blank template. Distill what the user described (or what you actually did, generalised) and bake the specifics in.
- **Preserve dependencies** — give each node a sequential `unique_id` (integers starting at 1), then express dependencies as a separate top-level `edges` array: `{ "source": <upstream unique_id>, "target": <downstream unique_id> }`. Do NOT put `dependencies`, `depends_on`, or `dependsOn` on node objects — brahmi rejects that shape.
- **Stamp `assigned_agent: "solo"` on every node.** Solo mode has only one agent identity. Do not pick team-mode personas (`developer`, `aramb-deployer`, `local-deployer`, etc.) — they do not exist in the solo image and dispatch will fail.
- **Carry `required_toolkits` per node — MANDATORY, never omit.** For each node, list the Composio toolkit slugs that node will call (`["GMAIL"]`, `["GOOGLESHEETS","GOOGLEDRIVE"]`, etc.). Infer slugs from the action you're describing — Gmail action → `["GMAIL"]`, Google Sheets append → `["GOOGLESHEETS"]`, Slack DM → `["SLACK"]`. Empty array (`[]`) when a node only writes files / orchestrates and does not touch a third-party service — `[]` is REQUIRED, not optional; do not omit the field. Slugs are uppercase, exactly as Composio reports them. Brahmi snapshots this list onto every workflow run step at trigger time so the executing agent sees the same dependencies the planner declared, and the Evaluate step uses it to surface missing-connection warnings before publish.
- **Set `default_node_settings` on the workflow.** Always emit a sensible defaults block — see "Default node settings — workflow-level" below. Don't leave it empty: the FE renders the settings tray off these values, and a missing block surfaces as blank fields the user has to fill in by hand.
- **Per-node `settings` typically stays empty (`{}`)** — defaults inherit from the workflow. The exception: if a node clearly does something destructive or externally visible (posts to Linear, sends an email, writes to a customer DB, deletes files), set that one node's `settings.approval_mode = "manual"` so a human has to approve the step before it runs. Use this heuristic sparingly — over-gating turns every run into a clickfest.
- **Per-node attachments** only when the user explicitly mentioned files in chat ("here's the spreadsheet", "use this PDF as the spec"). Never invent attachments — empty `input_attachments` is the default.
- **End every node `prompt` with a one-line output contract** describing what the next step should find in this node's `outputs.summary` and `outputs.files`. See "Output contract per node" below.

## Output contract per node

End each node `prompt` with one short line naming what the next step will find in this node's `outputs.summary` (≤500 chars, downstream-facing) and `outputs.files` (workspace-relative paths).

Format `summary` as readable markdown — short headings or bullets where useful; code-fence identifiers, file paths, IDs, and small JSON snippets. It renders directly in the FE timeline for humans AND is parsed as preamble by the next agent, so both audiences benefit from the same structure. Avoid wall-of-text paragraphs; lead with the key facts.

Examples:

- `Outputs to next step: 'summary' describes the N events you fetched and the date window covered; 'files' includes .planning/calendar.json.`
- `Outputs to next step: 'summary' confirms the message was sent and includes the Gmail message id; 'files' is empty.`
- `Outputs to next step: 'summary' is a one-line user-facing confirmation; 'files' is empty.` (terminal node)

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

- `model` — Sonnet 4.6 is the everyday default; promote to `claude-opus-4-7` only if the user said "use Opus" or the work obviously needs heavier reasoning. Demote to `claude-haiku-4-5` only on explicit user request.
- `effort` — `medium` is the default. `high` if the user emphasized care / depth, `low` for trivially mechanical workflows.
- `thinking` — `adaptive` is the default; only flip if the user said something specific.
- `max_turns` — `35` per step; raise (60–80) only for steps the user described as long / iterative.
- `admin` — `false`. Don't enable graph-edit privilege without an explicit user ask.
- `budget_usd` — `25.0` is the workflow-wide ceiling. Increase only when the user named a higher number.
- `approval_mode` — `auto` workflow-wide. Manual gating belongs on individual node `settings`.
- `instructions` — usually `""`. Fill from chat if the user expressed a *cross-workflow* style preference ("respond in IST", "use markdown for replies") — voice / format / locale guidance, not task-specific content.

Per-node `settings` overrides only fire when the user asked for variation. Otherwise leave each node's `settings: {}`.

### 4. Identify environment variables

**Be stingy with env variables.** The workflow is a *learned recipe*, not a
generic template. Bake business context, topic, tone, target audience, etc.
directly into the relevant node's prompt. Do NOT re-parameterize every
specific thing.

The test: "would we ever want to rerun this exact workflow with a different
value here?" If no, keep it in the prompt.

Valid env variables (workflow-level, not per-node):
- **Secrets** — API keys, tokens, passwords
- **Identity** — email, username, account handle, login
- **URLs / endpoints** — server URL, webhook target, API base URL

Not env variables (these belong in the prompt):
- Business description, company/product name, pitch
- Topic, domain, subject matter, tone, voice, persona, style
- Target audience, segment

Most workflows have **zero or one or two env variables**. Empty is fine: pass
`env_variables='{}'`.

When you do use env variables, structure them as:
`{ "VAR_NAME": { "default": "value", "description": "what this is" } }`

### 5. Save the workflow

Send a progress update: "Saving workflow…".

Call `save_workflow` with `application_id` + `project_id` (both available in
your session metadata). Brahmi creates the workflow row + nodes atomically in
a single transaction.

**Pre-flight checklist — verify before calling save_workflow.** For every node:

- `unique_id` — sequential integer starting at 1
- `name` — short label
- `prompt` — concrete instruction with business context baked in **AND a one-line output contract** at the end describing what `outputs.summary` / `outputs.files` will contain (see "Output contract per node" above).
- **`assigned_agent` — solo has only one agent. Stamp `"solo"` on every node. Do NOT use team-mode personas (`developer`, `aramb-deployer`, `local-deployer`, etc.) — they don't exist in the solo image. Brahmi rejects any other value for solo-mode workflows (defensive save-time override).**
- `acceptance_criteria` — how to know the step succeeded
- **`required_toolkits` — list of Composio slugs the node calls; `[]` for orchestration / file-only nodes; never omit.**
- **`source_task_id` — solo doesn't have source tasks. Omit the field for every node, OR pass `null`. Brahmi accepts both.**
- **`settings` — JSONB; usually `{}`. Set keys only when this node deviates from the workflow defaults.**

And on the call itself:

- **`default_node_settings`** — the workflow-wide defaults block. Emit it; don't leave it empty.

**Each node's `prompt` should look like this (markdown, multi-line) before you JSON-encode it for `save_workflow`:**

```
Read events from the primary calendar for the current day. Save the
result as JSON to .planning/calendar.json.

Outputs to next step: 'summary' describes the events fetched and the date
window covered; 'files' includes .planning/calendar.json.
```

The instruction body (top paragraph) is per-node business context. The trailing `Outputs to next step:` line is the per-node output contract — identical structure across every node, only the description of `summary` / `files` content differs.

`save_workflow` skeleton:

```bash
npx mcporter call brahmi.save_workflow \
  application_id="<application_id>" \
  project_id="<project_id>" \
  name="Descriptive Workflow Name" \
  description="What this workflow does in 1-2 sentences" \
  env_variables='{}' \
  default_node_settings='{"model":"claude-sonnet-4-6","effort":"medium","thinking":"adaptive","max_turns":35,"admin":false,"budget_usd":25.0,"approval_mode":"auto","instructions":""}' \
  nodes='[
    {"unique_id": 1, "name": "Fetch calendar events", "prompt": "<body + output contract>", "assigned_agent": "solo", "acceptance_criteria": "events array fetched and logged", "required_toolkits": ["GOOGLECALENDAR"], "settings": {}},
    {"unique_id": 2, "name": "Summarize",             "prompt": "<body + output contract>", "assigned_agent": "solo", "acceptance_criteria": "summary text produced",          "required_toolkits": [],                "settings": {}},
    {"unique_id": 3, "name": "Email the summary",     "prompt": "<body + output contract>", "assigned_agent": "solo", "acceptance_criteria": "Gmail returned a message id",  "required_toolkits": ["GMAIL"],         "settings": {"approval_mode":"manual"}}
  ]' \
  edges='[
    {"source": 1, "target": 2},
    {"source": 2, "target": 3}
  ]'
```

Note on the example: node 3 ("Email the summary") carries `settings.approval_mode = "manual"` because it sends an external-facing message — exactly the kind of step the per-node manual-approval heuristic catches. Nodes 1 and 2 keep `settings: {}` and inherit the workflow defaults.

The response includes `workflow_id` and `node_count`. If `node_count` matches the number of nodes you sent, the save succeeded.

**Never retry `save_workflow`.** If the first call succeeds, you're done — calling again will fail with "workflow already exists for this application". If the first call errors out (bad payload, cycle in deps, etc.), tell the user the concise reason via `brahmi.send_message` and what they could change. Do NOT retry with a modified payload silently.

### 6. Confirm to the user, and schedule if asked

On success, send the user a one-line confirmation:

```bash
npx mcporter call brahmi.send_message \
  message="Workflow created — \"<name>\" (<workflow_id>) — <n> steps. View it in the Workflows tab." \
  chat_location="main"
```

**If the user's original message also contained a scheduling phrase** ("a daily
standup workflow that runs at 9am IST", "build the digest, run it Mondays at
8am UTC"), don't surface a hint — **just do it**. Immediately after
`save_workflow` succeeds, call `set_workflow_schedule`:

```bash
npx mcporter call brahmi.set_workflow_schedule \
  workflow_id="<workflow_id>" \
  cron_expression="0 8 * * *" \
  cron_timezone="Asia/Kolkata" \
  enabled=true
```

Then bundle the schedule into your confirmation message ("Workflow created and
scheduled for 8am IST every weekday."). The `schedule-workflow` skill is
already in your loadout if you need to consult cron-format guidance.

If `save_workflow` returned an error, tell the user the concise reason via
`brahmi.send_message` and what they could change, then stop. Don't retry.

## Rules

- Each node's `prompt` carries the real business context baked in
- **Each node's `prompt` ends with a one-line output contract** describing what `outputs.summary` / `outputs.files` will contain for the next step.
- **Always emit `default_node_settings`** with the full sensible-defaults block; never leave it empty
- **Per-node `settings`** stays `{}` unless the user asked for variation. Manual approval gating goes on individual node settings, never on the workflow default.
- **`source_task_id` is omitted (or `null`) for every node** — solo doesn't have source tasks
- **`required_toolkits` per node is an honest list** of Composio slugs the node actually calls; `[]` when the node touches no third-party service; never omit
- **For history-derived intent, generalise** — strip one-off dates / values from prompts; the recipe should run again with fresh inputs
- Only use `{{env.VARIABLE_NAME}}` for secrets, identity, or URLs — empty `env_variables` is the common case
- `unique_id` values are sequential integers starting at 1 (never 0)
- Dependencies are expressed ONLY via the top-level `edges` array; never put `dependencies` / `depends_on` / `dependsOn` on node objects
- `edges` must be a DAG — no cycles. If no edges are needed (single-node workflow), pass `'[]'` or omit
- Give the workflow a clear, descriptive name (not "Workflow 1")
- **`assigned_agent` is `"solo"` on every node** — solo mode has only one agent; team-mode personas (`developer`, `aramb-deployer`, `local-deployer`, etc.) do NOT exist in the solo image
- Never call `save_workflow` more than once — one shot, success or failure
- Confirm to the user via `brahmi.send_message` at the end (success or failure)
- If the user also asked for a schedule, call `set_workflow_schedule` yourself right after save — don't punt to the user
