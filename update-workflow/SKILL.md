---
name: update-workflow
description: >
  Regenerate / refresh / tweak an existing workflow's definition. Works in two
  dispatch modes: (1) task dispatch — master regenerates from the application's
  user tasks (any status) plus any change request (system task with
  purpose=update-workflow); (2) chat dispatch — solo applies an explicit change
  request ("add a Slack DM step", "remove the synth node") or consolidates the
  work done so far in this chat.
  Use when: dispatched as a system task with purpose=update-workflow, OR when the
  user asks to refresh / update / regenerate / change the workflow. NOT for:
  creating a workflow from scratch (use create-workflow), polishing a template
  import (use import-workflow), executing a workflow, or editing schedules
  (use schedule-workflow).
---

# Update Workflow

Produce a fresh, full replacement node + edge set for an **existing** workflow,
taking the existing definition into account as a hint about what worked. The
workflow ALREADY exists — the platform atomically swaps the new definition in when you
call `aramb_mcp.workflows_update`. The old definition stays live until that call
succeeds; in-flight runs continue against their snapshot.

> **If asked to CREATE a workflow from scratch, use `create-workflow`. If polishing
> a template-import draft, use `import-workflow`.** This skill is update-only.

## Which dispatch mode am I in? — read this first

The `task_id` / `workflow_id` referred to here are **the platform's** ids from the
dispatch block — NOT Claude's built-in `TaskCreate`.

- **A) Task dispatch (you are master, dispatched as a system task).** Your "Your
  task id" block gives you `application_id`, `project_id`, `workflow_id`, and
  `task_id`. Regenerate from the application's user tasks — ALL statuses, read for
  intent (+ any user-supplied change request in the task description). Report
  progress on the task description; close with `aramb_mcp.tasks_update`. → Go to **Path
  A** below.
- **B) Chat dispatch, team mode (you have `aramb_mcp.tasks_*` tools but NO `task_id`).**
  You are master launched directly from chat. **Do not design the update inline.**
  Look up the workflow and dispatch a proper system task, then exit — the
  dispatched task re-enters this skill via Path A. → Go to **Path B** below.
- **C) Chat dispatch, solo (no `task_id`, and no `aramb_mcp.tasks_*` tools at all).**
  You are solo. Author the update directly from chat — an explicit change request
  or the work done so far in this conversation. Close by replying in chat. → Go to
  **Path C** below.

Paths A and C share all the authoring rules (analyze the delta, setting-change
intent recognition, closing template, pre-flight, the `aramb_mcp.workflows_update`
call, side-effects). They differ only in where the change spec comes from,
`assigned_agent` handling, and how you report progress / close out. Path B is a
short hand-off that does no authoring.

## MUST rules — read before anything else

1. **Every node in `aramb_mcp.workflows_update` MUST carry `required_toolkits`.** Copy the slugs from each source task's `required_toolkits` (task dispatch) or the matching node in `aramb_mcp.workflows_get` / the action it performs (chat dispatch). Use `[]` (not omitted) when the node touches no third-party service. Omitting silently kills the Evaluate missing-connection warnings. Ground slugs via `aramb_mcp.toolkits_list_toolkits` — don't trust a slug you can't see in the catalog. **Never invent a toolkit binding, and never bind a platform-internal/hidden toolkit** (`composio`, `composio_search`, `browser_tool`, `slackbot`, `discord`, `discordbot`, `microsoft_teams`) — `aramb_mcp.workflows_update` rejects those; for Slack/Discord/Teams messaging deliver via the chat service's `chat.send_dm` (no toolkit). See the `aramb-workflows` skill.
2. **Every node that touches a third-party service MUST carry a singular `toolkit`** — its primary toolkit slug, used for trigger-binding. Invariant the platform enforces: **`toolkit ∈ required_toolkits`.** Omit (or `null`) only when `required_toolkits` is `[]`. If the existing node had no `toolkit` (pre-v2 definition), add it now.
3. **No placeholder syntax in any node `prompt`.** No `{{env.KEY}}`, no `{{input.KEY}}`. There is no substitution layer; the platform **rejects** any prompt matching `{{ env.… }}`. If a node you carry forward from `aramb_mcp.workflows_get` still contains legacy `{{env.…}}` placeholders, **rewrite that prompt now** to read its per-run values from `<run_input>` (see "Run input & slug grounding — v2 contract" below).
4. **Do NOT declare `env_variables`.** Omit the field from the `aramb_mcp.workflows_update` call (leaving it out keeps nothing — there's no runtime path). If the existing definition declared `env_variables`, drop them: the schema rejects a non-empty map and the values were never read.
5. **Every node's `prompt` MUST end with the workflow-step closing instruction** so the executing agent calls `aramb_mcp.workflows_update_step` (with the explicit `step_id` rendered into its dispatch) at the end of its run. See "Closing instruction per node" below.
   - **Failure mode:** Without it, the agent finishes its LLM session, the platform's safety net auto-closes the step, but `outputs` stays NULL. The downstream step's `## Upstream context` preamble shows "(no summary)" instead of the real hand-off.
6. **Call `aramb_mcp.workflows_update` exactly once.** Success or failure — never retry.
7. **Close out cleanly.** Task dispatch: always `aramb_mcp.tasks_update` (`status=done` on success, `status=failed` on any error) — never leave `in_progress`. Chat dispatch: confirm in your reply text. There is no task to close in chat dispatch.
8. **Speak to the user in plain product language — never leak internals.** No MCP tool names (`aramb_mcp.workflows_update`), raw upstream errors (`502` from the integrations proxy), CLI names, or "the tool isn't in my surface." You have these tools — call them. Report real failures in human terms and stop.

## Run input & slug grounding — v2 contract

These rules apply to every node you author or carry forward — same contract as
`create-workflow`:

- **Per-run context arrives in `<run_input>`, not declared variables.** The platform
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
  `aramb_mcp.toolkits_list_toolkits` (and trigger slugs with
  `aramb_mcp.toolkits_list_triggers("<TOOLKIT>")` when relevant). Slugs are uppercase,
  verbatim from the catalog — never inferred from prose.

  ```bash
  npx mcporter call aramb_mcp.toolkits_list_toolkits
  npx mcporter call aramb_mcp.toolkits_list_triggers toolkit="GITHUB"
  ```

- **Migrating a legacy definition.** If `aramb_mcp.workflows_get` returns nodes with
  `{{env.…}}` placeholders or a non-empty `env_variables` map, treat that as debt
  to clear in this update: rewrite the placeholder prompts to read from
  `<run_input>`, drop `env_variables`, and add the per-node `toolkit` field. The
  update will be rejected otherwise.

## Path B — master, chat dispatch (no task_id): dispatch and exit

You were launched directly from chat instead of via the system-task dispatch, and
you have the `aramb_mcp.tasks_*` toolkit (team mode). **Do not design the workflow
inline.** Instead:

1. Look up the project's workflows and pick the one to update:
   ```bash
   npx mcporter call aramb_mcp.workflows_list project_id="<PROJECT_ID>"
   ```
   (A project can hold several workflows — appless is the norm; don't assume one
   per application. If more than one matches the user's intent, ask which.)
2. **If a workflow exists** — dispatch a proper system task and exit:
   ```bash
   npx mcporter call aramb_mcp.workflows_update_from_tasks workflow_id="<WORKFLOW_ID_FROM_STEP_1>"
   ```
   Then write a one-line confirmation in your reply text (e.g. *"Starting workflow
   update, task &lt;id&gt;."*) and STOP. (The platform saves your final assistant text as
   the chat row.) The dispatched system task arrives separately and reloads this
   skill with the correct `workflow_id` + `task_id` (Path A).
3. **If no workflow exists** — tell the user there is no workflow to update yet and
   that they need to create one first (suggest the `create-workflow` skill). Do NOT
   design or create one in this turn.

Do not continue past this section — there is no `task_id` to close in Path B.

## Path A & C — author the update

### Step 1. Fetch the existing definition

```bash
npx mcporter call aramb_mcp.workflows_get workflow_id="<workflow_id>"
```

Chat dispatch (Path C): if you don't have a `workflow_id`, find the project's
workflows and pick the one the user means (a project can hold several — appless
is the norm; if more than one matches, ask which):

```bash
npx mcporter call aramb_mcp.workflows_list project_id="<project_id>"
```

If no workflow exists (Path C), tell the user there's nothing to update and suggest
they describe the workflow they want — you'll use `create-workflow` to build it.
Stop here.

The response is the full canvas: `name`, `description`, `env_variables`, `nodes`,
`edges`, `default_node_settings`, `stateful`, `status`, plus `schedule` if one is
configured. **Read it carefully — it's your starting point.** Don't throw it away
unless you have a reason.

### Step 2. Gather the change spec

**Path A (task dispatch) — fetch the user tasks (ALL statuses):**

```bash
npx mcporter call aramb_mcp.tasks_list \
  application_id="<application_id>"
```

Same shape as create-workflow: **do NOT filter by `status="done"`** — read intent
from the whole user-task corpus regardless of success. Ignore
`task_kind == "system"`, read `task_kind == "user"` only.

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
workflow fires, DO NOT call `aramb_mcp.workflows_update` — route it:

- **Cron / wall-clock timing** ("change the schedule to weekly", "stop the cron",
  "move it to UTC", "run it every Monday at 9am instead of Tuesday", "pause the
  schedule", "stagger the fire time / don't run at exactly 9:00") → `schedule-workflow`.
  Cron fields — including the optional `random_delay_enabled` /
  `random_delay_max_minutes` jitter — live in flat columns on the workflow row.
- **Event trigger** ("fire it on a new GitHub issue too", "stop firing on pushes",
  "trigger when I get a Slack DM instead") → `configure-trigger`. Event triggers
  live in `workflow_triggers` rows.
- **Run-status callback** ("POST run status to my endpoint", "add/change the
  callback URL", "stop sending run webhooks") → set `callback_url` directly via
  `aramb_mcp.workflows_set_callback` (workflow-level config; see the `aramb-workflows`
  skill). This is NOT a definition change — do NOT call `aramb_mcp.workflows_update`
  for it. Path C: call `set_callback` yourself; Path A: close with a hint so master
  handles it.

Touching either through `aramb_mcp.workflows_update` regenerates the definition for
nothing and ignores the actual ask. Reject and route (the examples below use the
cron case; for an event condition, substitute `configure-trigger` for
`schedule-workflow`).

- **Path A (task dispatch):** close the task as failed so master routes correctly:
  ```bash
  npx mcporter call aramb_mcp.tasks_update \
    task_id="<your task_id>" \
    status="failed" \
    rejection_reason="schedule-shaped change request — dispatch schedule-workflow skill instead with workflow_id=<id> and the user's exact phrase"
  ```
- **Path C (chat dispatch, solo):** use the `schedule-workflow` skill (cron) or the
  `configure-trigger` skill (event) from your loadout directly. Send a one-line
  confirmation. Do not call `aramb_mcp.workflows_update` at all.

If the request is **mixed** (definition change + firing-condition change in one
sentence), apply the definition change per the rest of this skill, then: Path A —
add a `schedule_hint` (cron) or `trigger_hint` (event) to your closing `outputs`
so master dispatches the right skill next; Path C — call
`aramb_mcp.workflows_set_schedule` (cron) yourself, or use `configure-trigger` (event),
right after `aramb_mcp.workflows_update` succeeds.

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
| "give it a $50 budget" / "raise the budget to $50" | workflow-level `budget_usd = 50.0`. Cumulative cap across the whole run (passed to the agent runtime as `maxSessionCostUsd`). |
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
`aramb_mcp.workflows_get` (step 1). Edit only the fields the user named.

#### Graph delta

Compare the existing definition against the change spec (task corpus + change
request, or the user's explicit change / chat work):
- New steps the change reflects that the existing graph doesn't have? Add nodes.
- Existing nodes obsolete now (user said remove, or new work supersedes them)? Drop them.
- Reworded step / changed logic? Update that node's `prompt`.
- Agent assignments changed? Update `assigned_agent` per node (see below).
- Toolkits changed? Update `required_toolkits` and the singular `toolkit` per node (grounded via `aramb_mcp.toolkits_list_toolkits`).
- Legacy `{{env.…}}` placeholders or declared `env_variables` carried over from the old definition? Clear them — rewrite the prompts to read from `<run_input>` and drop the `env_variables` map.

**Lean on the existing definition.** Resist rewriting from scratch. If 80% of the
graph is unchanged, keep 80% unchanged. The user already saw and accepted the
existing version; the change spec tells you *which* 20% to actually touch.

**`assigned_agent` handling — one dedicated agent per node by its role, decided IDENTICALLY in solo and team (same model as create-workflow; mode never enters the decision):**
- *Existing nodes you keep (both paths):* **read the existing `assigned_agent` verbatim from `aramb_mcp.workflows_get` and carry it forward.** Workflows can be multi-persona (`developer`, `aramb-deployer`, a bespoke agent name, …) even in a solo chat — do NOT blindly stamp `"solo"` across the graph.
- *Freshly authored nodes:* exactly as create-workflow does. For each node, reuse a fitting existing agent (a persona already in the graph, a roster persona, or one you created in this update), otherwise **provision a bespoke agent via `create-agent`** named for its role, to the template-grade bar. This is the same in solo and team. Bare `"solo"` only for a trivial glue node.

**Same authoring rules as create-workflow:**
- Concrete prompts with real business context baked in. No generic templates. No `{{env.…}}` / `{{input.…}}` placeholders — per-run values arrive in `<run_input>` (step 1 only).
- **Each node `prompt` ends with the closing-instruction template** (below). If you carry an old node forward unchanged, verify it still has the template; if it pre-dates this rule, append it now.
- **The entry (first) node's prompt distills `<run_input>` into its `outputs.summary`** — if your delta changes which node runs first, make sure the new entry node funnels the input forward.
- **Each node carries `required_toolkits`** — never omit; `[]` for orchestration / file-only nodes. Ground slugs via `aramb_mcp.toolkits_list_toolkits`.
- **Each node that uses toolkits carries a singular `toolkit`** — its primary slug, a member of `required_toolkits`; omit (or `null`) when `required_toolkits` is `[]`.
- **Each node carries `settings`** — usually `{}`. Carry forward existing per-node overrides from `aramb_mcp.workflows_get`, plus or minus what the user is changing. Don't drop overrides the user didn't mention.
- **Carry forward `default_node_settings`** from the existing workflow, edited only where the user asked. If the existing block is empty / missing (older definitions), seed the same sensible defaults create-workflow uses (`model=claude-sonnet-4-6`, `effort=medium`, `thinking=adaptive`, `max_turns=35`, `admin=false`, `budget_usd=25.0`, `approval_mode=auto`, `instructions=""`).
- Sequential `unique_id` integers starting at 1 (numbering can differ from the existing version — uniqueness is what matters).
- Dependencies via the top-level `edges` array, never on nodes.
- **Do NOT declare `env_variables`** — omit the field; drop any the old definition carried.

## Closing instruction per node — MANDATORY

Every node's `prompt` MUST end with this exact block, with `<summary>` and `<files>` substituted to match what the node will actually produce. Non-negotiable, baked into every prompt at authoring time.

```
When done — record your output for the next step:
  npx mcporter call aramb_mcp.workflows_update_step \
    project_id="<your Project ID from User Message>" \
    step_id="<your Workflow Run Step ID from User Message>" \
    status="done" \
    outputs='{"summary":"<one-paragraph hand-off, under 500 chars>","files":["relative/path/to/output.json"]}'

If you can't complete the step:
  npx mcporter call aramb_mcp.workflows_update_step \
    project_id="<your Project ID from User Message>" \
    step_id="<your Workflow Run Step ID from User Message>" \
    status="failed" \
    error="<concise reason + any partial progress>"
```

Why both `summary` and `files`:
- `summary` is a paragraph the next agent reads as preamble — the hand-off vocabulary that makes the chain coherent. Keep it under 500 chars; focus on what's useful downstream.
- `files` is a list of paths (relative to the workspace working directory) the next agent reads to dig deeper. Empty array `[]` is correct when the node only sends a message / posts to an external service and produces no files.

Notes:
- The agent reads `project_id` and `step_id` from the User Message under "## Current Context" (`Project ID:` and `Workflow Run Step ID:` lines). The platform rejects cross-step writes (`context_drift`), so the agent must copy these verbatim into the close call — never re-use a stale UUID.
- Do NOT instruct the agent to call `aramb_mcp.tasks_update` from a workflow-step prompt — that targets the tasks domain (different DB rows) and the run will stall on the safety net. Only `aramb_mcp.workflows_update_step` closes a workflow run step.
- When carrying over node prompts from the existing definition, **re-verify the closing template is present and uses `update_step` with explicit IDs.** If the existing version pre-dates this rule (still references `update_my_step`), rewrite it now.

### Step 4.5. Browser-login pre-check — scoped to changed/added nodes

Same hard gate as create-workflow, but only over the nodes this update **adds or
changes** (an untouched node's login was already gated when it was created):

- For each added/changed node whose `required_toolkits` includes `aramb-browser`
  AND whose `prompt` names a known-login site (`linkedin.com`, `github.com`,
  `twitter.com`/`x.com`, `gmail.com`/`mail.google.com`, `reddit.com`, `notion.so`,
  `slack.com`, `discord.com`, `instagram.com`), infer the `<site>-login` context
  name and check it with `npx mcporter call aramb-browser.browser_context_list`.
- **Slot present** → proceed; mention "I'll use your existing `<site>` login."
- **Slot missing** → do NOT call `aramb_mcp.workflows_update`. Surface the canonical
  aramb-browser login flow (`browser_context_create` → log in → `browser_save_context`,
  context_name=`<site>-login`) and STOP until the slot exists. No bypass.
- If the update *removes* the last browser-login node for a site, no check is
  needed — the dependency is gone.

### Step 4.6. Trigger review when the entry toolkit changes

Unlike create, `aramb_mcp.workflows_update` does NOT take a `trigger_choice` — the
firing condition is managed separately (Step 3 routes explicit schedule/trigger
change requests to `schedule-workflow` / `configure-trigger`). But one delta
silently breaks an existing trigger: **changing the entry node's `toolkit`** (the
slug an event trigger binds against). If this update changes which toolkit the
entry node uses:

- Check whether a trigger exists (`aramb_mcp.workflows_get` surfaces the schedule;
  for event triggers, the workflow's trigger rows). If a `toolkit_event` trigger
  is bound to the *old* toolkit, it no longer matches the new entry toolkit.
- Tell the user via `aramb_mcp.chat_ask_question` that the trigger needs to change,
  and run the same picker shape create-workflow uses (list_triggers for the new
  toolkit → recommend → cron/manual options). On their answer, re-wire via
  `configure-trigger` (event) or `set_schedule` (cron) after the update saves.

If the entry toolkit is unchanged, leave the trigger alone — don't reconfigure a
working trigger the user didn't ask to touch.

### Step 5. Call aramb_mcp.workflows_update

Update progress: "Saving updated workflow".

**Pre-flight checklist — verify before calling `aramb_mcp.workflows_update`.** For every node:

- `unique_id` — sequential integer starting at 1
- `name` — short label
- `prompt` — concrete instruction with business context baked in, **no `{{env.…}}` / `{{input.…}}` placeholders**, **AND ending with the closing-instruction template**. The entry node reads `<run_input>` and distills it into its summary.
- `assigned_agent` — kept nodes: carry the existing persona verbatim from `aramb_mcp.workflows_get` (both paths). Freshly authored nodes: one dedicated agent per node by its role, decided identically in solo and team — reuse a fitting existing agent (roster persona / persona already in the graph), else **provision a bespoke agent via `create-agent`** named for its role. Bare `"solo"` only for a trivial glue node. Never `null` or empty.
- `acceptance_criteria` — how to know the step succeeded
- **`required_toolkits`** — copied from the source task / existing node, grounded via `aramb_mcp.toolkits_list_toolkits`; `[]` for orchestration / file-only nodes; never omit.
- **`toolkit`** — the primary slug; a member of `required_toolkits`; omit (or `null`) when `required_toolkits` is `[]`.
- **`settings`** — JSONB; preserve existing per-node overrides from `aramb_mcp.workflows_get`, edit only where the user asked; `{}` when the node has no overrides.

And on the call itself:

- **`default_node_settings`** — carry the existing block forward (or seed sensible defaults if empty), then apply any workflow-wide setting changes the user requested.
- **No `env_variables`** — omit the field; drop any the old definition declared (the schema rejects a non-empty map).

Bugs that silently break downstream behaviour, as fatal as in create-workflow:
1. Missing `required_toolkits` — kills Evaluate's missing-connection warnings.
2. `toolkit` not in `required_toolkits` (or missing on a toolkit-using node) — the platform rejects the call.
3. A `{{env.KEY}}` / `{{input.KEY}}` placeholder in any prompt — the platform rejects the call.
4. Missing closing instruction in `prompt` — outputs stay NULL, downstream sees "(no summary)" preamble.

**Each node's `prompt` should look like this (markdown, multi-line) before you JSON-encode it:**

```
Concrete instruction with the real business context baked in.

When done — record your output for the next step:
  npx mcporter call aramb_mcp.workflows_update_step \
    project_id="<your Project ID from User Message>" \
    step_id="<your Workflow Run Step ID from User Message>" \
    status="done" \
    outputs='{"summary":"<hand-off paragraph under 500 chars>","files":["<relative/path>"]}'

If you can't complete the step:
  npx mcporter call aramb_mcp.workflows_update_step \
    project_id="<your Project ID from User Message>" \
    step_id="<your Workflow Run Step ID from User Message>" \
    status="failed" \
    error="<concise reason>"
```

`aramb_mcp.workflows_update` skeleton (kept nodes carry their existing persona verbatim; freshly authored nodes carry a bespoke agent, a roster persona, or `"solo"` per the work — otherwise identical across paths):

```bash
npx mcporter call aramb_mcp.workflows_update \
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
the matching node in `aramb_mcp.workflows_get` (step 1), plus or minus what the user is
changing. If you omit it, the platform falls back to the prior node's toolkits matched by
`name` — brittle across renames. Emit the field explicitly. `[]` only when the node
genuinely needs no toolkits.

The response includes:
- `workflow_id`, `status`, `node_count`, `message` (familiar from create)
- `stateful_continuity`: `"preserved"` or `"reset"`
- `stateful_reset_reason` (only when reset)
- `schedule_paused` + `schedule_paused_reason` (only when an enabled schedule was auto-paused due to env mismatch)

The response `status` is always `"draft"` after a successful update — an updated workflow returns to draft so the change ships deliberately. A workflow is part of its owning agent (whether it was created with `agent_id` or later attached via `aramb_mcp.agents_attach_workflow` — same end state) and has no publish step of its own: the draft goes live automatically when the **agent** is (re-)published (`aramb_mcp.agents_publish`) — **but only if the workflow's required toolkits are connected.** A workflow whose steps need third-party toolkits (Gmail, Slack…) is published with the agent ONLY once those toolkits are **CONNECTED**; otherwise it stays a draft and the publish response reports it as blocked, naming the missing toolkits. Test the draft via Preview (`aramb_mcp.workflows_run` works on the draft) in the meantime; never call a workflow-publish tool yourself.

**Never retry `aramb_mcp.workflows_update`.** If the first call succeeds you're done. If it errors (bad payload, cycle in edges), close the task as failed (Path A) or tell the user the concise reason and stop (Path C) — don't retry silently. The original definition is intact on failure (the swap is atomic; rejection happens before it). The platform emits `workflow.update_failed` so the UI shows "Update failed, original kept".

### Step 6. Tell the user about side effects + setting changes

**Describe setting changes in inheritance terms** ("workflow default + per-node override"), so the user can predict behavior:
- workflow default change → "Set the workflow default model to Opus." (applies everywhere)
- per-node override → "Switched the synth step to Opus; other steps still use the workflow default of Sonnet."
- removing an override → "Cleared the node-level model override on the synth step so it inherits the workflow default."
- mixed → "Set the workflow default to Sonnet AND overrode the writer step to Opus."

If you only edited the graph (no settings touched), no settings line needed.

**Status is now `draft` — goes live when the AGENT is published.** Every successful
update returns the workflow to `draft`, regardless of where it was before. The new
definition is NOT live until the owning **agent** is (re-)published
(`aramb_mcp.agents_publish`) — there is no separate workflow-publish step, and you must
not call one. **And if this workflow's steps require third-party toolkits, it goes
live at publish ONLY once those toolkits are CONNECTED** — otherwise it stays a draft
and the publish response flags it as blocked with the missing toolkit names. So if the
workflow needs a toolkit the user hasn't connected, tell them plainly to connect it on
the **Integrations** page before publishing the agent (verify with
`aramb_mcp.toolkits_check_connection`). The builder can Preview / `aramb_mcp.workflows_run` the
draft to test it now. Cron schedules fire from the live (published) version, so a
scheduled workflow runs the previous published definition until the agent is
re-published. Always surface this.

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
npx mcporter call aramb_mcp.tasks_update \
  task_id="<your task_id>" \
  status="done" \
  outputs='{"workflow_id":"<workflow_id>","node_count":<number>,"summary":"Updated workflow: <one-line summary, in inheritance terms when settings were touched>. Status: draft (publish the agent to put it live). Stateful chain: preserved | reset. Schedule: unchanged | paused."}'
```

If the user's request also contained a schedule-shaped phrase you didn't handle
(mixed intent), include `"schedule_hint":"User also asked to change the schedule:
\"<verbatim phrase>\". Dispatch schedule-workflow with workflow_id=<id>."` so master
dispatches `schedule-workflow` next.

On failure (aramb_mcp.tasks_list / aramb_mcp.workflows_get / aramb_mcp.workflows_update error,
cycle, invalid status):

```bash
npx mcporter call aramb_mcp.tasks_update \
  task_id="<your task_id>" \
  status="failed" \
  rejection_reason="<concise one-line reason>"
```

**CRITICAL: After calling `aramb_mcp.tasks_update`, STOP. Do not send any follow-up messages.**

**Path C (chat dispatch, solo) — confirm in chat.** Write a one-line confirmation in
your reply text (the platform saves it as the chat row):

```
Updated workflow "<name>" — <one-line summary of what changed>. Status: draft (goes live when you publish the agent).
```

Include any side effects (stateful chain reset, schedule auto-paused) in the same
line. If the user's message was mixed (definition + schedule), call
`aramb_mcp.workflows_set_schedule` yourself right after `aramb_mcp.workflows_update` succeeds
and bundle the schedule into the same confirmation. Don't punt the schedule back to
the user. On error, tell the user the concise reason and stop — the original
definition is intact.

## Rules

- One shot: never call `aramb_mcp.workflows_update` twice. If the first call succeeded, you're done. If it errored, close as failed (Path A) or tell the user and stop (Path C).
- Each node's `prompt` carries real business context baked in.
- **Each node's `prompt` MUST end with the closing-instruction template** so the executing agent calls `aramb_mcp.workflows_update_step` (with the explicit `step_id` rendered into its dispatch User Message) at the end of its run. Without it, `outputs` stays NULL and the upstream-context hand-off chain shows "(no summary)".
- **Each node carries `required_toolkits`** — `[]` when the node touches no third-party service; never omit. Ground slugs via `aramb_mcp.toolkits_list_toolkits`.
- **Each toolkit-using node carries a singular `toolkit`** — its primary slug, a member of `required_toolkits`; omit (or `null`) when `required_toolkits` is `[]`.
- **No placeholder syntax in prompts** — no `{{env.KEY}}`, no `{{input.KEY}}`; the platform rejects prompts containing `{{ env.… }}`. Per-run values arrive in `<run_input>` (step 1 only); rewrite any legacy placeholders carried over from the old definition.
- **Do NOT declare `env_variables`** — omit the field; drop any the old definition carried. The schema rejects a non-empty map; the column has no runtime path in v2.
- **The entry node's prompt distills `<run_input>` into its `outputs.summary`** — downstream steps never see `<run_input>`.
- **Each node carries `settings`** — preserve existing per-node overrides from `aramb_mcp.workflows_get`; `{}` when none.
- **Carry `default_node_settings`** forward unchanged from `aramb_mcp.workflows_get`, edited only where the user asked. Never silently drop the workflow defaults block.
- **Reject pure firing-condition change requests** — cron → route to `schedule-workflow`; event trigger → route to `configure-trigger`. Path A: close failed with a `rejection_reason` naming the skill. Path C: use that skill directly. Only call `aramb_mcp.workflows_update` for definition changes.
- **Apply setting changes at the right level**: workflow-wide phrases ("all steps" / "the workflow" / "everywhere") → `default_node_settings`. Single-step phrases ("the synth step" / "this step") → that one node's `settings` override.
- **Preserve per-node `assigned_agent` verbatim from `aramb_mcp.workflows_get`** — multi-persona workflows keep their personas through updates. For freshly authored nodes, give each its own dedicated agent by role (identically in solo and team): reuse a fitting existing agent, else provision a bespoke one via `create-agent`. Bare `"solo"` only for a trivial glue node.
- **For history-derived chat deltas, generalize the new work** — strip one-off dates / values from any new node prompts before adding them.
- `unique_id` values are sequential integers starting at 1.
- Dependencies live ONLY in the top-level `edges` array. Never on nodes.
- `edges` must be a DAG — no cycles.
- `assigned_agent` should match existing agent names.
- **Close out:** Path A — always `aramb_mcp.tasks_update` (`done` or `failed`), then STOP; never leave `in_progress`. Path C — confirm inline in your reply text (success or failure), always mention on success that the update is a `draft` that goes live when the agent is published (once its required toolkits are connected; no separate workflow-publish step).
