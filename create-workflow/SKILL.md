---
name: create-workflow
description: >
  Consolidate completed tasks into a reusable, generalized workflow definition.
  Use when: asked to create a workflow from completed tasks, or told to use the
  create-workflow skill. NOT for: executing workflows, editing existing workflows,
  or managing workflow status.
---

# Create Workflow

Analyze completed tasks and consolidate them into a generalized, repeatable workflow.

> **If asked to update an existing workflow instead, use the `update-workflow` skill.**
> This skill only handles the first-time creation flow (no workflow exists yet).

## MUST rules — read before anything else

1. **Every node in `save_workflow` MUST carry `required_toolkits`.** Copy the array from each source task's `required_toolkits` field. Use `[]` (not omitted) when the node touches no third-party service.
   - **Failure mode:** Omitting `required_toolkits` from `save_workflow` nodes means workflow Evaluate cannot flag missing connections at publish time, and the Required-toolkits row in the FE node panel renders empty. ALWAYS copy from each source task's `required_toolkits` field. Empty array `[]` is correct when the node touches no third-party service.
2. **Every node's `prompt` MUST end with a one-line output contract** — one line describing what the next step should expect to find in `outputs.summary` and `outputs.files`. See "Output contract per node" below.
3. Call `save_workflow` exactly once. Success or failure — never retry.
4. Always close the task with `update_task` (`status=done` on success, `status=failed` on any error). Never leave it `in_progress`.

You are running as a **task** assigned to master. Brahmi dispatched you with an
extra-system-prompt block named "Your task id" that gives you:
- `application_id` — the workspace to consolidate
- `project_id` — the project the workspace lives in
- `task_id` — your own task id (use this to report progress and close yourself out)

**The workflow does NOT exist yet.** Brahmi creates it atomically when you
call `save_workflow`. Don't ask for a workflow_id — you don't have one and
don't need one. If `save_workflow` succeeds, the response tells you the
workflow_id brahmi assigned; use that in your task outputs.

The list of completed tasks is NOT in your prompt. Fetch it yourself via the
`list_tasks` MCP tool. This keeps the dispatch message small and lets you see
the full task detail.

## Progress reports — do this throughout

The user sees your task card in the chat sidebar. If you don't update the
task description, they're staring at a spinner with zero signal. Before each
major step below, append a short `## Progress` bullet to the task description
so the user can follow along. Example pattern:

```bash
npx mcporter call brahmi.update_task \
  task_id="<your task_id>" \
  description="<full current description, including any Progress so far>
## Progress
- Fetched 5 completed tasks
- Analyzing dependencies and agent assignments"
```

Rules of thumb:
- Report before step 1 (fetching), before step 3 (designing), and before
  step 5 (saving). Three progress updates is usually right; don't spam.
- Keep each bullet to one line.
- Preserve the original description text — append, don't replace.

## Workflow

### 1. Fetch the completed tasks

Update task description with a "Fetching completed tasks" progress bullet, then:

```bash
npx mcporter call brahmi.list_tasks \
  application_id="<application_id>" \
  status="done"
```

The result is a JSON array of task objects. Each has: `task_id`, `name`,
`description`, `acceptance_criteria`, `assigned_agent`, `depends_on`,
`required_toolkits` (Composio toolkit slugs the task used), `outputs`.

**Read `required_toolkits` on every task you fetch.** You will copy these
into the corresponding workflow node in step 5 — losing them here means
losing them forever.

Ignore tasks where `task_kind == "system"` — those are internal bookkeeping
(including the very task you're running). Consolidate only `task_kind == "user"`
tasks.

### 2. Analyze tasks

Study the completed tasks. Understand:
- What each task accomplished
- How tasks depend on each other
- Which agents were assigned and why
- What inputs/outputs flow between tasks

### 3. Design the workflow

Update progress: "Designing workflow graph — N nodes, M levels".

- **Merge or split** tasks where it makes the workflow cleaner. Not every task becomes a node — some may be combined, others split.
- **Concrete prompts** — each node's `prompt` carries the real business context baked in. This is a learned recipe, not a blank template. Distill what actually worked from the session but keep the concrete subject matter.
- **Preserve dependencies** — give each node a sequential `unique_id` (integers starting at 1), then express dependencies as a separate top-level `edges` array: `{ "source": <upstream unique_id>, "target": <downstream unique_id> }`. Do NOT put `dependencies`, `depends_on`, or `dependsOn` on node objects — brahmi rejects that shape.
- **Keep agent assignments** unless a different agent fits better for the generalized version.
- **Carry `required_toolkits` per node — MANDATORY, never omit.** For each node, list the Composio toolkit slugs that node will call (`["GMAIL"]`, `["GOOGLESHEETS","GOOGLEDRIVE"]`, etc.). Source the slugs from the source tasks' `required_toolkits` field (primary) and from the actual tool calls you observe in the task outputs (cross-check). Empty array (`[]`) when a node only writes files / orchestrates and does not touch a third-party service — `[]` is REQUIRED, not optional; do not omit the field. Slugs are uppercase, exactly as Composio reports them. Brahmi snapshots this list onto every workflow run step at trigger time so the executing agent sees the same dependencies the planner declared, and the Evaluate step uses it to surface missing-connection warnings before publish.
- **Set `default_node_settings` on the workflow.** Always emit a sensible defaults block — see "Default node settings — workflow-level" below. Don't leave it empty: the FE renders the settings tray off these values, and a missing block surfaces as blank fields the user has to fill in by hand.
- **Per-node `settings` typically stays empty (`{}`)** — defaults inherit from the workflow. The exception: if a node clearly does something destructive or externally visible (posts to Linear, sends an email, writes to a customer DB, deletes files), set that one node's `settings.approval_mode = "manual"` so a human has to approve the step before it runs. Use this heuristic sparingly — over-gating turns every run into a clickfest.
- **Per-node attachments** only when the user explicitly mentioned files in chat ("here's the spreadsheet", "use this PDF as the spec"). Never invent attachments — empty `input_attachments` is the default.
- **End every node `prompt` with a one-line output contract** describing what the next step should find in this node's `outputs.summary` and `outputs.files`. See "Output contract per node" below.

## Output contract per node

End each node `prompt` with one short line naming what the next step will find in this node's `outputs.summary` (≤500 chars, downstream-facing) and `outputs.files` (workspace-relative paths).

Format `summary` as readable markdown — short headings or bullets where useful; code-fence identifiers, file paths, IDs, and small JSON snippets. It renders directly in the FE timeline for humans AND is parsed as preamble by the next agent, so both audiences benefit from the same structure. Avoid wall-of-text paragraphs; lead with the key facts.

Examples:

- `Outputs to next step: 'summary' describes the N events you fetched and the date window covered; 'files' includes .planning/calendar.json.`
- `Outputs to next step: 'summary' is a one-paragraph hand-off naming the prospect cohort and qualifier; 'files' includes the leads CSV.`
- `Outputs to next step: 'summary' confirms the message was sent and includes the Gmail message id; 'files' is empty.`

Terminal nodes (no downstream consumer) still get a contract line — phrase it as `Outputs: 'summary' is a one-line user-facing confirmation; 'files' is empty.` Keeps the recipe consistent and gives the FE timeline a useful summary string.

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

- `model` — workflow-wide model. Sonnet 4.6 is the everyday default; promote to `claude-opus-4-7` only if the user said "use Opus", or the work obviously needs heavier reasoning (deep code synthesis, long planning). Demote to `claude-haiku-4-5` only on explicit user request.
- `effort` — `medium` is the default. Bump to `high` if the user emphasized care / depth, drop to `low` for trivially mechanical workflows (e.g. simple calendar scrape + email).
- `thinking` — `adaptive` is the default; only flip if the user said something specific ("turn extended thinking off", "always think hard").
- `max_turns` — `35` is the default per step. Raise (60–80) only for steps the user explicitly described as long / iterative.
- `admin` — `false`. Don't enable graph-edit privilege without an explicit user ask.
- `budget_usd` — `25.0` is the workflow-wide ceiling. Increase only when the user named a higher number.
- `approval_mode` — `auto` workflow-wide. Manual gating belongs on individual node `settings`, not the workflow default — see the per-node heuristic above.
- `instructions` — usually `""`. Fill from chat if the user expressed a *cross-workflow* style preference ("respond in IST", "use markdown for replies", "always cite sources"). The string is appended to every step's prompt at dispatch, so it should be voice / format / locale guidance — never task-specific content.

Per-node `settings` overrides only fire when the user asked for variation. Common patterns:
- "the synth step should use Opus" → that one node's `settings.model = "claude-opus-4-7"`.
- a destructive / external-effect step → that node's `settings.approval_mode = "manual"`.
- a step the user said is bigger than the others → that node's `settings.max_turns = 80`.

Otherwise leave each node's `settings: {}`.

### 4. Identify environment variables

**Be stingy with env variables.** The workflow is a *learned recipe*, not a
generic template — the whole point is that master watched real work happen
and can replay it. Bake business context, topic, tone, target audience, etc.
directly into the relevant node's prompt. Do NOT re-parameterize every
specific thing you see; that defeats the purpose.

Env variables are ONLY for things that genuinely CANNOT live in a prompt at
authoring time. The test: "would we ever want to rerun this exact workflow
with a different value here?" If no, keep it in the prompt.

Valid env variables (workflow-level, not per-node):
- **Secrets** — API keys, tokens, passwords
- **Identity** — email, username, account handle, login
- **URLs / endpoints** — server URL, webhook target, API base URL
- **Other runtime values that truly cannot be known at workflow-authoring time**

Not env variables (these belong in the prompt):
- Business description, company/product name, pitch
- Topic, domain, subject matter, space
- Tone, voice, persona, style
- Target audience, segment
- Any content the user discussed with you in chat — that IS the recipe

Most workflows will have **zero or one or two env variables**. Empty is fine:
pass `env_variables='{}'`.

When you do use env variables, structure them as:
`{ "VAR_NAME": { "default": "value", "description": "what this is" } }`

### 5. Save the workflow

Update progress: "Saving workflow to brahmi".

Call `save_workflow` with `application_id` + `project_id`. Brahmi creates the
workflow row + nodes atomically in a single transaction.

**Pre-flight checklist — verify before calling save_workflow.** For every node
in your `nodes` array, confirm each of these fields is present:

- `unique_id` — sequential integer starting at 1
- `name` — short label
- `prompt` — concrete instruction with business context baked in **AND a one-line output contract** at the end describing what `outputs.summary` / `outputs.files` will contain (see "Output contract per node" above).
- `assigned_agent` — name of an existing agent
- `acceptance_criteria` — how to know the step succeeded
- **`required_toolkits` — copied from the corresponding source task's `required_toolkits`. Use `[]` for orchestration / file-only nodes; never omit the field.**
- **`source_task_id` — the `task_id` of the originating task from `list_tasks`. Required whenever this node consolidates from one user task. Powers the FE "show me the task that produced this node" link and cost reconciliation. Omit only for nodes that don't correspond to a single source task (e.g. a glue / orchestration node you invented).**
- **`settings` — JSONB; usually `{}`. Set keys only when this node deviates from the workflow defaults (e.g. `{"approval_mode":"manual"}` on a destructive step, `{"model":"claude-opus-4-7"}` on a heavy-reasoning step). Defaults inherit from the workflow's `default_node_settings`.**

And on the call itself:

- **`default_node_settings`** — the workflow-wide defaults block. See "Default node settings — workflow-level" above. Emit it; don't leave it empty.

Two bugs silently break downstream behaviour — both non-negotiable, fix the payload before calling `save_workflow`:
1. Missing `required_toolkits` — kills Evaluate's missing-connection warnings.
2. Missing `source_task_id` — once saved, the link to the originating user task is gone for good (cost reconciliation + FE deep-link both stop working).

**Each node's `prompt` should look like this (markdown, multi-line) before you JSON-encode it for `save_workflow`:**

```
Read events from the primary calendar for the current day. Save the
result as JSON to .planning/calendar.json.

Outputs to next step: 'summary' describes the events fetched and the date
window covered; 'files' includes .planning/calendar.json.
```

The instruction body (top paragraph) is per-node business context. The trailing `Outputs to next step:` line is the per-node output contract — identical structure across every node, only the description of `summary` / `files` content differs to match what each node produces.

`save_workflow` skeleton (each node's `prompt` carries its full body + output-contract line — abbreviated below for readability):

```bash
npx mcporter call brahmi.save_workflow \
  application_id="<application_id>" \
  project_id="<project_id>" \
  name="Descriptive Workflow Name" \
  description="What this workflow does in 1-2 sentences" \
  env_variables='{}' \
  default_node_settings='{"model":"claude-sonnet-4-6","effort":"medium","thinking":"adaptive","max_turns":35,"admin":false,"budget_usd":25.0,"approval_mode":"auto","instructions":""}' \
  nodes='[
    {"unique_id": 1, "name": "Fetch calendar events", "prompt": "<body + output contract>", "assigned_agent": "developer", "acceptance_criteria": "events array fetched and logged", "required_toolkits": ["GOOGLECALENDAR"], "source_task_id": "<task_id from list_tasks>", "settings": {}},
    {"unique_id": 2, "name": "Summarize",             "prompt": "<body + output contract>", "assigned_agent": "developer", "acceptance_criteria": "summary text produced",          "required_toolkits": [],                "source_task_id": "<task_id from list_tasks>", "settings": {}},
    {"unique_id": 3, "name": "Email the summary",     "prompt": "<body + output contract>", "assigned_agent": "developer", "acceptance_criteria": "Gmail returned a message id",  "required_toolkits": ["GMAIL"],         "source_task_id": "<task_id from list_tasks>", "settings": {"approval_mode":"manual"}}
  ]' \
  edges='[
    {"source": 1, "target": 2}
  ]'
```

Note on the example: node 3 ("Email the summary") carries `settings.approval_mode = "manual"` because it sends an external-facing message — exactly the kind of step the per-node manual-approval heuristic catches. Nodes 1 and 2 keep `settings: {}` and inherit the workflow defaults.

Note how each node's `required_toolkits` is present: nodes 1 and 3 have the
slugs they actually call, and node 2 (pure summarization, no third-party
service) carries `[]` rather than omitting the field. Each `source_task_id`
is the literal `task_id` UUID from `list_tasks` — copy it directly, do not
fabricate one. Each `prompt` carries the full body AND a one-line output
contract (omitted in the skeleton above for readability — see the multi-line
example earlier in this section for the exact shape).

Node objects carry ONLY the node fields (unique_id / name / prompt / assigned_agent / acceptance_criteria / approval_mode / required_toolkits / source_task_id). Dependencies live in the separate top-level `edges` array — each edge is `{source: <unique_id>, target: <unique_id>}`, meaning "the target node depends on the source node." A cycle in edges will cause the save to fail.

For a linear 3-step workflow the edges would be `[{"source":1,"target":2},{"source":2,"target":3}]`. For a fan-out where step 1 feeds both 2 and 3: `[{"source":1,"target":2},{"source":1,"target":3}]`. If the workflow has only one node, omit `edges` (or pass `'[]'`).

With env variables:

```bash
env_variables='{"LINKEDIN_ACCESS_TOKEN": {"default": "", "description": "OAuth token for posting to LinkedIn"}}'
# ...with "{{env.LINKEDIN_ACCESS_TOKEN}}" in the relevant node's prompt.
```

The response includes `workflow_id` and `node_count`. If the response says
`node_count` matches the number of nodes you sent, the save succeeded.

**Never retry `save_workflow`.** If the first call succeeds, you're done — the
workflow exists and calling again will fail with "workflow already exists for
this application". If the first call errors out (bad payload, cycle in deps,
etc.), close your task as failed with the reason — do NOT retry with a
modified payload. The user can click Create Workflow again for a fresh attempt.

### 6. Close your task

On success — use the `workflow_id` brahmi returned in step 5:

```bash
npx mcporter call brahmi.update_task \
  task_id="<your task_id>" \
  status="done" \
  outputs='{"workflow_id":"<workflow_id from save_workflow response>","node_count":<number>,"summary":"Consolidated N tasks into M nodes across L levels."}'
```

**Compound-schedule handoff.** If the user's original create message *also*
contained a scheduling phrase ("a daily standup workflow that runs at 9am",
"build the digest, run it Mondays at 8am UTC"), this skill does NOT set the
schedule itself — it only produces the workflow. Add a `schedule_hint` field
to your `outputs` so master can dispatch `schedule-workflow` next:

```bash
outputs='{"workflow_id":"<id>","node_count":<n>,"summary":"...","schedule_hint":"User also asked for a schedule: \"daily at 9am IST\". Run schedule-workflow next with workflow_id=<id> and the user phrase verbatim."}'
```

If there was no scheduling intent in the original message, omit `schedule_hint`. Master reads outputs after the task closes; it dispatches the schedule-workflow skill when `schedule_hint` is present.

On failure — if any step above failed (list_tasks error, save_workflow error,
cycle detected in dependencies, etc.):

```bash
npx mcporter call brahmi.update_task \
  task_id="<your task_id>" \
  status="failed" \
  rejection_reason="<concise one-line reason>"
```

**CRITICAL: After calling `update_task`, STOP. Do not send any follow-up messages.**

## Rules

- Each node's `prompt` should carry the real business context baked in
- **Each node's `prompt` ends with a one-line output contract** describing what `outputs.summary` / `outputs.files` will contain for the next step.
- **Always emit `default_node_settings`** with the full sensible-defaults block (see "Default node settings — workflow-level"); never leave it empty
- **Per-node `settings`** stays `{}` unless the user asked for variation. Manual approval gating goes on individual node settings, never on the workflow default.
- **Never set the cron schedule from this skill.** If the user asked for one, surface a `schedule_hint` in your task outputs so master can dispatch `schedule-workflow`.
- Only use `{{env.VARIABLE_NAME}}` for secrets, identity, or URLs — empty `env_variables` is the common case
- `unique_id` values are sequential integers starting at 1 (never 0)
- Dependencies are expressed ONLY via the top-level `edges` array — each edge is `{"source": <upstream unique_id>, "target": <downstream unique_id>}`. Never put `dependencies` / `depends_on` / `dependsOn` on node objects; brahmi rejects the call.
- `edges` must be a DAG — no cycles. If no edges are needed (single-node workflow), pass `'[]'` or omit the argument.
- Give the workflow a clear, descriptive name (not "Workflow 1")
- `assigned_agent` should match existing agent names
- **`required_toolkits` per node is an honest list** of Composio slugs the node actually calls (`["GMAIL"]`, `["GOOGLESHEETS","GOOGLEDRIVE"]`, etc.). Empty array when the node touches no third-party service. Pull from the source tasks' `required_toolkits` plus what you observe in tool-call traces.
- Never call `save_workflow` more than once — one shot, success or failure
- Never call `update_task` with status=done without calling `save_workflow` first
- Always close the task: either `status=done` or `status=failed`, never leave in_progress
- Append to task description periodically with `## Progress` bullets so the user can follow along
