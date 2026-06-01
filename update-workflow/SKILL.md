---
name: update-workflow
description: >
  Regenerate / refresh / tweak an existing workflow's definition. Works in two
  dispatch modes: (1) task dispatch — master regenerates from the current set of
  completed user tasks (system task with purpose=update-workflow); (2) chat
  dispatch — solo applies an explicit change request ("add a Slack DM step",
  "remove the synth node") or consolidates the work done so far in this chat.
  Use when: dispatched as a system task with purpose=update-workflow, OR when the
  user asks to refresh / update / regenerate / change the workflow. NOT for:
  creating a workflow from scratch (use create-workflow), polishing a template
  import (use import-workflow), executing a workflow, or editing schedules
  (use schedule-workflow).
---

# Update Workflow

Produce a fresh, full replacement node + edge set for an **existing** workflow,
taking the existing definition into account as a hint about what worked. The
workflow ALREADY exists — brahmi atomically swaps the new definition in when you
call `aramb_workflows.update`. The old definition stays live until that call
succeeds; in-flight runs continue against their snapshot.

> **If asked to CREATE a workflow from scratch, use `create-workflow`. If polishing
> a template-import draft, use `import-workflow`.** This skill is update-only.

## Which dispatch mode am I in? — read this first

The `task_id` / `workflow_id` referred to here are **brahmi's** ids from the
dispatch block — NOT Claude's built-in `TaskCreate`.

- **A) Task dispatch (you are master, dispatched as a system task).** Your "Your
  task id" block gives you `application_id`, `project_id`, `workflow_id`, and
  `task_id`. Regenerate from the application's completed tasks (+ any user-supplied
  change request in the task description). Report progress on the task description;
  close with `aramb_tasks.update`. → Go to **Path A** below.
- **B) Chat dispatch, team mode (you have `aramb_tasks.*` tools but NO `task_id`).**
  You are master launched directly from chat. **Do not design the update inline.**
  Look up the workflow and dispatch a proper system task, then exit — the
  dispatched task re-enters this skill via Path A. → Go to **Path B** below.
- **C) Chat dispatch, solo (no `task_id`, and no `aramb_tasks.*` tools at all).**
  You are solo. Author the update directly from chat — an explicit change request
  or the work done so far in this conversation. Close by replying in chat. → Go to
  **Path C** below.

Paths A and C share all the authoring rules (analyze the delta, setting-change
intent recognition, closing template, pre-flight, the `aramb_workflows.update`
call, side-effects). They differ only in where the change spec comes from,
`assigned_agent` handling, and how you report progress / close out. Path B is a
short hand-off that does no authoring.

## MUST rules — read before anything else

1. **Every node in `aramb_workflows.update` MUST carry `required_toolkits`.** Copy the slugs from each source task's `required_toolkits` (task dispatch) or the matching node in `aramb_workflows.get` / the action it performs (chat dispatch). Use `[]` (not omitted) when the node touches no third-party service. Omitting silently kills the Evaluate missing-connection warnings. Ground slugs via `aramb_toolkits.list_toolkits` — don't trust a slug you can't see in the catalog.
2. **Every node that touches a third-party service MUST carry a singular `toolkit`** — its primary toolkit slug, used for trigger-binding. Invariant brahmi enforces: **`toolkit ∈ required_toolkits`.** Omit (or `null`) only when `required_toolkits` is `[]`. If the existing node had no `toolkit` (pre-v2 definition), add it now.
3. **No placeholder syntax in any node `prompt`.** No `{{env.KEY}}`, no `{{input.KEY}}`. There is no substitution layer; brahmi **rejects** any prompt matching `{{ env.… }}`. If a node you carry forward from `aramb_workflows.get` still contains legacy `{{env.…}}` placeholders, **rewrite that prompt now** to read its per-run values from `<run_input>` (see "Run input & slug grounding — v2 contract" below).
4. **Do NOT declare `env_variables`.** Omit the field from the `aramb_workflows.update` call (leaving it out keeps nothing — there's no runtime path). If the existing definition declared `env_variables`, drop them: the schema rejects a non-empty map and the values were never read.
5. **Every node's `prompt` MUST end with the workflow-step closing instruction** so the executing agent calls `aramb_workflows.update_step` (with the explicit `step_id` rendered into its dispatch) at the end of its run. See "Closing instruction per node" below.
   - **Failure mode:** Without it, the agent finishes its LLM session, brahmi's safety net auto-closes the step, but `outputs` stays NULL. The downstream step's `## Upstream context` preamble shows "(no summary)" instead of the real hand-off.
6. **Call `aramb_workflows.update` exactly once.** Success or failure — never retry.
7. **Close out cleanly.** Task dispatch: always `aramb_tasks.update` (`status=done` on success, `status=failed` on any error) — never leave `in_progress`. Chat dispatch: confirm in your reply text. There is no task to close in chat dispatch.

## Run input & slug grounding — v2 contract

These rules apply to every node you author or carry forward — same contract as
`create-workflow`:

- **Per-run context arrives in `<run_input>`, not declared variables.** brahmi
  renders the user's instruction (manual run) or the trigger payload JSON (trigger
  run) into the **first step's** prompt as a `<run_input>` block. There are no
  input variables, no typed form, no `{{env.KEY}}` substitution. Write node prompts
  that tell the agent to read what it needs from the context it's given.
- **`<run_input>` is first-step-only.** Downstream steps see only their parent's
  `outputs.summary` + `outputs.files`. So step 1's prompt MUST instruct the agent
  to distill the relevant input into its summary for propagation. If you're adding
  a new entry node or changing which node is first, make sure that node funnels the
  input forward.
- **Empty input fails late, gracefully.** A step that gets an empty `<run_input>`
  should report "I don't have anything to work on" — no pre-flight gate.
- **Ground slugs before drafting.** Confirm toolkit slugs with
  `aramb_toolkits.list_toolkits` (and trigger slugs with
  `aramb_toolkits.list_triggers("<TOOLKIT>")` when relevant). Slugs are uppercase,
  verbatim from the catalog — never inferred from prose.

  ```bash
  npx mcporter call aramb_toolkits.list_toolkits
  npx mcporter call aramb_toolkits.list_triggers toolkit="GITHUB"
  ```

- **Migrating a legacy definition.** If `aramb_workflows.get` returns nodes with
  `{{env.…}}` placeholders or a non-empty `env_variables` map, treat that as debt
  to clear in this update: rewrite the placeholder prompts to read from
  `<run_input>`, drop `env_variables`, and add the per-node `toolkit` field. The
  update will be rejected otherwise.

## Path B — master, chat dispatch (no task_id): dispatch and exit

You were launched directly from chat instead of via the system-task dispatch, and
you have the `aramb_tasks.*` toolkit (team mode). **Do not design the workflow
inline.** Instead:

1. Look up the application's workflow:
   ```bash
   npx mcporter call aramb_workflows.get application_id="<APPLICATION_ID>"
   ```
2. **If a workflow exists** — dispatch a proper system task and exit:
   ```bash
   npx mcporter call aramb_workflows.update_from_tasks workflow_id="<WORKFLOW_ID_FROM_STEP_1>"
   ```
   Then write a one-line confirmation in your reply text (e.g. *"Starting workflow
   update, task &lt;id&gt;."*) and STOP. (Brahmi saves your final assistant text as
   the chat row.) The dispatched system task arrives separately and reloads this
   skill with the correct `workflow_id` + `task_id` (Path A).
3. **If no workflow exists** — tell the user there is no workflow to update yet and
   that they need to create one first (suggest the `create-workflow` skill). Do NOT
   design or create one in this turn.

Do not continue past this section — there is no `task_id` to close in Path B.

## Path A & C — author the update

### Step 1. Fetch the existing definition

```bash
npx mcporter call aramb_workflows.get workflow_id="<workflow_id>"
```

Chat dispatch (Path C): if you don't have a `workflow_id`, look it up by
application (each app has at most one workflow):

```bash
npx mcporter call aramb_workflows.get application_id="<application_id>"
```

If no workflow exists (Path C), tell the user there's nothing to update and suggest
they describe the workflow they want — you'll use `create-workflow` to build it.
Stop here.

The response is the full canvas: `name`, `description`, `env_variables`, `nodes`,
`edges`, `default_node_settings`, `stateful`, `status`, plus `schedule` if one is
configured. **Read it carefully — it's your starting point.** Don't throw it away
unless you have a reason.

### Step 2. Gather the change spec

**Path A (task dispatch) — fetch the completed tasks:**

```bash
npx mcporter call aramb_tasks.list \
  application_id="<application_id>" \
  status="done"
```

Same shape as create-workflow: ignore `task_kind == "system"`, consolidate
`task_kind == "user"` only.

Then **check the dispatched task description for a `User-supplied change request:`
section.** If present, that text is the user's verbatim instruction (e.g. *"add a
Slack DM step after the standup comment"*, *"remove the email triage step"*). Treat
it as a **first-class authoring signal** — apply it directly to the relevant
node(s), in addition to whatever the task corpus diff suggests. Without acting on
it, the user's ask vanishes silently. If no such section exists, you're in plain
regeneration mode (FE-button or "refresh the workflow" intent).

**Path C (chat dispatch, solo) — classify the user's message:**

- *Explicit change* ("add a Slack DM step", "remove the email triage", "change the synth step to also include the calendar"): use the user's message as the change spec verbatim. Skip ahead to step 4.
- *History-derived* (canned button message: "update the existing workflow based on the work done in this chat", or any phrasing pointing at the conversation as evidence): treat your conversation since the workflow was last saved as the evidence. Walk back and produce, in your reasoning: (a) new ordered steps you ran, (b) data hand-offs between them, (c) toolkits actually called, (d) one-off specifics vs the recurring shape. **Generalize, don't transcribe** — strip one-off dates / values; the workflow is a recipe.

### Step 3. Reject firing-condition change requests (schedule or trigger)

A workflow's *definition* and its *firing conditions* live in different storage
and different skills. If the change request is **solely** about when/why the
workflow fires, DO NOT call `aramb_workflows.update` — route it:

- **Cron / wall-clock timing** ("change the schedule to weekly", "stop the cron",
  "move it to UTC", "run it every Monday at 9am instead of Tuesday", "pause the
  schedule") → `schedule-workflow`. Cron fields live in flat columns on the
  workflow row.
- **Event trigger** ("fire it on a new GitHub issue too", "stop firing on pushes",
  "trigger when I get a Slack DM instead") → `configure-trigger`. Event triggers
  live in `workflow_triggers` rows.

Touching either through `aramb_workflows.update` regenerates the definition for
nothing and ignores the actual ask. Reject and route (the examples below use the
cron case; for an event condition, substitute `configure-trigger` for
`schedule-workflow`).

- **Path A (task dispatch):** close the task as failed so master routes correctly:
  ```bash
  npx mcporter call aramb_tasks.update \
    task_id="<your task_id>" \
    status="failed" \
    rejection_reason="schedule-shaped change request — dispatch schedule-workflow skill instead with workflow_id=<id> and the user's exact phrase"
  ```
- **Path C (chat dispatch, solo):** use the `schedule-workflow` skill (cron) or the
  `configure-trigger` skill (event) from your loadout directly. Send a one-line
  confirmation. Do not call `aramb_workflows.update` at all.

If the request is **mixed** (definition change + firing-condition change in one
sentence), apply the definition change per the rest of this skill, then: Path A —
add a `schedule_hint` (cron) or `trigger_hint` (event) to your closing `outputs`
so master dispatches the right skill next; Path C — call
`aramb_workflows.set_schedule` (cron) yourself, or use `configure-trigger` (event),
right after `aramb_workflows.update` succeeds.

### Step 4. Analyze the delta

Update progress: "Designing updated workflow — N nodes, M levels" (Path A: append a
`## Progress` bullet to the task description; Path C: narrate in your reply text).

#### Intent recognition for setting changes

Many change requests don't change the *graph* — they change a *setting*. Recognize the intent and apply at the right level. The defaults block is `default_node_settings` on the workflow; per-node deviations live in each node's `settings`. Workflow defaults inherit down; per-node values override.

| User phrase | Where to apply |
|---|---|
| "all steps should use Opus" / "switch the model to Opus" | `default_node_settings.model = "claude-opus-4-7"` (workflow) |
| "the synth step should use Opus" | that one node's `settings.model = "claude-opus-4-7"` (override) |
| "use Sonnet everywhere except the writer step, which should be Opus" | workflow `default_node_settings.model = "claude-sonnet-4-6"` AND that one node's `settings.model = "claude-opus-4-7"` |
| "give it a $50 budget" / "raise the budget to $50" | workflow-level `budget_usd = 50.0`. Cumulative cap across the whole run (passed to benji as `maxSessionCostUsd`). |
| "cap the synth step at $5" / per-step budget | Reject. Budget caps are workflow-level only. Reply: "Budget caps apply to the whole workflow run, not individual steps. I'll set the workflow budget to $5 if that's what you meant." |
| "this step shouldn't auto-approve" / "make me approve the email step" | that one node's `settings.approval_mode = "manual"` |
| "auto-approve everything" | workflow `default_node_settings.approval_mode = "auto"` AND clear `approval_mode` from any per-node `settings` overrides |
| "always respond in IST" / "use markdown for replies" / "cite sources" | `default_node_settings.instructions = "<phrase>"` (workflow) |
| "for this step, prefer concise bullets" | that one node's `settings.instructions = "<phrase>"` (appends to workflow-level) |
| "give it more turns" / "let each step go up to 80 turns" | `default_node_settings.max_turns = 80` (workflow) |
| "let the synth step take longer" | that one node's `settings.max_turns = 80` (override) |
| "turn extended thinking off" | `default_node_settings.thinking = "off"` (workflow) |
| "turn admin on" | `default_node_settings.admin = true` — only when the user explicitly asks. Off by default. |

**Inheritance model — be explicit in the user reply.** When you change a workflow
default, mention what it implies for nodes that had overrides ("Set the workflow
default to Opus and cleared the node override on the synth step so it inherits.").
When you set a node override, name the node ("Switched the synth step to Opus;
other steps still use the workflow default of Sonnet.").

**Don't touch settings the user didn't ask about.** Carry the existing
`default_node_settings` and per-node `settings` through unchanged from
`aramb_workflows.get` (step 1). Edit only the fields the user named.

#### Graph delta

Compare the existing definition against the change spec (task corpus + change
request, or the user's explicit change / chat work):
- New steps the change reflects that the existing graph doesn't have? Add nodes.
- Existing nodes obsolete now (user said remove, or new work supersedes them)? Drop them.
- Reworded step / changed logic? Update that node's `prompt`.
- Agent assignments changed? Update `assigned_agent` per node (see below).
- Toolkits changed? Update `required_toolkits` and the singular `toolkit` per node (grounded via `aramb_toolkits.list_toolkits`).
- Legacy `{{env.…}}` placeholders or declared `env_variables` carried over from the old definition? Clear them — rewrite the prompts to read from `<run_input>` and drop the `env_variables` map.

**Lean on the existing definition.** Resist rewriting from scratch. If 80% of the
graph is unchanged, keep 80% unchanged. The user already saw and accepted the
existing version; the change spec tells you *which* 20% to actually touch.

**`assigned_agent` handling:**
- *Path A (task dispatch):* update per node to match the (possibly new) task assignment; use existing team persona names.
- *Path C (chat dispatch, solo):* **read the existing `assigned_agent` verbatim from `aramb_workflows.get` and carry it forward on every node you keep.** Workflows imported from templates can be multi-persona (`developer`, `aramb-deployer`, …) even in a solo chat — do NOT blindly stamp `"solo"` across the graph. Set `assigned_agent: "solo"` only on nodes you author fresh in this update where no prior node exists to copy from AND the new work was clearly done by you (solo) in the chat. If a step the user is adding clearly belongs to an existing persona in the graph, reuse that persona's name.

**Same authoring rules as create-workflow:**
- Concrete prompts with real business context baked in. No generic templates. No `{{env.…}}` / `{{input.…}}` placeholders — per-run values arrive in `<run_input>` (step 1 only).
- **Each node `prompt` ends with the closing-instruction template** (below). If you carry an old node forward unchanged, verify it still has the template; if it pre-dates this rule, append it now.
- **The entry (first) node's prompt distills `<run_input>` into its `outputs.summary`** — if your delta changes which node runs first, make sure the new entry node funnels the input forward.
- **Each node carries `required_toolkits`** — never omit; `[]` for orchestration / file-only nodes. Ground slugs via `aramb_toolkits.list_toolkits`.
- **Each node that uses toolkits carries a singular `toolkit`** — its primary slug, a member of `required_toolkits`; omit (or `null`) when `required_toolkits` is `[]`.
- **Each node carries `settings`** — usually `{}`. Carry forward existing per-node overrides from `aramb_workflows.get`, plus or minus what the user is changing. Don't drop overrides the user didn't mention.
- **Carry forward `default_node_settings`** from the existing workflow, edited only where the user asked. If the existing block is empty / missing (older definitions), seed the same sensible defaults create-workflow uses (`model=claude-sonnet-4-6`, `effort=medium`, `thinking=adaptive`, `max_turns=35`, `admin=false`, `budget_usd=25.0`, `approval_mode=auto`, `instructions=""`).
- Sequential `unique_id` integers starting at 1 (numbering can differ from the existing version — uniqueness is what matters).
- Dependencies via the top-level `edges` array, never on nodes.
- **Do NOT declare `env_variables`** — omit the field; drop any the old definition carried.

## Closing instruction per node — MANDATORY

Every node's `prompt` MUST end with this exact block, with `<summary>` and `<files>` substituted to match what the node will actually produce. Non-negotiable, baked into every prompt at authoring time.

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
- `summary` is a paragraph the next agent reads as preamble — the hand-off vocabulary that makes the chain coherent. Keep it under 500 chars; focus on what's useful downstream.
- `files` is a list of paths (relative to the workspace working directory) the next agent reads to dig deeper. Empty array `[]` is correct when the node only sends a message / posts to an external service and produces no files.

Notes:
- The agent reads `project_id` and `step_id` from the User Message under "## Current Context" (`Project ID:` and `Workflow Run Step ID:` lines). Brahmi rejects cross-step writes (`context_drift`), so the agent must copy these verbatim into the close call — never re-use a stale UUID.
- Do NOT instruct the agent to call `aramb_tasks.update` from a workflow-step prompt — that targets the tasks domain (different DB rows) and the run will stall on the safety net. Only `aramb_workflows.update_step` closes a workflow run step.
- When carrying over node prompts from the existing definition, **re-verify the closing template is present and uses `update_step` with explicit IDs.** If the existing version pre-dates this rule (still references `update_my_step`), rewrite it now.

### Step 5. Call aramb_workflows.update

Update progress: "Saving updated workflow".

**Pre-flight checklist — verify before calling `aramb_workflows.update`.** For every node:

- `unique_id` — sequential integer starting at 1
- `name` — short label
- `prompt` — concrete instruction with business context baked in, **no `{{env.…}}` / `{{input.…}}` placeholders**, **AND ending with the closing-instruction template**. The entry node reads `<run_input>` and distills it into its summary.
- `assigned_agent` — Path A: existing team persona. Path C: carried verbatim from `aramb_workflows.get`, or `"solo"` / a provisioned sub-agent on freshly authored nodes.
- `acceptance_criteria` — how to know the step succeeded
- **`required_toolkits`** — copied from the source task / existing node, grounded via `aramb_toolkits.list_toolkits`; `[]` for orchestration / file-only nodes; never omit.
- **`toolkit`** — the primary slug; a member of `required_toolkits`; omit (or `null`) when `required_toolkits` is `[]`.
- **`settings`** — JSONB; preserve existing per-node overrides from `aramb_workflows.get`, edit only where the user asked; `{}` when the node has no overrides.

And on the call itself:

- **`default_node_settings`** — carry the existing block forward (or seed sensible defaults if empty), then apply any workflow-wide setting changes the user requested.
- **No `env_variables`** — omit the field; drop any the old definition declared (the schema rejects a non-empty map).

Bugs that silently break downstream behaviour, as fatal as in create-workflow:
1. Missing `required_toolkits` — kills Evaluate's missing-connection warnings.
2. `toolkit` not in `required_toolkits` (or missing on a toolkit-using node) — brahmi rejects the call.
3. A `{{env.KEY}}` / `{{input.KEY}}` placeholder in any prompt — brahmi rejects the call.
4. Missing closing instruction in `prompt` — outputs stay NULL, downstream sees "(no summary)" preamble.

**Each node's `prompt` should look like this (markdown, multi-line) before you JSON-encode it:**

```
Concrete instruction with the real business context baked in.

When done — record your output for the next step:
  npx mcporter call aramb_workflows.update_step \
    project_id="<your Project ID from User Message>" \
    step_id="<your Workflow Run Step ID from User Message>" \
    status="done" \
    outputs='{"summary":"<hand-off paragraph under 500 chars>","files":["<relative/path>"]}'

If you can't complete the step:
  npx mcporter call aramb_workflows.update_step \
    project_id="<your Project ID from User Message>" \
    step_id="<your Workflow Run Step ID from User Message>" \
    status="failed" \
    error="<concise reason>"
```

`aramb_workflows.update` skeleton (Path C, solo, would carry `"solo"` or a sub-agent on freshly authored nodes; Path A carries team personas — otherwise identical):

```bash
npx mcporter call aramb_workflows.update \
  workflow_id="<workflow_id>" \
  name="Updated Workflow Name" \
  description="What this workflow does in 1-2 sentences" \
  default_node_settings='{"model":"claude-opus-4-7","effort":"medium","thinking":"adaptive","max_turns":35,"admin":false,"budget_usd":50.0,"approval_mode":"auto","instructions":""}' \
  nodes='[
    {"unique_id": 1, "name": "First step",  "prompt": "<reads <run_input> + closing template>", "assigned_agent": "agent-name", "acceptance_criteria": "...", "required_toolkits": ["GMAIL"], "toolkit": "GMAIL", "settings": {}},
    {"unique_id": 2, "name": "Second step", "prompt": "<body + closing template>",            "assigned_agent": "agent-name", "acceptance_criteria": "...", "required_toolkits": [],        "settings": {"approval_mode":"manual"}}
  ]' \
  edges='[
    {"source": 1, "target": 2}
  ]'
```

The example shows a workflow whose user said "switch the model to Opus and raise the budget to $50, but make me approve step 2" — workflow-level changes land in `default_node_settings`, the per-step gating lands in node 2's `settings`.

`name`, `description`, `default_node_settings` are optional — omit them to keep existing values. Do NOT pass `env_variables` (omit it). `nodes` is required and must not be empty. `edges` may be `[]` for a single-node workflow.

**`required_toolkits` per node — always include it.** Copy the existing list from
the matching node in `aramb_workflows.get` (step 1), plus or minus what the user is
changing. If you omit it, brahmi falls back to the prior node's toolkits matched by
`name` — brittle across renames. Emit the field explicitly. `[]` only when the node
genuinely needs no toolkits.

The response includes:
- `workflow_id`, `status`, `node_count`, `message` (familiar from create)
- `stateful_continuity`: `"preserved"` or `"reset"`
- `stateful_reset_reason` (only when reset)
- `schedule_paused` + `schedule_paused_reason` (only when an enabled schedule was auto-paused due to env mismatch)

The response `status` is always `"draft"` after a successful update — brahmi demotes every updated workflow back to draft so the user re-publishes deliberately.

**Never retry `aramb_workflows.update`.** If the first call succeeds you're done. If it errors (bad payload, cycle in edges), close the task as failed (Path A) or tell the user the concise reason and stop (Path C) — don't retry silently. The original definition is intact on failure (the swap is atomic; rejection happens before it). Brahmi emits `workflow.update_failed` so the UI shows "Update failed, original kept".

### Step 6. Tell the user about side effects + setting changes

**Describe setting changes in inheritance terms** ("workflow default + per-node override"), so the user can predict behavior:
- workflow default change → "Set the workflow default model to Opus." (applies everywhere)
- per-node override → "Switched the synth step to Opus; other steps still use the workflow default of Sonnet."
- removing an override → "Cleared the node-level model override on the synth step so it inherits the workflow default."
- mixed → "Set the workflow default to Sonnet AND overrode the writer step to Opus."

If you only edited the graph (no settings touched), no settings line needed.

**Status is now `draft` — re-publish required.** Every successful update demotes the
workflow to `draft`, regardless of where it was before. The new definition is NOT
live until the user re-publishes (brahmi auto-evaluates toolkit connections at
publish time). Cron schedules do NOT fire from `draft`, so any scheduled workflow is
effectively paused until republish. Always surface this.

If `stateful_continuity` is `"reset"`: the workflow is `stateful=true` AND the new
entry node uses a different agent than before. The next stateful run starts a fresh
trunk. Mention it.

If `schedule_paused` is `true`: an enabled cron schedule was auto-paused because the
new env_variables no longer satisfy required keys. Tell the user the reason and that
they can resume once the env values are sorted out.

### Step 7. Close out

**Path A (task dispatch) — close the task.** On success, use the workflow_id from
the response:

```bash
npx mcporter call aramb_tasks.update \
  task_id="<your task_id>" \
  status="done" \
  outputs='{"workflow_id":"<workflow_id>","node_count":<number>,"summary":"Updated workflow: <one-line summary, in inheritance terms when settings were touched>. Status: draft (re-publish to put it live). Stateful chain: preserved | reset. Schedule: unchanged | paused."}'
```

If the user's request also contained a schedule-shaped phrase you didn't handle
(mixed intent), include `"schedule_hint":"User also asked to change the schedule:
\"<verbatim phrase>\". Dispatch schedule-workflow with workflow_id=<id>."` so master
dispatches `schedule-workflow` next.

On failure (aramb_tasks.list / aramb_workflows.get / aramb_workflows.update error,
cycle, invalid status):

```bash
npx mcporter call aramb_tasks.update \
  task_id="<your task_id>" \
  status="failed" \
  rejection_reason="<concise one-line reason>"
```

**CRITICAL: After calling `aramb_tasks.update`, STOP. Do not send any follow-up messages.**

**Path C (chat dispatch, solo) — confirm in chat.** Write a one-line confirmation in
your reply text (brahmi saves it as the chat row):

```
Updated workflow "<name>" — <one-line summary of what changed>. Status: draft (re-publish to put it live).
```

Include any side effects (stateful chain reset, schedule auto-paused) in the same
line. If the user's message was mixed (definition + schedule), call
`aramb_workflows.set_schedule` yourself right after `aramb_workflows.update` succeeds
and bundle the schedule into the same confirmation. Don't punt the schedule back to
the user. On error, tell the user the concise reason and stop — the original
definition is intact.

## Rules

- One shot: never call `aramb_workflows.update` twice. If the first call succeeded, you're done. If it errored, close as failed (Path A) or tell the user and stop (Path C).
- Each node's `prompt` carries real business context baked in.
- **Each node's `prompt` MUST end with the closing-instruction template** so the executing agent calls `aramb_workflows.update_step` (with the explicit `step_id` rendered into its dispatch User Message) at the end of its run. Without it, `outputs` stays NULL and the upstream-context hand-off chain shows "(no summary)".
- **Each node carries `required_toolkits`** — `[]` when the node touches no third-party service; never omit. Ground slugs via `aramb_toolkits.list_toolkits`.
- **Each toolkit-using node carries a singular `toolkit`** — its primary slug, a member of `required_toolkits`; omit (or `null`) when `required_toolkits` is `[]`.
- **No placeholder syntax in prompts** — no `{{env.KEY}}`, no `{{input.KEY}}`; brahmi rejects prompts containing `{{ env.… }}`. Per-run values arrive in `<run_input>` (step 1 only); rewrite any legacy placeholders carried over from the old definition.
- **Do NOT declare `env_variables`** — omit the field; drop any the old definition carried. The schema rejects a non-empty map; the column has no runtime path in v2.
- **The entry node's prompt distills `<run_input>` into its `outputs.summary`** — downstream steps never see `<run_input>`.
- **Each node carries `settings`** — preserve existing per-node overrides from `aramb_workflows.get`; `{}` when none.
- **Carry `default_node_settings`** forward unchanged from `aramb_workflows.get`, edited only where the user asked. Never silently drop the workflow defaults block.
- **Reject pure firing-condition change requests** — cron → route to `schedule-workflow`; event trigger → route to `configure-trigger`. Path A: close failed with a `rejection_reason` naming the skill. Path C: use that skill directly. Only call `aramb_workflows.update` for definition changes.
- **Apply setting changes at the right level**: workflow-wide phrases ("all steps" / "the workflow" / "everywhere") → `default_node_settings`. Single-step phrases ("the synth step" / "this step") → that one node's `settings` override.
- **Preserve per-node `assigned_agent` verbatim from `aramb_workflows.get`** — multi-persona workflows (template imports) keep their personas through updates. Stamp `"solo"` (Path C) only on freshly authored nodes with no existing counterpart.
- **For history-derived chat deltas, generalize the new work** — strip one-off dates / values from any new node prompts before adding them.
- `unique_id` values are sequential integers starting at 1.
- Dependencies live ONLY in the top-level `edges` array. Never on nodes.
- `edges` must be a DAG — no cycles.
- `assigned_agent` should match existing agent names.
- **Close out:** Path A — always `aramb_tasks.update` (`done` or `failed`), then STOP; never leave `in_progress`. Path C — confirm inline in your reply text (success or failure), always mention the `draft` re-publish step on success.
