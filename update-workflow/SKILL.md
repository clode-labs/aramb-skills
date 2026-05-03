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

If no `User-supplied change request:` section exists, you're in plain
regeneration mode (FE-button or "refresh the workflow" intent).

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
- Sequential `unique_id` integers starting at 1 (numbering can be different
  from the existing version — uniqueness is what matters).
- Dependencies via the top-level `edges` array, never on nodes.
- Be stingy with env variables. Same test as create-workflow: "would we ever
  rerun this with a different value?" If no, bake it into the prompt.
- Most workflows have zero, one, or two env variables.

### 4. Call update_workflow

Update progress: "Saving updated workflow".

```bash
npx mcporter call brahmi.update_workflow \
  workflow_id="<workflow_id>" \
  name="Updated Workflow Name" \
  description="What this workflow does in 1-2 sentences" \
  env_variables='{}' \
  nodes='[
    {"unique_id": 1, "name": "First step",  "prompt": "Concrete instruction with the real business context baked in.", "assigned_agent": "agent-name", "acceptance_criteria": "...", "required_toolkits": ["GMAIL"]},
    {"unique_id": 2, "name": "Second step", "prompt": "...",                                                          "assigned_agent": "agent-name", "acceptance_criteria": "...", "required_toolkits": []}
  ]' \
  edges='[
    {"source": 1, "target": 2}
  ]'
```

`name`, `description`, `env_variables` are optional — omit them to keep the
existing values. `nodes` is required and must not be empty. `edges` may be `[]`
for a single-node workflow.

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

### 5. Tell the user about side effects

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
  outputs='{"workflow_id":"<workflow_id>","node_count":<number>,"summary":"Updated workflow: <one-line summary of what changed>. Status: draft (re-publish to put it live). Stateful chain: preserved | reset. Schedule: unchanged | paused."}'
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
- Only use `{{env.VARIABLE_NAME}}` for secrets, identity, or URLs — empty
  `env_variables` is the common case.
- `unique_id` values are sequential integers starting at 1.
- Dependencies live ONLY in the top-level `edges` array. Never on nodes.
- `edges` must be a DAG — no cycles.
- `assigned_agent` should match existing agent names.
- Always close the task: either `status=done` or `status=failed`. Never leave
  in_progress.
- Append `## Progress` bullets so the user can follow along.
