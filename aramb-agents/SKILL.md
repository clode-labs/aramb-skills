---
name: aramb-agents
description: >
  MCP toolkit for the organization's aramb agents (aramb_agents.*). Use to
  create an agent once a persona design is settled, and to inspect, revise
  (draft), and publish existing agents. To read an agent's real conversations
  when evaluating it use the analyse-conversation skill; to author and run
  scripted test suites use the agent-tests skill (both are aramb_agents.*).
  NOT for provisioning workflow-node sub-agents — that is the create-agent skill.
---

# Aramb Agents Toolkit

The `aramb_agents.*` tools manage the organization's **product agents** — the
personas end-users chat with. Each agent carries a versioned config (name,
system prompt, greeting, mode, skills, disabled tools) with a **single mutable
draft** and **immutable published versions**; end-users always get the
published version.

## CRITICAL: mcporter syntax rules
- ALL arguments MUST use `key="value"` format.
- Do NOT use `--output` — it is not supported by mcporter call.
- Array arguments (`skills`, `disabled_tools`) take a JSON array string, e.g. `skills='["skill-a","skill-b"]'`.

## Which tool, when

- **The design is settled and the user wants a NEW agent to exist** →
  `aramb_agents.create`. Create only AFTER the persona is agreed — name and
  the full system prompt are required. Never create speculatively mid-brainstorm;
  iterate on the design in conversation first. **Only call `create` when there is
  genuinely no agent yet in the conversation.**
- **You are already operating on / within an existing agent** (an agent is already
  in context, being edited or built out) → **`aramb_agents.update`, NOT `create`.**
  When a change lands and there is already an agent you're working on, revise THAT
  agent — do not spin up a brand-new one. A second agent for work that belongs on
  the current one is a duplication bug.
- **Before creating anything** → `aramb_agents.list`. If an agent with the
  same purpose already exists, update it instead of duplicating.
- **Before ANY revision** → `aramb_agents.get`. The stored draft is the
  source of truth, not this conversation — someone may have edited the agent
  elsewhere since you last saw it. Read, then patch.
- **The user wants a change** → `aramb_agents.update`. This is a partial
  merge onto the DRAFT: pass only the keys that change. Saving a draft does
  NOT change what end-users see.
- **The change should go live** → `aramb_agents.publish`. Publishing
  snapshots the draft as a new immutable version and makes it what end-users
  get. Treat this as a deliberate, user-confirmed step — draft freely,
  publish on an explicit "ship it".
- **You need to see how the agent actually behaves with users** → read its real
  conversations before judging or revising a persona (the **analyse-conversation**
  skill). Ground the change in what users actually said and how the agent
  replied, not a guess.
- **You want to prove a change with a repeatable, scripted test** → author and
  run a multi-turn test suite (the **agent-tests** skill).

## Evaluate and test — separate skills

Two capabilities that used to live here now have their own skills. Both are
still the `aramb_agents.*` toolkit; they were split out so each is a focused,
self-contained playbook:

- **Read the agent's real conversations** (evaluate from evidence → improve) →
  the **analyse-conversation** skill (`aramb_agents.conversation_search` /
  `conversation_get`). This is also where the console's **Analyze** button lands.
- **Author and run scripted test suites** against a persona → the
  **agent-tests** skill (`aramb_agents.test_*`). Tests must script at least 3
  user turns.

Both feed the same `get` → `update` → `publish` loop below: read a conversation
or run a test, judge it, patch the draft, publish when confirmed.

## Draft vs published — the one model to internalize

`update` edits a private draft; `publish` releases it. So the safe default
loop is: `get` → discuss → `update` → let the user test → `publish` when they
confirm. If a user reports "my agent still does the old thing" after an
update, the likely cause is an unpublished draft — `get` shows
`publishable: true` when the draft differs from the published version.

## Beyond the prompt — when the agent needs more, use the right skill

A persona often needs a capability these tools don't cover. Don't improvise it
here — reach for the dedicated skill; each documents its own tools:

- **The agent must touch an external service** (Gmail, Drive, Slack, a sheet) →
  create the toolkit connection with the `aramb-toolkits` skill (check what's
  connected, start the OAuth from chat) and the `composio-cli` skill (discover
  and run the actual actions). Name the concrete connection the agent needs.
- **The agent's job is a repeated multi-step routine, or should run on its own**
  (daily digest, triage-then-route, scheduled report) → build and run it with
  the `create-workflow` / `aramb-workflows` skills, and `schedule-workflow` /
  `configure-trigger` to fire it on a cron or an event.

## An agent can own workflows (an optional binding, not a rule for all workflows)

Workflows are standalone objects by default and remain so — this section is only about
the ones you deliberately bind to an agent. A **bound** workflow is owned by, and
discoverable + runnable by, **exactly one agent**; binding does not turn every workflow
into an agent-scoped thing, and standalone workflows are unaffected. When you are
**designing an agent**, build the workflows it needs **bound to that agent** (rather than
leaving them loose) so the agent can discover and run them:

- A **bound** workflow belongs to **exactly one agent** — and there are **two
  equally-valid orderings** to get there. **Agent-first:** create the agent, then
  create the workflow already linked to it by passing `agent_id` on
  `aramb_workflows.create` (create-and-link in one call). **Workflow-first:** if the
  builder wants to design and TEST a workflow before committing to an agent, build it
  on its own, iterate/preview it, then link it to the agent with
  `aramb_agents.attach_workflow` once the agent exists (its `agent_id` gets stamped and
  the workflow is re-filed under the agent's template project). Attach and
  create-with-`agent_id` **converge on the same end state** — owned by and filed under
  the agent. Don't leave a workflow **permanently** unattached. See the
  `create-workflow` and `aramb-workflows` skills.
- A workflow stays a **draft** on creation; the builder tests it via Preview. There
  is **no separate "publish the workflow" step** — a workflow freezes into its live
  version **automatically when you `aramb_agents.publish` the owning agent**. So
  publishing the agent is what ships both the persona and its workflows together.
- **Publishing a toolkit-using workflow is gated on its toolkits being connected.**
  When you publish the agent, the backend publishes each bound workflow draft — BUT a
  workflow whose steps require third-party toolkits (Gmail, Slack, Notion…) goes live
  ONLY if those toolkits are actually **CONNECTED**. If a required toolkit isn't
  connected, that workflow stays a draft and the publish response reports it as blocked,
  naming the missing toolkits. So the go-live path for such a workflow is: connect its
  toolkits on the **Integrations** page, then publish the agent. Verify up front with
  `aramb_toolkits.check_connection` and tell the builder which toolkits to connect —
  never call a toolkit-using workflow "live" before its toolkits are connected **and**
  the agent is published.

## Not this skill

- **Workflow-node sub-agents** (a persona to own one step of a workflow you
  are authoring) → the `create-agent` skill. Those are workspace-level
  runtime agents, not org product agents, and have no draft/publish
  lifecycle.
- **Editing your own persona** — these tools manage the org's agents; your
  own identity files are not among them.

## Ownership

Every call is fenced to the calling agent's organization. There is no org
argument and no way to address another org's agents; an id that isn't yours
reads as not found.
