# Workflow Templates — aramb-skills

**Status:** design / not started
**Workspace design:** [`/Users/siva/workspace/claude/tasks/workflow-templates.md`](../../../claude/tasks/workflow-templates.md)
**PR (planned):** Lands at the start of the workflow-templates rollout — ships with the brahmi PR (must reach the master agent before brahmi starts dispatching `<template-import>` blocks).

This doc tracks aramb-skills work only. Read the workspace doc first
for the full flow; sections here reference workspace §§ where applicable.

---

## 1. Scope

1. New skill: `aramb-skills/import-workflow/SKILL.md` (workspace §8.1).
2. One-paragraph addition to `aramb-skills/workspace-master/AGENTS.md`
   so master lists `import-workflow` alongside `create-workflow` /
   `update-workflow` and routes to it when the dispatch contains a
   `<template-import>` block.

Out of scope:

- Agent provisioning logic (handled by brahmi via `benji.ProvisionAgent`
  gRPC before this skill runs — workspace §6.2 step 3).
- Solo flavor (`solo-create-workflow` / `solo-update-workflow`):
  templates are team-mode-only by decision 4 in the workspace doc.
- Tests against the existing `create-workflow` skill — the
  template-import path is distinct (no tasks, no list_tasks, no
  consolidation analysis) and must not affect the consolidation
  flow's safety rules.

## 2. The new skill

### 2.1 Location and layout

```
aramb-skills/import-workflow/
└── SKILL.md
```

Same single-file shape as `create-workflow/`.

### 2.2 Frontmatter

```yaml
---
name: import-workflow
description: >
  Materialize a pre-defined workflow template into the current
  application. Use when the dispatch contains a <template-import>
  block in the extra-system-prompt. NOT for: consolidating completed
  tasks (use create-workflow), editing an existing workflow (use
  update-workflow), or executing a workflow.
---
```

### 2.3 Content

The skill MUST contain — in this order — sections matching the
workspace §8.1 responsibilities:

#### 2.3.1 MUST rules (at the top)

1. **This skill ONLY runs when the dispatch contains a
   `<template-import>` block.** If no such block is present, STOP —
   you should be using `create-workflow` or `update-workflow` instead.
2. **Do NOT call `list_tasks` and do NOT call `update_task`.** There
   is no task driving this skill. The brahmi dispatcher invokes the
   master agent directly with the template payload; tasks are not
   part of the template-import flow.
3. **Do NOT create, modify, or delete any agents via filesystem
   writes.** The agents listed in `<agents-provisioned>` have
   already been created in benji by brahmi via `ProvisionAgent`
   gRPC before this skill runs. Treat the list as informational —
   names to mention in the chat summary.
4. **`save_workflow` MUST be called exactly once.** Success or
   failure — no retry. The pre-resolved nodes/edges in the
   `<template-import>` block are the authoritative content.
5. **Every node in the `save_workflow` call MUST carry
   `required_toolkits`** copied verbatim from the
   `<template-import>` block. Use `[]` (not omitted) when a node
   touches no third-party service. (Same rule as `create-workflow`
   — fails the Required-toolkits row in the FE node panel if
   omitted.)
6. **Every node's `prompt` MUST end with the workflow-step closing
   instruction.** Pre-resolved prompts from brahmi already include
   this; polish MUST NOT remove it. (Same rule as `create-workflow`.)

#### 2.3.2 Steps

1. **Parse the dispatch.** Locate the `<template-import>` block in
   the extra-system-prompt. Extract `slug`, `agents-provisioned`
   (list of agent ids), and `workflow` (JSON object with
   `name`/`description`/`nodes`/`edges`/`default_node_settings`/
   `budget_usd`/`stateful`).
2. **Light polish (optional).** May lightly rewrite node `name` and
   `prompt` for tone or to merge in user context from the original
   chat message. MUST NOT:
   - Add or remove nodes
   - Change `assigned_agent` on any node
   - Change `required_toolkits` on any node
   - Add, remove, or reroute edges
   - Drop the workflow-step closing instruction from any prompt
   - Modify `default_node_settings`, `budget_usd`, or `stateful`
3. **Call `save_workflow`** with the resolved (and optionally
   polished) `nodes`, `edges`, `name`, `description`,
   `default_node_settings`, `budget_usd`, `stateful`, plus the
   `template_slug` field (workspace §2.9, option a) so brahmi can
   stamp `DefinitionSource{Kind:"template", Reference:slug}` on the
   workflow row.
4. **Post a chat summary.** A short message naming the workflow and
   listing the agents:
   > "Created **GTM Team** workflow with 8 agents: Sales Manager,
   >  Lead Researcher, Email Writer, Call Prep, Demo Scheduler,
   >  Lead Scorer, CRM Sync, Analytics."

   Agent names come from `<agents-provisioned>`. No need to look
   them up — brahmi already provisioned them.

#### 2.3.3 Error handling

- If `save_workflow` fails → post an error message to chat ("Couldn't
  create the workflow: <reason>. Please try again or contact
  support."), no retry.
- If the `<template-import>` block is malformed (missing required
  fields) → post an error message ("Template import payload was
  malformed — this is a bug, please file it."), no retry.

#### 2.3.4 What this skill does NOT do

- Does NOT call `list_tasks` (no tasks).
- Does NOT call `update_task` (no task to close).
- Does NOT call `update_workflow` (we're creating, not editing).
- Does NOT write to the filesystem (no agent materialization;
  brahmi did it).
- Does NOT invoke any other agent (the listed agents will only
  start working when the user manually triggers a run of the new
  workflow).

## 3. Master agent integration

### 3.1 `workspace-master/AGENTS.md`

Add a one-paragraph entry near the existing `create-workflow` /
`update-workflow` references:

> **import-workflow.** If the dispatch's extra-system-prompt
> contains a `<template-import>` block, route to the
> `import-workflow` skill. This block is brahmi telling you the
> user wants to materialize a pre-defined template — the agents
> have already been created on the runtime, and the workflow
> nodes/edges are pre-resolved. Do NOT call `create-workflow` or
> `update-workflow` for this path.

Read the existing AGENTS.md before writing this to match its tone
and structural conventions; do not duplicate or overwrite existing
sections.

### 3.2 No SOUL change

Master's SOUL is its personality / values; routing logic belongs in
AGENTS.md (per benji's persona / operational split — see
`benji/src/config/agent-workspace.ts` defaults). No SOUL edit
needed.

## 4. agent-factory pipeline

Per the 2026-04-30 memory note, `generate.py` SKILL_ORDER MUST
include every skill referenced by agent specs. Append
`import-workflow` to SKILL_ORDER (location: wherever the existing
list of master skills lives in the agent-factory pipeline). Without
this entry, the master persona ships without the skill content and
the dispatch silently falls through.

The fidelity check (sha256 vs source) added 2026-04-30 will catch a
missing skill at pipeline run time — but only if the master's
AGENTS.md references `import-workflow`. So land the AGENTS.md edit
and the SKILL_ORDER append in the same commit.

## 5. Test plan

### 5.1 Manual self-test (in dev container)

After rebuilding the kairo image with the new skill:

1. Start the local-testing stack.
2. Insert a fake `<template-import>` block into a chat message
   directly via brahmi DB (bypass the queue-consumer branch — that
   lives in brahmi's PR which may not be deployed yet to dev).
3. Confirm master loads the skill, calls `save_workflow`, and
   posts the chat summary.

### 5.2 End-to-end (after brahmi PR + this PR + image rebuild)

Per the workspace §11.2 UAT path. The brahmi PR's test plan is the
authoritative check; this skill is exercised as a side effect.

### 5.3 No regression on create-workflow

Re-run the existing `create-workflow` happy path in local-testing
(consolidate a chat with 2-3 completed tasks into a workflow) and
confirm it still works unchanged. This skill MUST NOT affect that
path.

## 6. Commit phasing (within this PR)

1. `import-workflow: new SKILL.md (full content per §2)`
2. `workspace-master: AGENTS.md adds import-workflow routing paragraph`
3. `agent-factory: SKILL_ORDER appends import-workflow`

## 7. Risks

| Risk | Mitigation |
|---|---|
| Master agent doesn't see the `<template-import>` block (extra-system-prompt formatting drift). | Brahmi PR's dispatch payload builder includes the block via the same plumbing as `create-workflow`'s "Your task id" block — proven path. Validate end-to-end in local-testing UAT. |
| Master picks `create-workflow` first by mistake (because the dispatch also contains general conversation about templates). | AGENTS.md routing paragraph is explicit ("If the dispatch's extra-system-prompt contains a `<template-import>` block, route to import-workflow"). The presence of the block — not the user's prose — is the trigger. |
| `save_workflow` schema change required for the new `template_slug` field (brahmi-side). | Coordinate with the brahmi PR — the MCP tool definition change for `save_workflow` lands in brahmi PR step 9 (per `brahmi/claude/tasks/workflow-templates.md` §4 commit phasing). |
| Light polish drifts and the polished prompt loses the workflow-step closing instruction. | MUST rule at §2.3.1 forbids it; polish step explicitly lists this in the don't-do bullets. Smoke test: take a known-good template payload, run through master in dev, diff polished output against input — closing instructions must survive. |

## 8. Dependencies on other modules

- `brahmi` PR — provides the `<template-import>` block format,
  agent provisioning before dispatch, and the `template_slug` field
  on the `save_workflow` MCP tool.
- Kairo image rebuild after this PR merges so master agents pulled
  fresh from the pool have the skill loaded.
- web-app-v2 PR — independent of this skill (FE doesn't know about
  the skill; only knows about the wizard + send metadata).
