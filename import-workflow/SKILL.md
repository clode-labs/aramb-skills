---
name: import-workflow
description: >
  Materialize a pre-defined workflow template into the current application —
  create each template agent via the create-agent skill, polish the node
  prompts using the user's wizard answers, then save the workflow. Use when
  the dispatch contains a <template-import> block in the extra-system-prompt.
  NOT for: consolidating completed tasks (use create-workflow), editing an
  existing workflow (use update-workflow), or executing a workflow.
---

# Import Workflow

Materialize a pre-defined workflow template into the current application. The
template ships pre-resolved nodes and edges (placeholders already substituted
by brahmi) and full agent specs (name, identity, soul, agentsDoc, default
model/backend/thinking, required toolkits). Your job: create each agent via
the `create-agent` skill, substantively polish the node prompts using the
user's wizard answers, then call `aramb_workflows.create` exactly once.

> **If asked to consolidate completed tasks into a new workflow instead, use
> the `create-workflow` skill. If asked to edit an existing workflow, use
> `update-workflow`.** This skill is exclusively for the template-import path
> triggered by a `<template-import>` block from brahmi.

## MUST rules — read before anything else

1. **This skill ONLY runs when the dispatch contains a `<template-import>`
   block.** If no such block is present in the extra-system-prompt, STOP — you
   should be using `create-workflow` or `update-workflow` instead. The block is
   the trigger; the user's prose alone does not authorise this path.
2. **Do NOT call `aramb_tasks.list` and do NOT call `aramb_tasks.update`.** There is no
   task driving this skill. Brahmi's QueueConsumer dispatches the master agent
   directly with the template payload; tasks are not part of the
   template-import flow. Calling `aramb_tasks.list` returns unrelated tasks and
   misleads the import; calling `aramb_tasks.update` resolves no task because none
   was opened.
3. **You MUST create every agent listed in `<agents>` via the `create-agent`
   skill before calling `aramb_workflows.create`.** Brahmi no longer pre-provisions
   them — the template ships agent specs in the dispatch, and you are the one
   who lands them in benji. If you skip this step the workflow will save with
   `assigned_agent` references that don't resolve, and every run will fail at
   dispatch with "agent not found". One `create-agent` invocation per spec,
   in the order the specs appear in the `<agents>` array.
4. **`aramb_workflows.create` MUST be called exactly once.** Success or failure — never
   retry. The pre-resolved nodes/edges in the `<template-import>` block are
   the authoritative *structure*; your polish (step 3 below) may rewrite
   `name` / `prompt` / `description` text but must not change the graph.
5. **Every node in the `aramb_workflows.create` call MUST carry `required_toolkits`**
   copied verbatim from the matching node in the `<template-import>` block.
   Use `[]` (not omitted) when a node touches no third-party service. Same
   failure mode as `create-workflow`: omitting kills the Evaluate
   missing-connection warnings and renders the Required-toolkits row empty in
   the FE node panel.
6. **Strip stale closing blocks during polish.** If a template-shipped node prompt ends with a literal `npx mcporter call aramb_workflows.update_my_step …` block, strip it during polish (step 3) and replace it with a one-line output contract describing what `outputs.summary` / `outputs.files` should contain for the next step. See "Output contract per node" below.

You are running as the **master agent**, not as a task. Brahmi dispatched the
chat message with an extra-system-prompt block named `<template-import>` that
gives you everything you need:

- `slug` — the template's slug (e.g. `gtm-team`)
- `<agents>` — JSON array of full agent specs to create via `create-agent`
- `<wizard-answers>` — JSON object of the user's wizard inputs
  (e.g. `company_name`, `company_description`, `ideal_customer`) — use these
  to polish node prompts in step 3
- `<workflow>` — the resolved workflow JSON (`name`, `description`, `nodes`,
  `edges`, `default_node_settings`, `budget_usd`, `stateful`). Placeholders
  are already substituted, but the resulting prose may read like a Mad Lib;
  step 3 fixes that.

**The workflow does NOT exist yet.** Brahmi creates it atomically when you
call `aramb_workflows.create`. Don't ask for a workflow_id — you don't have one and
don't need one.

## Output contract per node

End each polished node `prompt` with one short line naming what the next step will find in this node's `outputs.summary` (≤500 chars, downstream-facing) and `outputs.files` (workspace-relative paths).

Format `summary` as readable markdown — short headings or bullets where useful; code-fence identifiers, file paths, IDs, and small JSON snippets. It renders directly in the FE timeline for humans AND is parsed as preamble by the next agent, so both audiences benefit from the same structure. Avoid wall-of-text paragraphs; lead with the key facts.

Examples:

- `Outputs to next step: 'summary' describes the qualified prospect cohort with fit/intent scoring; 'files' includes the leads CSV.`
- `Outputs to next step: 'summary' confirms the email sequence was queued and lists the recipient ids; 'files' is empty.`

If the template ships a node prompt with a literal `npx mcporter call aramb_workflows.update_my_step …` block tacked onto the bottom, strip it during polish (step 3) and replace it with the contract line above.

## Workflow

### 1. Parse the dispatch

Locate the `<template-import>` block in the extra-system-prompt. Extract:

- `slug` from the opening tag attribute
- The JSON array inside `<agents>` — full agent specs
- The JSON object inside `<wizard-answers>` — raw user inputs
- The JSON object inside `<workflow>` — the resolved workflow definition

If the block is absent, STOP — this is the wrong skill. If the block is
present but malformed (missing `slug`, missing `<workflow>`, JSON parse
error, missing required workflow fields), see "Error handling" below.

### 2. Create the agents

For each spec in the `<agents>` array, invoke the `create-agent` skill with
that spec's fields mapped onto the create-agent input shape:

| `<agents>` spec field | `create-agent` input |
|-----------------------|----------------------|
| `name`                | `name`               |
| `identity`            | folds into IDENTITY.md content (use verbatim, no rewriting) |
| `soul`                | folds into SOUL.md content (use verbatim, no rewriting) |
| `agentsDoc`           | folds into AGENTS.md content (use verbatim, no rewriting) |
| `defaultModel`        | `--model` flag on the registration step (empty → omit; let benji default) |
| `defaultBackend`      | `--backend` flag (empty → omit) |
| `defaultThinking`     | `--thinking` flag (empty → omit) |
| `requiredToolkits`    | informational — toolkit wiring is per-node, not per-agent |
| `displayName`         | informational — for the final chat summary |

Pass the template-provided text verbatim into IDENTITY.md / SOUL.md /
AGENTS.md. Do NOT rewrite the personas — the template author wrote them
intentionally, and the user's wizard answers (per the template-templates
contract) influence the workflow prompts, not the agent personas. Skill
handling inside `create-agent`: always include the mandatory `aramb-chat`,
`aramb-tasks`, `aramb-workflows`, and `juno` skills (the skill enforces this) —
additionally, copy any skill implied by the agent's `requiredToolkits` (e.g. a
`hubspot` toolkit implies the agent needs to know how to use the aramb MCP
toolkits — already covered by the default `aramb-chat` / `aramb-tasks` /
`aramb-workflows` skills).

Run agents in the order they appear in the `<agents>` array. If
`create-agent` fails for any spec, STOP — do not proceed to `aramb_workflows.create`,
post the failure as the chat summary (see "Error handling"), and exit.

### 3. Polish the workflow (substantive — required when wizard answers are present)

When `<wizard-answers>` is non-empty, the resolved node prompts almost
certainly read like Mad Libs — the user's free-form answers were dropped
into `{{placeholder}}` slots by mechanical substitution, producing
grammatically awkward or contextually thin text. You MUST rewrite these to
read naturally, using both the wizard answers and any additional context the
user expressed in their original chat message.

What "substantive polish" looks like:

- Smooth the substituted prose so it reads like a person wrote it, not a
  template engine: collapse list-of-three answers into a natural clause,
  fix article agreement, restructure run-on sentences.
- Weave in the *meaning* of the wizard answers, not just the strings.
  Example: if `ideal_customer` = "solopreneurs, builders who don't wanna
  quit their job, builders who don't have a big team to build", you might
  rewrite "Find ideal customers matching: solopreneurs, builders who don't
  wanna quit their job, ..." → "Identify side-builder founders — solopreneurs
  and small-team builders who haven't yet quit their day job to go full-time
  on their product."
- Add brief, neutral context implied by the inputs when it helps the
  executing agent do its job (e.g. infer the company is early-stage, infer
  the ICP is "indie-founder-style buyer", add one-line guidance).
- **Strip any stale closing-call block** — if a template-shipped node prompt
  ends with a literal `npx mcporter call aramb_workflows.update_my_step …`
  block, remove it and put a one-line output contract in its place (see
  "Output contract per node" above).

What you MUST NOT change:

- `assigned_agent` on any node
- `required_toolkits` on any node (copy verbatim)
- `unique_id` / `settings` on any node
- The set of nodes (no adds, no removes)
- Any edges (no adds, no removes, no reroutes)
- `default_node_settings`, `budget_usd`, `stateful`

When `<wizard-answers>` is empty (`{}`), polish is optional: only rewrite if
the resolved text is obviously broken. The stale-closing-block strip still
applies.

### 4. Save the workflow

Call `aramb_workflows.create` with `application_id` + `project_id` (both available
from your dispatch context, same as every other master-side MCP call). Pass
the polished workflow fields plus `template_slug` so brahmi stamps
`DefinitionSource{Kind:"template", Reference:slug}` on the workflow row.

```bash
npx mcporter call aramb_workflows.create \
  application_id="<application_id>" \
  project_id="<project_id>" \
  template_slug="<slug from the template-import block>" \
  name="<workflow.name, polished>" \
  description="<workflow.description, polished>" \
  default_node_settings='<workflow.default_node_settings JSON, verbatim>' \
  budget_usd=<workflow.budget_usd> \
  stateful=<workflow.stateful> \
  env_variables='{}' \
  nodes='<polished nodes JSON — name/prompt rewritten per step 3, rest verbatim>' \
  edges='<workflow.edges JSON, verbatim>'
```

**Pre-flight checklist — verify before calling `aramb_workflows.create`.** For every
node in your `nodes` array, confirm:

- `unique_id`, `assigned_agent`, `acceptance_criteria`, `settings` — all
  present and unchanged from the template payload (verbatim)
- `name`, `prompt` — may carry your polish from step 3
- `required_toolkits` — present on every node, copied verbatim from the
  template payload (use `[]`, never omit)
- `prompt` — carries business context + a one-line output contract. If the template shipped a stale `npx mcporter call aramb_workflows.update_my_step …` block at the bottom, polish should have stripped it (step 3).

And on the call itself:

- `template_slug` — the slug from the `<template-import>` block, so the
  workflow row records its origin
- `default_node_settings` — verbatim from the template payload
- `env_variables` — `'{}'` (templates do not declare env variables in v1)
- `edges` — verbatim from the template payload (each edge `{source, target}`).

**Never retry `aramb_workflows.create`.** One shot — success or failure. If the call
fails, surface the error in the chat summary (step 5) and stop.

### 5. Post a chat summary

After `aramb_workflows.create` returns, post a short chat message naming the
workflow and listing the agents you created. Use the `name` you sent to
`aramb_workflows.create` and the agent `displayName` values from the `<agents>`
specs (fall back to title-cased `name` when `displayName` is empty).

```bash
npx mcporter call aramb_chat.send_message \
  project_id="<PROJECT_ID>" \
  application_id="<APPLICATION_ID>" \
  content="Created **GTM Team** workflow with 8 agents: Sales Manager, Lead Researcher, Email Writer, Call Prep, Demo Scheduler, Lead Scorer, CRM Sync, Analytics."
```

After posting, STOP. Do not send follow-up messages.

## Error handling

- **`create-agent` fails for any spec** → post a single chat message naming
  the failing agent and the reason, then STOP. Do NOT call `aramb_workflows.create`.

  ```bash
  npx mcporter call aramb_chat.send_message \
    project_id="<PROJECT_ID>" \
    application_id="<APPLICATION_ID>" \
    content="Couldn't create agent **<name>**: <reason>. Template import aborted."
  ```

- **`aramb_workflows.create` fails** → post a single chat message naming the failure,
  then STOP. No retry. (At this point the agents were created — if the user
  retries the import the agent registry will report a conflict; that's
  acceptable for v1, but mention it in the chat summary so they know.)

  ```bash
  npx mcporter call aramb_chat.send_message \
    project_id="<PROJECT_ID>" \
    application_id="<APPLICATION_ID>" \
    content="Created agents but couldn't create the workflow: <reason>. Re-importing the same template will fail until the existing agents are deleted."
  ```

- **`<template-import>` block is malformed** (missing required fields,
  invalid JSON, no `slug`, no `<workflow>`, no `<agents>`) → post a single
  chat message flagging the bug, then STOP. No `create-agent` calls, no
  `aramb_workflows.create` call.

  ```bash
  npx mcporter call aramb_chat.send_message \
    project_id="<PROJECT_ID>" \
    application_id="<APPLICATION_ID>" \
    content="Template import payload was malformed — this is a bug, please file it."
  ```

- **`<template-import>` block absent** → STOP immediately. Do not post a
  message; this skill simply does not apply. Master should be routing to
  `create-workflow` / `update-workflow` instead per its AGENTS.md.

## What this skill does NOT do

- Does NOT call `aramb_tasks.list` (no tasks drive this dispatch)
- Does NOT call `aramb_tasks.update` (no task was opened)
- Does NOT call `aramb_workflows.update` (we're creating, not editing)
- Does NOT invoke any other agent (the listed agents only start working
  when the user manually triggers a run of the new workflow)
- Does NOT set a schedule (template imports do not carry scheduling
  intent in v1; if the user later wants one, they ask separately and
  master routes to `schedule-workflow`)
- Does NOT rewrite agent personas — `identity` / `soul` / `agentsDoc` from
  the `<agents>` specs land in benji verbatim. Polish (step 3) applies
  only to workflow node text.

## Rules

- Trigger is the `<template-import>` block in the extra-system-prompt — never the user's prose
- Create every agent from the `<agents>` array via `create-agent` before saving the workflow — verbatim persona content, no rewriting
- Substantively polish node `name` / `prompt` text (and the workflow `name` / `description`) when `<wizard-answers>` is non-empty; structure (`assigned_agent`, `required_toolkits`, edges, settings) is immutable
- Every node in `aramb_workflows.create` carries `required_toolkits` (use `[]` when empty, never omit)
- Every node's `prompt` carries business context + a one-line output contract (see "Output contract per node")
- `aramb_workflows.create` runs exactly once; never retry
- Always pass `template_slug` so brahmi records the workflow's origin
- Post exactly one chat summary at the end (success or error); then STOP
- Never call `aramb_tasks.list`, `aramb_tasks.update`, or `aramb_workflows.update` from this skill
