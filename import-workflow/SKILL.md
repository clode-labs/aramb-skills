---
name: import-workflow
description: >
  Enrich a pre-created workflow draft for the current application — fetch the
  draft the platform already built from the template, polish its node prompts using
  the user's wizard answers, save the polish, and (if asked) set its schedule.
  The platform then auto-publishes and runs it. Use when the dispatch contains
  a <template-import> block in the extra-system-prompt. NOT for: consolidating
  completed tasks (use create-workflow), editing an arbitrary existing workflow
  (use update-workflow), or executing a workflow.
---

# Import Workflow

A template import is a **two-phase** flow and the platform has already done phase one
before you were dispatched:

- It **provisioned every template agent** into the agent runtime (identity / soul /
  agentsDoc / model / backend all baked from the template).
- It **created the draft workflow** for this application, with the template's
  nodes/edges and the wizard answers already substituted into the node prompts.
- It stamped the draft so that, **the moment this turn completes, the platform
  automatically publishes the workflow and fires its first run** — no manual
  publish, no manual trigger.

Your job (phase two) is the **enrichment polish**: fetch that draft, rewrite the
node prompts so the substituted prose reads naturally and carries the user's
intent, save the polish with `aramb_mcp.workflows_update`, optionally set a schedule,
then post a short summary and stop. You do **not** create agents and you do
**not** create a workflow — both already exist.

> **If asked to consolidate completed tasks into a new workflow, use the
> `create-workflow` skill. If asked to edit some other existing workflow, use
> `update-workflow`.** This skill is exclusively for the template-import path
> triggered by a `<template-import>` block from the platform.

## MUST rules — read before anything else

1. **This skill ONLY runs when the dispatch contains a `<template-import>`
   block.** If no such block is present in the extra-system-prompt, STOP — you
   should be using `create-workflow` or `update-workflow` instead. The block is
   the trigger; the user's prose alone does not authorise this path.
2. **The draft workflow ALREADY EXISTS. Do NOT call `aramb_mcp.workflows_create`.**
   The block carries a `workflow_id`. Fetch the draft with `aramb_mcp.workflows_get`
   and save your polish with `aramb_mcp.workflows_update`. Calling `create` will fork
   a second, duplicate workflow and fail ("a workflow already exists for this
   application").
3. **The agents ALREADY EXIST. Do NOT create them.** The platform provisioned every
   template agent before dispatching you — do NOT run `create-agent`, do NOT run
   `benji agent create`. The node `assigned_agent` references already resolve.
   Re-creating them clobbers the template's configuration (model/backend) with
   defaults and wastes a round-trip.
4. **Do NOT publish and do NOT trigger a run.** The platform auto-publishes the
   workflow and fires its first run automatically when this turn ends. Never
   tell the user to publish it, run it, or trigger anything manually, and do not
   wait for their confirmation.
5. **Do NOT call `aramb_mcp.tasks_list` / `aramb_mcp.tasks_update`.** No task drives this
   dispatch — the platform dispatched you (the master/solo agent) directly with the
   template payload. Calling them returns unrelated rows and misleads the import.
6. **Preserve structure; polish only text.** `aramb_mcp.workflows_update` replaces
   nodes + edges atomically, so you must send the FULL set back. You may rewrite
   each node's `name` / `prompt` (and the workflow `name` / `description`). You
   must NOT change `unique_id`, `assigned_agent`, `acceptance_criteria`,
   `settings`, `required_toolkits`, `toolkit`, the set of nodes, or any edge.
7. **Every node keeps its `required_toolkits` (use `[]`, never omit) and, when
   that array is non-empty, its singular `toolkit` (a member of it).** Copy both
   verbatim from the fetched draft. **Never invent a binding, and never use a
   platform-internal/hidden toolkit** (`composio`, `composio_search`,
   `browser_tool`, `slackbot`, `discord`, `discordbot`, `microsoft_teams`) —
   `aramb_mcp.workflows_update` rejects those; for Slack/Discord/Teams messaging the
   node delivers via the chat service's `chat.send_dm` (no toolkit). See the `aramb-workflows`
   skill.
8. **No placeholder syntax in any node `prompt`.** The draft's prompts should be
   literal (the platform already substituted). Do NOT introduce `{{env.KEY}}` /
   `{{input.KEY}}`; if a node still contains a literal `{{env.…}}` (a template
   bug), rewrite it to read its per-run value from `<run_input>`. The platform's MCP
   schema rejects prompts matching `{{ env.… }}`.
9. **Do NOT pass `env_variables`.** Omit it from `aramb_mcp.workflows_update` — v2
   templates declare none and a non-empty map is rejected.
10. **Speak to the user in plain product language — never leak internals.** No
    MCP tool names, raw upstream errors (`502` from the integrations proxy, `ConfigInvalid`),
    CLI names, or "the tool isn't in my surface." You have these tools — call
    them. Report real failures in human terms and stop.

You are running as the **master/solo agent**, not as a task. The
`<template-import>` block in your extra-system-prompt gives you:

- `slug` — the template's slug (e.g. `discovery-workflow`), on the opening tag.
- `workflow_id` — the UUID of the draft the platform already created, on the opening
  tag. This is what you pass to `aramb_mcp.workflows_get` / `aramb_mcp.workflows_update`.
- `<wizard-answers>` — JSON object of the user's wizard inputs (e.g.
  `team_name`, `channel_ids`, `lookback_days`) — use these to polish node
  prompts in step 3.

There is **no** `<agents>` array and **no** `<workflow>` body in the block — the
agents and the workflow already live server-side. Fetch the workflow to see its
current nodes/edges.

## System / appless imports (discovery & per-user system workflows)

Some template imports are **system workflows** — the canonical one is
`discovery-workflow` (the slug on the opening tag). The platform materializes these as
**project-scoped, appless** workflows in the user's **private project** (the
per-user DM project), not as a channel-app workflow in the public project:

- **No application binding.** The draft has `application_id = NULL` and is keyed
  by its `workflow_id` / lineage. Your `get` + `update` flow is keyed on
  `workflow_id`, so it works **unchanged** — never reach for an `application_id`
  to fetch or save a system workflow.
- **Output is DM-delivered.** A system workflow's final/delivery node reports to
  the user over their **DM**, via the chat service's `chat.send_dm` (no toolkit) — it must NOT
  post to a public channel-app. When you polish a delivery node, keep it on the
  DM path; do not rewrite it into a chat-service `chat.send_message`/channel post or bind
  a Slack toolkit. (The Discovery template already does this — "scan your channels
  and DM you a report.")
- **It lives in the private project.** Treat the report as a per-user artifact:
  per-user output, even when the source data is shared/public channels.

Everything else (polish text only, preserve structure, auto-publish) is identical
to an app-bound import.

## Output contract per node

End each polished node `prompt` with one short line naming what the next step
will find in this node's `outputs.summary` (≤500 chars, downstream-facing) and
`outputs.files` (workspace-relative paths).

Format `summary` as readable markdown — short headings or bullets where useful;
code-fence identifiers, file paths, IDs, and small JSON snippets. It renders in
the FE timeline for humans AND is parsed as preamble by the next agent.

Examples:

- `Outputs to next step: 'summary' is a per-channel table of message counts and topics; 'files' lists the .discovery/messages/*.json captures.`
- `Outputs to result: 'summary' is the top suggestions + the chat service's send_dm response (ok, ts); 'files' is the fallback report path if the DM failed.`

If a fetched node prompt ends with a stale `npx mcporter call
aramb_mcp.workflows_update_my_step …` block, strip it during polish and replace it
with the contract line above.

## Workflow

### 1. Parse the dispatch

Locate the `<template-import>` block in the extra-system-prompt. Extract:

- `slug` from the opening tag attribute
- `workflow_id` from the opening tag attribute
- The JSON object inside `<wizard-answers>` — raw user inputs

If the block is absent, STOP — this is the wrong skill. If the block is present
but malformed (no `slug`, no `workflow_id`, JSON parse error on wizard answers),
see "Error handling" below.

### 2. Fetch the draft

```bash
npx mcporter call aramb_mcp.workflows_get workflow_id="<workflow_id from the block>"
```

This returns the draft's `name`, `description`, `nodes` (each with `unique_id`,
`name`, `prompt`, `assigned_agent`, `acceptance_criteria`, `required_toolkits`,
`toolkit`, `settings`), and `edges`. This is your authoritative structure — you
will send it back, with only the text fields polished.

If `aramb_mcp.workflows_get` fails or returns no workflow for the id, see "Error
handling" (do NOT fall back to `create`).

### 3. Polish the node prompts (substantive — required when wizard answers are present)

When `<wizard-answers>` is non-empty, the fetched node prompts may read like Mad
Libs — the user's free-form answers were dropped into `{{placeholder}}` slots by
mechanical substitution. Rewrite them to read naturally, using both the wizard
answers and any extra context in the user's original chat message.

What "substantive polish" looks like:

- Smooth the substituted prose so it reads like a person wrote it, not a
  template engine: collapse a list-of-three answer into a natural clause, fix
  article agreement, restructure run-on sentences.
- Weave in the *meaning* of the wizard answers, not just the strings.
- Add brief, neutral context implied by the inputs when it helps the executing
  agent (e.g. "these are public ops channels; expect deploy chatter and alerts").
- Strip any stale `npx mcporter call aramb_mcp.workflows_update_my_step …` block and
  replace it with the one-line output contract above.
- Never introduce placeholder syntax — `{{env.KEY}}` / `{{input.KEY}}` are
  rejected. If a fetched prompt still has a literal `{{env.…}}`, rewrite it to
  read its per-run value from `<run_input>`.

What you MUST NOT change (carry every field back verbatim from the fetched
draft): `unique_id`, `assigned_agent`, `acceptance_criteria`, `settings`,
`required_toolkits`, `toolkit`, the set of nodes, and every edge.

When `<wizard-answers>` is empty (`{}`), polish is optional: only rewrite if the
fetched text is obviously broken. The stale-closing-block strip still applies.

### 4. Save the polish

Call `aramb_mcp.workflows_update` with the `workflow_id` and the FULL node + edge set
(it replaces atomically — a partial set deletes the rest):

```bash
npx mcporter call aramb_mcp.workflows_update \
  workflow_id="<workflow_id from the block>" \
  name="<workflow.name, polished — optional, omit to keep>" \
  description="<workflow.description, polished — optional, omit to keep>" \
  nodes='<full node set — name/prompt polished, everything else verbatim from the fetched draft>' \
  edges='<full edge set, verbatim from the fetched draft>'
```

**Pre-flight checklist — verify before calling `aramb_mcp.workflows_update`.** For
every node in your `nodes` array, confirm:

- `unique_id`, `assigned_agent`, `acceptance_criteria`, `settings` — present and
  unchanged from the fetched draft (verbatim)
- `name`, `prompt` — may carry your polish from step 3
- `required_toolkits` — present on every node, verbatim (use `[]`, never omit)
- `toolkit` — present on every node with non-empty `required_toolkits`, a member
  of it, verbatim
- `prompt` — carries business context + a one-line output contract, **no
  `{{env.…}}` / `{{input.…}}` placeholders**
- `edges` — the full set, verbatim
- `env_variables` — omit the field entirely

If `<wizard-answers>` is empty and the fetched prompts are already clean, you may
skip the update entirely — the draft is ready as-is and will still auto-publish.

### 5. Schedule (only if the dispatch asks)

If the user's message (or the template's accompanying instruction) asks for a
recurring schedule, set it on the SAME workflow:

```bash
npx mcporter call aramb_mcp.workflows_set_schedule \
  workflow_id="<workflow_id>" \
  cron_expression="<5-field cron, e.g. 0 */6 * * *>" \
  cron_timezone="UTC" \
  enabled="true"
```

If the template (or the user's request) carries a **randomized cadence** — fires
staggered off the exact tick rather than at a robotic time — pass the optional
cron-only args through: `random_delay_enabled=true` and, if the template specifies
a cap, `random_delay_max_minutes=<N>` (the delay is clamped to 80% of the gap to
the next tick). Omit both when the template's cadence is a plain cron. See the
`schedule-workflow` skill.

This configures the repeat cadence only. The **first** run still fires
immediately via auto-publish — do NOT trigger it yourself.

### 6. Post a chat summary

Post one short chat message naming the workflow and noting it's set up. Do NOT
say "publish it" or "trigger it" — the platform does both automatically.

```bash
npx mcporter call aramb_mcp.chat_send_message \
  project_id="<PROJECT_ID>" \
  application_id="<APPLICATION_ID>" \
  content="Set up the **Discovery Report** workflow — it'll scan your channels and DM you a report shortly, then refresh on schedule."
```

Use the `project_id` / `application_id` from your User Message's "## Current
Context" block. For a **system / appless import** — a system slug (e.g.
`discovery-workflow`) **and** no `application_id` in the context (see "System /
appless imports" above) — post with `project_id` only and omit `application_id`;
the message lands in the user's private-project chat. Decide "appless" from the
system slug, not the missing field alone. The
report itself still arrives via the workflow's DM delivery node — this summary is
just the acknowledgement.

After posting, STOP. Do not send follow-up messages.

## Error handling

- **`aramb_mcp.workflows_get` fails / returns no workflow for the id** → the draft
  the platform should have created is missing. Do NOT fall back to `create`. Post one
  chat message flagging it as a setup problem and STOP.

  ```bash
  npx mcporter call aramb_mcp.chat_send_message \
    project_id="<PROJECT_ID>" \
    application_id="<APPLICATION_ID>" \
    content="Couldn't finish setting up the workflow — its draft wasn't found. This is a setup issue on our side; please retry shortly."
  ```

- **`aramb_mcp.workflows_update` fails** → the draft still exists and will
  auto-publish with the unpolished (but functional) prompts. Post one chat
  message and STOP. No retry.

  ```bash
  npx mcporter call aramb_mcp.chat_send_message \
    project_id="<PROJECT_ID>" \
    application_id="<APPLICATION_ID>" \
    content="The workflow is set up and will run, but I couldn't apply my final polish to the steps: <reason>."
  ```

- **`<template-import>` block is malformed** (no `slug`, no `workflow_id`,
  invalid wizard-answers JSON) → post one chat message flagging the bug, then
  STOP. No `get`, no `update`.

  ```bash
  npx mcporter call aramb_mcp.chat_send_message \
    project_id="<PROJECT_ID>" \
    application_id="<APPLICATION_ID>" \
    content="Template import payload was malformed — this is a bug, please file it."
  ```

- **`<template-import>` block absent** → STOP immediately. Do not post a message;
  this skill simply does not apply. Master should route to `create-workflow` /
  `update-workflow` instead per its AGENTS.md.

## What this skill does NOT do

- Does NOT call `aramb_mcp.workflows_create` (the draft already exists — use
  `get` + `update`)
- Does NOT create agents / call `create-agent` / `benji agent create` (the platform
  already provisioned them)
- Does NOT publish the workflow or trigger a run (auto-publish does both on turn
  completion)
- Does NOT call `aramb_mcp.tasks_list` / `aramb_mcp.tasks_update` (no task drives this)
- Does NOT invoke any other agent
- Does NOT rewrite agent personas — only workflow node `name` / `prompt` text

## Rules

- Trigger is the `<template-import>` block in the extra-system-prompt — never the user's prose
- The draft workflow AND its agents already exist — `get` the workflow by `workflow_id`, never `create`, never `create-agent`
- Send the FULL node + edge set to `aramb_mcp.workflows_update` (it replaces atomically); polish only `name` / `prompt`, everything else verbatim
- Every node keeps `required_toolkits` (use `[]`, never omit) and its singular `toolkit` (a member of it) verbatim — never invent or use a hidden toolkit
- No placeholder syntax (`{{env.KEY}}` / `{{input.KEY}}`) in any prompt — the platform rejects it; per-run context reaches the first node via `<run_input>`
- Omit `env_variables` (the schema rejects a non-empty map)
- Every node's `prompt` carries business context + a one-line output contract
- Set a schedule with `aramb_mcp.workflows_set_schedule` only if the dispatch asks; never trigger the first run yourself
- Do NOT publish or trigger — the platform auto-publishes and runs the workflow on turn completion
- Post exactly one chat summary at the end (success or error); then STOP
- Never call `aramb_mcp.tasks_list`, `aramb_mcp.tasks_update`, or `aramb_mcp.workflows_create` from this skill
