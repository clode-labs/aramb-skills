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

The result is a JSON array of task objects. Each has: `id`, `task_name`,
`description`, `acceptance_criteria`, `assigned_agent`, `depends_on`, `outputs`.

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
- **Carry `required_toolkits` per node** — for each node, list the Composio toolkit slugs that node will call (`["GMAIL"]`, `["GOOGLESHEETS","GOOGLEDRIVE"]`, etc.). Pull these from the source tasks' `required_toolkits` field and from the actual tool calls you observe in the task outputs. Empty array (`[]`) when a node only writes files / orchestrates and does not touch a third-party service. Slugs are uppercase, exactly as Composio reports them. Brahmi snapshots this list onto every workflow run step at trigger time so the executing agent sees the same dependencies the planner declared.

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

```bash
npx mcporter call brahmi.save_workflow \
  application_id="<application_id>" \
  project_id="<project_id>" \
  name="Descriptive Workflow Name" \
  description="What this workflow does in 1-2 sentences" \
  env_variables='{}' \
  nodes='[
    {"unique_id": 1, "name": "First step",  "prompt": "Concrete instruction with the real business context baked in.", "assigned_agent": "agent-name", "acceptance_criteria": "How to know this step succeeded", "required_toolkits": []},
    {"unique_id": 2, "name": "Second step", "prompt": "...",                                                          "assigned_agent": "agent-name", "acceptance_criteria": "...",                          "required_toolkits": ["GMAIL","GOOGLESHEETS"]}
  ]' \
  edges='[
    {"source": 1, "target": 2}
  ]'
```

Node objects carry ONLY the node fields (unique_id / name / prompt / assigned_agent / acceptance_criteria / approval_mode / required_toolkits). Dependencies live in the separate top-level `edges` array — each edge is `{source: <unique_id>, target: <unique_id>}`, meaning "the target node depends on the source node." A cycle in edges will cause the save to fail.

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
