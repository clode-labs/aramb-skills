---
name: update-workflow
description: >
  Regenerate an existing workflow's definition from the current set of completed
  user tasks. Use when: dispatched as a system task with purpose=update-workflow,
  OR when the user asks to refresh / update / regenerate the workflow. NOT for:
  creating a workflow from scratch (use create-workflow), executing a workflow,
  or editing schedules.
---

# Update Workflow

Regenerate an existing workflow definition based on the current set of completed
tasks. The workflow already exists — your job is to produce a fresh, full
replacement node + edge set, taking the existing definition into account as a
hint about what worked.

## MUST rules — read before anything else

1. **Every node in `update_workflow` MUST carry `required_toolkits`.** Same rule as create-workflow: copy the slugs from each source task's `required_toolkits` field. Use `[]` (not omitted) when the node touches no third-party service. Omitting silently kills the Evaluate missing-connection warnings.
2. **Every node's `prompt` MUST end with a one-line output contract** — one line describing what the next step should expect to find in `outputs.summary` and `outputs.files`. See "Output contract per node" below.
   - If you carry an old node forward and find a literal `npx mcporter call brahmi.update_my_workflow_step …` block at the bottom of its prompt, strip it and replace with the output-contract line.
3. Call `update_workflow` exactly once. Success or failure — never retry.
4. Always close the task with `update_task` (`status=done` on success, `status=failed` on any error). Never leave it `in_progress`.

## Output contract per node

End each node `prompt` with one short line naming what the next step will find in this node's `outputs.summary` (≤500 chars, downstream-facing) and `outputs.files` (workspace-relative paths). Examples:

- `Outputs to next step: 'summary' describes the N events you fetched and the date window covered; 'files' includes .planning/calendar.json.`
- `Outputs to next step: 'summary' is a one-paragraph hand-off naming the prospect cohort and qualifier; 'files' includes the leads CSV.`
- `Outputs to next step: 'summary' confirms the message was sent and includes the Gmail message id; 'files' is empty.`

When carrying an old node forward, if its prompt ends in a literal `npx mcporter call brahmi.update_my_workflow_step …` block, strip the block and replace it with the contract line.

You are normally running as a **task** assigned to master. Brahmi dispatched
you with an extra-system-prompt block named "Your task id" that gives you:
- `application_id` — the workspace
- `project_id` — the project
- `workflow_id` — the workflow you are updating
- `task_id` — your own task id (use this to report progress and close yourself out)

### If you were NOT dispatched (no `workflow_id` in your context)

You were launched directly from chat instead of via the system-task
dispatch. **Do not design the workflow inline.** Instead:

1. Look up the application's workflow:
   ```bash
   npx mcporter call brahmi.get_workflow application_id="<APPLICATION_ID>"
   ```

2. **If a workflow exists** — dispatch a proper system task and exit:
   ```bash
   npx mcporter call brahmi.reconsolidate_workflow workflow_id="<WORKFLOW_ID_FROM_STEP_1>"
   ```
   Then send a one-line confirmation via `brahmi.send_message` (e.g.
   *"Starting workflow update, task &lt;id&gt;."*) and STOP. The dispatched
   system task will arrive separately and reload this skill with the
   correct `workflow_id` in its context.

3. **If no workflow exists** — tell the user there is no workflow to update
   yet and that they need to create one first (suggest the `create-workflow`
   skill / "create workflow" intent). Do NOT attempt to design or create
   one in this turn.

In both branches, do NOT continue past this section — there is no `task_id`
to close, no progress to report. The dispatched task (or the user's next
message) is the next step.

---

**When dispatched normally:** the workflow ALREADY exists. Brahmi will
atomically swap the new definition in when you call `update_workflow`. The
old definition stays in effect until that call succeeds — no half-states.
In-flight runs continue against their snapshot of the old definition.

## Progress reports — do this throughout

The user sees your task card in the chat sidebar. Append a short `## Progress`
bullet to the task description before each major step (fetching, designing,
saving). Three updates is usually right; don't spam.

```bash
npx mcporter call brahmi.update_task \
  task_id="<your task_id>" \
  description="<full current description, including any Progress so far>
## Progress
- Fetched existing workflow + 7 completed tasks
- Analyzing what's new vs the existing structure"
```

Preserve the original description text — append, don't replace.

## Workflow

### 1. Fetch the existing definition

Update progress: "Fetching existing workflow".

```bash
npx mcporter call brahmi.get_workflow workflow_id="<workflow_id>"
```

The response is the full canvas: `name`, `description`, `env_variables`, `nodes`,
`edges`, `stateful`, `status`, plus `schedule` if one is configured. Read it
carefully — that is your hint about what worked. Do not throw it away unless
you have a reason.

### 2. Fetch the completed tasks

```bash
npx mcporter call brahmi.list_tasks \
  application_id="<application_id>" \
  status="done"
```

Same shape as create-workflow: ignore `task_kind == "system"`, consolidate
`task_kind == "user"` only.

### 3. Analyze the delta

Update progress: "Designing updated workflow — N nodes, M levels".

**First — check the dispatched task description for a `User-supplied
change request:` section.** If present, that text is the user's verbatim
instruction (e.g. *"add a Slack DM step after the standup comment"*,
*"remove the email triage step"*, *"change the synth step to also include
tomorrow's calendar preview"*). Treat it as a **first-class authoring
signal** — apply it directly to the relevant node(s), in addition to
whatever the task corpus diff suggests. Without acting on it, the user's
ask vanishes silently and the update looks like a pointless regeneration.

**Reject schedule-shaped change requests.** If the `User-supplied change
request:` is solely about cron / timing ("change the schedule to weekly",
"stop the cron", "move it to UTC", "run it every Monday at 9am instead of
Tuesday", "pause the schedule"), DO NOT call `update_workflow`. The cron
fields live in a different storage column and have a dedicated skill
(`schedule-workflow`) — touching them through `update_workflow` regenerates
the definition for nothing and ignores the actual ask. Close the task as
follows:

```bash
npx mcporter call brahmi.update_task \
  task_id="<your task_id>" \
  status="failed" \
  rejection_reason="schedule-shaped change request — dispatch schedule-workflow skill instead with workflow_id=<id> and the user's exact phrase"
```

This signals master to route the request through the right skill. update-workflow only owns the workflow definition (nodes, edges, env vars, settings); cron belongs to schedule-workflow.

If the request is **mixed** (definition change + schedule change in one
sentence), apply the definition change here as normal and add a note in your
closing `outputs` so master knows to dispatch schedule-workflow next:

```
"schedule_hint":"User also asked to change the schedule: \"<verbatim phrase>\". Dispatch schedule-workflow with workflow_id=<id>."
```

If no `User-supplied change request:` section exists, you're in plain
regeneration mode (FE-button or "refresh the workflow" intent).

### Intent recognition for setting changes

Many change requests don't change the *graph* — they change a *setting*. Recognize the intent and apply the change at the right level. The defaults block is `default_node_settings` on the workflow; per-node deviations live in each node's `settings` field. Workflow defaults inherit down; per-node values override.

Common phrases and where they land:

| User phrase | Where to apply |
|---|---|
| "all steps should use Opus" / "switch the model to Opus" | `default_node_settings.model = "claude-opus-4-7"` (workflow) |
| "the synth step should use Opus" | that one node's `settings.model = "claude-opus-4-7"` (override) |
| "use Sonnet everywhere except the writer step, which should be Opus" | workflow `default_node_settings.model = "claude-sonnet-4-6"` AND that one node's `settings.model = "claude-opus-4-7"` |
| "give it a $50 budget" / "raise the budget to $50" | workflow-level `budget_usd = 50.0`. This is the cumulative cap across the whole workflow run (passed to benji as `maxSessionCostUsd`). |
| "cap the synth step at $5" / per-step budget intents | Reject. Budget caps are workflow-level only — benji enforces them across the whole run, not per step. Reply: "Budget caps apply to the whole workflow run, not individual steps. I'll set the workflow budget to $5 if that's what you meant." |
| "this step shouldn't auto-approve" / "make me approve the email step" | that one node's `settings.approval_mode = "manual"` |
| "auto-approve everything" | workflow `default_node_settings.approval_mode = "auto"` AND clear `approval_mode` from any per-node `settings` overrides (so they inherit) |
| "always respond in IST" / "use markdown for replies" / "cite sources" | `default_node_settings.instructions = "<phrase>"` (workflow) — voice/format/locale guidance lives at the workflow level |
| "for this step, prefer concise bullets" | that one node's `settings.instructions = "<phrase>"` — appends to the workflow-level instructions |
| "give it more turns" / "let each step go up to 80 turns" | `default_node_settings.max_turns = 80` (workflow) |
| "let the synth step take longer" | that one node's `settings.max_turns = 80` (override) |
| "turn extended thinking off" | `default_node_settings.thinking = "off"` (workflow) |
| "turn admin on" | `default_node_settings.admin = true` — only when the user explicitly asks. Off by default. |

**Inheritance model — be explicit in the user reply.** When you change a
workflow default, mention what it implies for nodes that had overrides
("Set the workflow default to Opus and cleared the node override on the
synth step so it inherits."). When you set a node override, name the node
("Switched the synth step to Opus; other steps still use the workflow
default of Sonnet."). The user's mental model of "default + override" only
holds if you describe changes in those terms.

**Don't touch settings the user didn't ask about.** Carry the existing
`default_node_settings` and per-node `settings` through unchanged from
`get_workflow` (step 1). Edit only the fields the user named.

Then compare the existing definition against the current task corpus:
- Are there new tasks the existing graph doesn't reflect? Add nodes.
- Are some existing nodes obsolete now (nothing in the current task set looks
  like them)? Drop them.
- Did agent assignments change? Update `assigned_agent` per node.
- Are env variables still relevant? Drop unused ones, add new required ones.

**Lean on the existing definition.** Resist the urge to rewrite from scratch
just because you can. If 80% of the graph is unchanged, keep 80% of the graph
unchanged. The user already saw and accepted the existing version. The
change request, if present, tells you *which* 20% to actually touch.

**Same authoring rules as create-workflow:**
- Concrete prompts with real business context baked in. No generic templates.
- **Each node `prompt` ends with a one-line output contract** (see "Output contract per node" above).
- **Each node carries `required_toolkits`** — never omit; `[]` for orchestration / file-only nodes.
- **Each node carries `settings`** — usually `{}`. Carry forward any existing per-node overrides from the `get_workflow` response, plus or minus what the user is changing in this request. Don't drop overrides the user didn't mention.
- **Carry forward `default_node_settings`** from the existing workflow, edited only where the user asked. If the existing workflow has an empty / missing block (older definitions), seed it with the same sensible defaults create-workflow uses (`model=claude-sonnet-4-6`, `effort=medium`, `thinking=adaptive`, `max_turns=35`, `admin=false`, `budget_usd=25.0`, `approval_mode=auto`, `instructions=""`).
- Sequential `unique_id` integers starting at 1 (numbering can be different
  from the existing version — uniqueness is what matters).
- Dependencies via the top-level `edges` array (each edge `{source, target}` referencing `unique_id`s), never on nodes.
- Be stingy with env variables. Same test as create-workflow: "would we ever
  rerun this with a different value?" If no, bake it into the prompt.
- Most workflows have zero, one, or two env variables.

### 4. Call update_workflow

Update progress: "Saving updated workflow".

**Pre-flight checklist — verify before calling update_workflow.** For every node
in your `nodes` array, confirm each of these fields is present:

- `unique_id` — sequential integer starting at 1
- `name` — short label
- `prompt` — concrete instruction with business context baked in **AND a one-line output contract** at the end describing what `outputs.summary` / `outputs.files` will contain.
- `assigned_agent` — name of an existing agent
- `acceptance_criteria` — how to know the step succeeded
- **`required_toolkits` — copied from the corresponding source task's `required_toolkits`. Use `[]` for orchestration / file-only nodes; never omit the field.**
- **`settings` — JSONB; preserve existing per-node overrides from `get_workflow`, edit only where the user asked. `{}` when the node has no overrides.**

And on the call itself:

- **`default_node_settings`** — carry the existing block forward (or seed sensible defaults if the existing one is empty), then apply any workflow-wide setting changes the user requested.

One bug silently breaks downstream behaviour and is as fatal as in `save_workflow`:
1. Missing `required_toolkits` — kills Evaluate's missing-connection warnings.

**Each node's `prompt` should look like this (markdown, multi-line) before you JSON-encode it:**

```
Concrete instruction with the real business context baked in.

Outputs to next step: 'summary' is a one-paragraph hand-off describing
<what>; 'files' includes <relative paths or '[]'>.
```

The instruction body (top paragraph) is per-node business context. The trailing `Outputs to next step:` line is the per-node output contract — identical structure across every node, only the description of `summary` / `files` content differs.

`update_workflow` skeleton:

```bash
npx mcporter call brahmi.update_workflow \
  workflow_id="<workflow_id>" \
  name="Updated Workflow Name" \
  description="What this workflow does in 1-2 sentences" \
  env_variables='{}' \
  default_node_settings='{"model":"claude-opus-4-7","effort":"medium","thinking":"adaptive","max_turns":35,"admin":false,"budget_usd":50.0,"approval_mode":"auto","instructions":""}' \
  nodes='[
    {"unique_id": 1, "name": "First step",  "prompt": "<body + output contract>", "assigned_agent": "agent-name", "acceptance_criteria": "...", "required_toolkits": ["GMAIL"], "settings": {}},
    {"unique_id": 2, "name": "Second step", "prompt": "<body + output contract>", "assigned_agent": "agent-name", "acceptance_criteria": "...", "required_toolkits": [],        "settings": {"approval_mode":"manual"}}
  ]' \
  edges='[
    {"source": 1, "target": 2}
  ]'
```

The example above shows a workflow whose user said "switch the model to Opus and raise the budget to $50, but make me approve step 2" — workflow-level changes land in `default_node_settings`, the per-step gating lands in node 2's `settings`.

`name`, `description`, `env_variables`, `default_node_settings` are optional —
omit them to keep the existing values. `nodes` is required and must not be
empty. `edges` may be `[]` for a single-node workflow.

**`required_toolkits` per node — always include it.** Copy the existing
list from the matching node in `get_workflow` (step 1), plus or minus
whatever the user is changing. If you omit the field, brahmi falls back to
the prior node's toolkits matched by `name`, but that fallback is brittle
across renames — emit the field explicitly. Use `[]` only when the node
genuinely needs no toolkits.

The response includes:
- `workflow_id`, `status`, `node_count`, `message` (familiar from save_workflow)
- `stateful_continuity`: `"preserved"` or `"reset"`
- `stateful_reset_reason` (only when reset): why the chain was reset
- `schedule_paused` + `schedule_paused_reason` (only when an enabled schedule
  was auto-paused due to env mismatch)

The response `status` will always be `"draft"` after a successful update —
brahmi demotes every updated workflow back to draft so the user can re-publish
deliberately. (See "side effects" below.)

### 5. Tell the user about side effects + setting changes

**Describe setting changes in inheritance terms.** The user's mental model
of these settings is "workflow default + per-node override." When you write
the closing summary, frame it that way so they can predict behavior:

- workflow default change → "Set the workflow default model to Opus." (one line, applies everywhere)
- per-node override → "Switched the synth step to Opus; other steps still use the workflow default of Sonnet."
- removing an override → "Cleared the node-level model override on the synth step so it inherits the workflow default."
- mixed → "Set the workflow default to Sonnet AND overrode the writer step to Opus."

If you only edited the graph (no settings touched), no settings line needed.

**Status is now `draft` — re-publish required.** Every successful update
demotes the workflow to `draft`, regardless of where it was before (active,
paused, etc.). The new definition is NOT live until the user re-publishes
(brahmi auto-evaluates toolkit connections at publish time). Cron schedules
do NOT fire from `draft`, so any scheduled workflow is effectively paused
until republish. Always mention this in your task outputs so the user knows
to act.

If `stateful_continuity` is `"reset"`: the workflow is `stateful=true` AND the
new entry node uses a different agent than the previous one. The next
stateful run starts a fresh trunk. Mention this in your task outputs so the
user knows.

If `schedule_paused` is `true`: the workflow had an enabled cron schedule and
the new env_variables no longer satisfy required keys, so brahmi auto-paused
it. Tell the user the reason and that they can resume the schedule once the
env values are sorted out.

### 6. Close your task

On success — use the workflow_id from the response (same as the input):

```bash
npx mcporter call brahmi.update_task \
  task_id="<your task_id>" \
  status="done" \
  outputs='{"workflow_id":"<workflow_id>","node_count":<number>,"summary":"Updated workflow: <one-line summary of what changed, in inheritance terms when settings were touched>. Status: draft (re-publish to put it live). Stateful chain: preserved | reset. Schedule: unchanged | paused."}'
```

If the user's request also contained a schedule-shaped phrase that you didn't
handle (mixed intent), include `"schedule_hint"` so master can dispatch
`schedule-workflow` next:

```
"schedule_hint":"User also asked to change the schedule: \"<verbatim phrase>\". Dispatch schedule-workflow with workflow_id=<id>."
```

On failure — list_tasks error, get_workflow error, update_workflow error
(invalid status, cycle in edges, etc.):

```bash
npx mcporter call brahmi.update_task \
  task_id="<your task_id>" \
  status="failed" \
  rejection_reason="<concise one-line reason>"
```

The original definition is intact on failure — UpdateWorkflowNodes is atomic
and any rejection happens before the swap. Brahmi emits `workflow.update_failed`
so the UI can show "Update failed, original kept" instead of treating the
workflow as gone.

**CRITICAL: After calling `update_task`, STOP. Do not send any follow-up messages.**

## Rules

- One shot: never call `update_workflow` twice for the same task. If the first
  call succeeded, you're done. If it errored, close the task as failed.
- Each node's `prompt` must carry the real business context baked in.
- **Each node's `prompt` ends with a one-line output contract** describing what `outputs.summary` / `outputs.files` will contain (see "Output contract per node" above).
- **Each node carries `required_toolkits`** — copied from the source tasks; `[]` when the node touches no third-party service; never omit.
- **Each node carries `settings`** — preserve existing per-node overrides from `get_workflow`; `{}` when the node has no overrides.
- **Carry `default_node_settings`** forward unchanged from `get_workflow`, edited only where the user asked. Never silently drop the workflow defaults block.
- **Reject schedule-shaped change requests** ("change the schedule to weekly", "stop the cron", "move it to UTC"). Close as failed with a `rejection_reason` telling master to dispatch `schedule-workflow` instead. Cron/timezone/enabled is the schedule-workflow skill's responsibility, not this skill's.
- **Apply setting changes at the right level** (see "Intent recognition for setting changes"): workflow-wide phrases like "all steps" / "the workflow" / "everywhere" → `default_node_settings`. Single-step phrases like "the synth step" / "this step" → that one node's `settings` override.
- Only use `{{env.VARIABLE_NAME}}` for secrets, identity, or URLs — empty
  `env_variables` is the common case.
- `unique_id` values are sequential integers starting at 1.
- Dependencies live ONLY in the top-level `edges` array. Never on nodes.
- `edges` must be a DAG — no cycles.
- `assigned_agent` should match existing agent names.
- Always close the task: either `status=done` or `status=failed`. Never leave
  in_progress.
- Append `## Progress` bullets so the user can follow along.
