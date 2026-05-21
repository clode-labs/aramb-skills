---
name: solo-update-workflow
description: >
  Update / refresh / regenerate / tweak an existing workflow — for solo agent.
  Triggered either by an explicit user change request ("add a Slack DM step",
  "remove the synth node") or by the canned button-driven message ("update
  the existing workflow based on the work done in this chat"). NOT for:
  dispatching as a task, consolidating completed tasks (use `update-workflow`
  in task mode instead), creating from scratch (use `solo-create-workflow`),
  or editing schedules (use `schedule-workflow`).
---

# Solo Update Workflow

You are solo. The user wants to change an existing workflow. The change spec
comes from one of two sources: an explicit description in their message, or
the new work you've done in this conversation since the workflow was last
saved. Identify which, then read the current definition, compute the delta,
and call `brahmi.update_workflow` once with the full replacement nodes +
edges set.

The workflow ALREADY exists. Brahmi will atomically swap the new definition
in when you call `update_workflow`. The old definition stays in effect until
that call succeeds — no half-states. In-flight runs continue against their
snapshot of the old definition.

## MUST rules — read before anything else

1. **Every node in `update_workflow` MUST carry `required_toolkits`.** Use `[]` (not omitted) when the node touches no third-party service. Omitting silently kills the Evaluate missing-connection warnings.
2. **Do NOT bake the `update_my_workflow_step` closing block into node prompts.** The workflow-step executor system prompt already mandates the closing call with full schema (summary ≤500 chars, files as relative paths, success vs failure shapes). Putting the same `npx mcporter call brahmi.update_my_workflow_step …` block into the node `prompt` duplicates the system prompt, bloats the recipe, and will drift the day the runtime calling convention changes. What each node prompt SHOULD spell out is the per-node **output contract** — one line at the end of the body describing what the next step should expect to find in `outputs.summary` and `outputs.files`. See "Output contract per node" below.
   - **Carrying forward existing nodes:** if you pull a node prompt forward from the previous workflow definition and it still contains a literal `npx mcporter call brahmi.update_my_workflow_step …` block (authored before this rule changed), STRIP that block out and replace it with a one-line output contract. Don't leave the literal mcporter block in — it'll re-pollute the recipe.
3. Call `update_workflow` exactly once. Success or failure — never retry.

## Output contract per node — describe what, not how

The workflow runtime owns the **mechanics** of closing a step. Every executing agent receives a system prompt (`workflow_step_executor_system_prompt`) that already mandates a final `update_my_workflow_step` call with `outputs.summary` (≤500 chars, downstream-facing) and `outputs.files` (workspace-relative paths). The user message template repeats the same contract in the per-step acceptance checklist.

That means **you do NOT need to author the `npx mcporter call brahmi.update_my_workflow_step …` block into the node `prompt`.** Doing so duplicates the system prompt, bloats every node, and creates a drift hazard the day the closing convention changes.

What each node prompt SHOULD carry, as a single short line at the end of the body, is the **per-node output contract** — what the next step is expected to read from this node's outputs. Examples:

- `Outputs to next step: 'summary' describes the N events you fetched and the date window covered; 'files' includes .planning/calendar.json.`
- `Outputs to next step: 'summary' is a one-paragraph hand-off naming the prospect cohort and qualifier; 'files' includes the leads CSV.`
- `Outputs to next step: 'summary' confirms the message was sent and includes the Gmail message id; 'files' is empty.`

When carrying over node prompts from the existing workflow definition, **re-verify the prompt does not contain a stale `npx mcporter call brahmi.update_my_workflow_step …` block.** Older definitions authored before this rule will. Strip it out and add a one-line output contract in its place — leaving the literal mcporter block in re-pollutes the recipe.

## Where the change spec comes from

You're running as solo in a regular chat dispatch. There's no `task_id`. The
change spec comes from one of:

- **(a) An explicit change** in the user's message — e.g. "add a Slack DM step", "remove the email triage", "change the synth step to also include the calendar". Use that as the change spec verbatim.
- **(b) New work done in this conversation** — when the user's message is the canned button phrase ("update the existing workflow based on the work done in this chat"). Treat your conversation since the existing workflow was last saved as the evidence: identify what new work happened, what was tried-and-discarded, which steps gained new logic, then design the delta.

The current workflow definition (your starting point either way) comes from
`brahmi.get_workflow` — see Step 1.

## Progress updates — keep the user in the loop

Stream short progress updates via `brahmi.send_message` at three checkpoints:
1. Restate what you understood **and which evidence source you're using** ("Updating <workflow name> from your description: adding a Slack DM step at the end" / "Consolidating updates from the work we did in this chat into <workflow name>").
2. When designing the delta ("New node count: 4. Reusing 3 existing nodes, adding 1.").
3. Just before save ("Saving updated workflow…").

```bash
npx mcporter call brahmi.send_message \
  message="<one-line update>" \
  chat_location="main"
```

Three messages is usually right. Don't spam.

## Workflow

### 1. Fetch the existing definition

```bash
npx mcporter call brahmi.get_workflow workflow_id="<workflow_id>"
```

If you don't already have a `workflow_id` in your context, list the
application's workflows first (the user typically refers to "the workflow" /
"my workflow" / by name):

```bash
npx mcporter call brahmi.list_workflows application_id="<application_id>"
```

If no workflow exists yet, tell the user there is nothing to update and
suggest they describe the workflow they want — you'll then use
`solo-create-workflow` to build it. Stop here.

The response from `get_workflow` is the full canvas: `name`, `description`,
`env_variables`, `nodes`, `edges`, `default_node_settings`, `stateful`,
`status`, plus `schedule` if one is configured. **Read it carefully — that is
your starting point.** Do not throw it away unless you have a reason.

### 2. Identify change-spec source, then gather it

**Classify the user's message:**

- *Explicit change* (e.g. "add a Slack DM step", "remove the email triage", "change the synth step to also include the calendar"): use the user's message as the change spec verbatim, same as today's task-mode `update-workflow`. Skip ahead to Step 3.
- *History-derived* (canned button message: "update the existing workflow based on the work done in this chat", "regenerate the workflow from what we just did", or any phrasing that points at the conversation as the evidence): treat your conversation since the existing workflow was last saved as the evidence. Identify what new work happened, what was tried-and-discarded, which steps gained new logic.

For history-derived intent, walk back through the conversation and produce, in your reasoning:

(a) what new ordered steps you ran since the last save,
(b) the explicit and implicit data hand-offs between them,
(c) the toolkits actually called,
(d) one-off specifics vs the recurring shape.

**Generalize, don't transcribe.** Same rule as `solo-create-workflow` — strip
one-off dates / values when carrying new work into node prompts. The
workflow is a recipe.

### 3. Reject schedule-shaped requests

If the user's message is solely about cron / timing ("change the schedule to
weekly", "stop the cron", "move it to UTC", "run it every Monday at 9am
instead of Tuesday", "pause the schedule"), DO NOT call `update_workflow`.
The cron fields live in a different storage column and have a dedicated skill
(`schedule-workflow`) — touching them through `update_workflow` regenerates
the definition for nothing and ignores the actual ask.

Use the `schedule-workflow` skill (already in your loadout) and call
`set_workflow_schedule` directly. Send the user a one-line confirmation when
done. Do not call `update_workflow` at all in this case.

If the request is **mixed** (definition change + schedule change in one
sentence), apply the definition change here per the rest of this skill, then
call `set_workflow_schedule` yourself right after `update_workflow` succeeds —
same pattern as `solo-create-workflow`.

### 4. Analyze the delta

Send a progress update describing what you're about to do.

The delta is the difference between the existing workflow definition and
either (a) the user's explicit change spec, or (b) the new work done in this
conversation. Read both, compute the change, design the new full nodes/edges
set:

- Are there new steps the user described (or that you ran in chat) that the existing graph doesn't have? Add nodes.
- Are some existing nodes obsolete now (the user said to remove them, or new chat work supersedes them)? Drop them.
- Did the user reword a step / did the new work change a step's logic? Update that node's `prompt`.
- Did agent assignments change? Update `assigned_agent` per node.
- Did env variables change? Drop unused ones, add new required ones.

**Lean on the existing definition.** Resist rewriting from scratch. If 80%
of the graph is unchanged, keep 80% of the graph unchanged. The user already
saw and accepted the existing version. The change spec tells you *which*
20% to actually touch. Carry forward node prompts and assignments unless
they need to change.

### Intent recognition for setting changes

Many change requests don't change the *graph* — they change a *setting*. Recognize the intent and apply the change at the right level. The defaults block is `default_node_settings` on the workflow; per-node deviations live in each node's `settings` field. Workflow defaults inherit down; per-node values override.

Common phrases and where they land:

| User phrase | Where to apply |
|---|---|
| "all steps should use Opus" / "switch the model to Opus" | `default_node_settings.model = "claude-opus-4-7"` (workflow) |
| "the synth step should use Opus" | that one node's `settings.model = "claude-opus-4-7"` (override) |
| "use Sonnet everywhere except the writer step, which should be Opus" | workflow `default_node_settings.model = "claude-sonnet-4-6"` AND that one node's `settings.model = "claude-opus-4-7"` |
| "give it a $50 budget" / "raise the budget to $50" | workflow-level `budget_usd = 50.0`. Cumulative cap across the whole run. |
| "cap the synth step at $5" / per-step budget | Reject. Budget caps are workflow-level only. Reply: "Budget caps apply to the whole workflow run, not individual steps. I'll set the workflow budget to $5 if that's what you meant." |
| "this step shouldn't auto-approve" / "make me approve the email step" | that one node's `settings.approval_mode = "manual"` |
| "auto-approve everything" | workflow `default_node_settings.approval_mode = "auto"` AND clear `approval_mode` from any per-node `settings` overrides |
| "always respond in IST" / "use markdown for replies" / "cite sources" | `default_node_settings.instructions = "<phrase>"` (workflow) |
| "for this step, prefer concise bullets" | that one node's `settings.instructions = "<phrase>"` |
| "give it more turns" / "let each step go up to 80 turns" | `default_node_settings.max_turns = 80` (workflow) |
| "let the synth step take longer" | that one node's `settings.max_turns = 80` (override) |
| "turn extended thinking off" | `default_node_settings.thinking = "off"` (workflow) |
| "turn admin on" | `default_node_settings.admin = true` — only when the user explicitly asks |

**Inheritance model — be explicit in the user reply.** When you change a
workflow default, mention what it implies for nodes that had overrides. When
you set a node override, name the node. The user's mental model of
"default + override" only holds if you describe changes in those terms.

**Don't touch settings the user didn't ask about.** Carry the existing
`default_node_settings` and per-node `settings` through unchanged from
`get_workflow` (Step 1). Edit only the fields the user named.

**Same authoring rules as `solo-create-workflow`:**
- Concrete prompts with real business context baked in. No generic templates.
- **Each node `prompt` ends with a one-line output contract** (see "Output contract per node" above). Do NOT bake the literal `npx mcporter call brahmi.update_my_workflow_step …` block into the node prompt — the runtime owns that mechanic. If you carry an old node forward unchanged, strip any stale mcporter block left over from older definitions and replace it with a one-line output contract.
- **Each node carries `required_toolkits`** — never omit; `[]` for orchestration / file-only nodes.
- **Each node carries `settings`** — usually `{}`. Carry forward any existing per-node overrides from the `get_workflow` response, plus or minus what the user is changing.
- **Carry forward `default_node_settings`** from the existing workflow, edited only where the user asked. If the existing workflow has an empty / missing block (older definitions), seed it with the same sensible defaults `solo-create-workflow` uses (`model=claude-sonnet-4-6`, `effort=medium`, `thinking=adaptive`, `max_turns=35`, `admin=false`, `budget_usd=25.0`, `approval_mode=auto`, `instructions=""`).
- Sequential `unique_id` integers starting at 1 (numbering can be different from the existing version — uniqueness is what matters).
- Dependencies via the top-level `edges` array, never on nodes. **Edge fields are `source`/`target` — not `from`/`to`.** You may see `from`/`to` referenced in the `aramb-templates` catalogue documentation; that's the template-publish path, a different layer. We're updating a workflow here (`update_workflow`), and brahmi's workflow storage uses `source`/`target`. Don't carry the template-doc shape over.
- Be stingy with env variables. Most workflows have zero, one, or two.
- For history-derived deltas, generalise the new work — strip one-off specifics from any new node prompts you add.

### 5. Call update_workflow

Send a progress update: "Saving updated workflow…".

**Pre-flight checklist — verify before calling update_workflow.** For every node:

- `unique_id` — sequential integer starting at 1
- `name` — short label
- `prompt` — concrete instruction with business context baked in **AND a one-line output contract** at the end describing what `outputs.summary` / `outputs.files` will contain. Do NOT include the `npx mcporter call brahmi.update_my_workflow_step …` block — the system prompt owns that mechanic. If you carried an old node forward, strip any stale mcporter block left over from older definitions.
- `assigned_agent` — name of an existing agent
- `acceptance_criteria` — how to know the step succeeded
- **`required_toolkits` — list of Composio slugs the node calls; `[]` for orchestration / file-only nodes; never omit.**
- **`settings` — JSONB; preserve existing per-node overrides from `get_workflow`, edit only where the user asked; `{}` when the node has no overrides.**

And on the call itself:

- **`default_node_settings`** — carry the existing block forward (or seed sensible defaults if empty), then apply any workflow-wide setting changes the user requested.

**Each node's `prompt` should look like this (markdown, multi-line) before you JSON-encode it:**

```
Concrete instruction with the real business context baked in.

Outputs to next step: 'summary' is a one-paragraph hand-off describing
<what>; 'files' includes <relative paths or '[]'>.
```

The instruction body (top paragraph) is per-node business context. The trailing `Outputs to next step:` line is the per-node output contract — identical structure across every node, only the description of `summary` / `files` content differs. The runtime injects the closing-call mechanics via the system prompt; you do not author them into the node `prompt`.

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

`name`, `description`, `env_variables`, `default_node_settings` are optional —
omit them to keep the existing values. `nodes` is required and must not be
empty. `edges` may be `[]` for a single-node workflow.

**`required_toolkits` per node — always include it.** Copy the existing list
from the matching node in `get_workflow` (Step 1), plus or minus whatever the
user is changing. If you omit the field, brahmi falls back to the prior
node's toolkits matched by `name`, but that fallback is brittle across
renames — emit the field explicitly. Use `[]` only when the node genuinely
needs no toolkits.

The response includes:
- `workflow_id`, `status`, `node_count`, `message`
- `stateful_continuity`: `"preserved"` or `"reset"`
- `stateful_reset_reason` (only when reset)
- `schedule_paused` + `schedule_paused_reason` (only when an enabled schedule was auto-paused due to env mismatch)

The response `status` will always be `"draft"` after a successful update —
brahmi demotes every updated workflow back to draft so the user can re-publish
deliberately.

**Never retry `update_workflow`.** If the first call succeeds, you're done.
If it errors out (bad payload, cycle in edges, etc.), tell the user the
concise reason and stop — don't retry silently.

### 6. Tell the user about side effects + setting changes

**Describe setting changes in inheritance terms.** The user's mental model of
these settings is "workflow default + per-node override." Frame your reply
that way so they can predict behavior:

- workflow default change → "Set the workflow default model to Opus." (one line, applies everywhere)
- per-node override → "Switched the synth step to Opus; other steps still use the workflow default of Sonnet."
- removing an override → "Cleared the node-level model override on the synth step so it inherits the workflow default."
- mixed → "Set the workflow default to Sonnet AND overrode the writer step to Opus."

If you only edited the graph (no settings touched), no settings line needed.

**Status is now `draft` — re-publish required.** Every successful update
demotes the workflow to `draft`, regardless of where it was before. The new
definition is NOT live until the user re-publishes (brahmi auto-evaluates
toolkit connections at publish time). Cron schedules do NOT fire from
`draft`, so any scheduled workflow is effectively paused until republish.
**Always mention this to the user** so they know to act.

If `stateful_continuity` is `"reset"`: the workflow is `stateful=true` AND
the new entry node uses a different agent than the previous one. The next
stateful run starts a fresh trunk. Mention this.

If `schedule_paused` is `true`: the workflow had an enabled cron schedule and
the new env_variables no longer satisfy required keys, so brahmi auto-paused
it. Tell the user the reason and that they can resume the schedule once the
env values are sorted out.

### 7. Confirm to the user

Send a one-line confirmation via `brahmi.send_message`:

```bash
npx mcporter call brahmi.send_message \
  message="Updated workflow \"<name>\" — <one-line summary of what changed>. Status: draft (re-publish to put it live)." \
  chat_location="main"
```

If there were side effects (stateful chain reset, schedule auto-paused),
include them in the same message.

If the user's message was mixed (definition change + schedule change), call
`set_workflow_schedule` yourself right after `update_workflow` succeeds and
bundle the schedule update into the same confirmation message. Don't punt
the schedule back to the user.

If `update_workflow` returned an error, tell the user the concise reason and
stop. The original definition is intact on failure — `update_workflow` is
atomic and any rejection happens before the swap.

## Rules

- One shot: never call `update_workflow` twice. If the first call succeeded, you're done. If it errored, tell the user and stop.
- Each node's `prompt` must carry the real business context baked in.
- **Each node's `prompt` ends with a one-line output contract** describing what `outputs.summary` / `outputs.files` will contain (see "Output contract per node" above). Do NOT bake the `npx mcporter call brahmi.update_my_workflow_step …` block into the node `prompt` — the workflow-step executor system prompt already mandates the closing call. When carrying old nodes forward, strip any stale mcporter block authored before this rule.
- **Each node carries `required_toolkits`** — `[]` when the node touches no third-party service; never omit.
- **Each node carries `settings`** — preserve existing per-node overrides from `get_workflow`; `{}` when the node has no overrides.
- **Carry `default_node_settings`** forward unchanged from `get_workflow`, edited only where the user asked. Never silently drop the workflow defaults block.
- **Reject pure schedule-shaped change requests** — use `schedule-workflow` instead. Only call `update_workflow` for definition changes.
- **Apply setting changes at the right level**: workflow-wide phrases like "all steps" / "the workflow" / "everywhere" → `default_node_settings`. Single-step phrases like "the synth step" / "this step" → that one node's `settings` override.
- **For history-derived deltas, generalise the new work** — strip one-off dates / values from any new node prompts before adding them.
- Only use `{{env.VARIABLE_NAME}}` for secrets, identity, or URLs — empty `env_variables` is the common case.
- `unique_id` values are sequential integers starting at 1.
- Dependencies live ONLY in the top-level `edges` array. Never on nodes.
- `edges` must be a DAG — no cycles.
- `assigned_agent` should match existing agent names.
- Confirm to the user via `brahmi.send_message` at the end (success or failure), and always mention the `draft` re-publish step on success.
