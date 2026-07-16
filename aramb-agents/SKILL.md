---
name: aramb-agents
description: >
  MCP toolkit for the organization's aramb agents (aramb_agents.*). Use to
  create an agent once a persona design is settled, and to inspect, revise
  (draft), and publish existing agents. NOT for provisioning workflow-node
  sub-agents — that is the create-agent skill.
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

- **The design is settled and the user wants the agent to exist** →
  `aramb_agents.create`. Create only AFTER the persona is agreed — name and
  the full system prompt are required, and the agent is born published as v1.
  Never create speculatively mid-brainstorm; iterate on the design in
  conversation first.
- **Before creating anything** → `aramb_agents.list`. If an agent with the
  same purpose already exists, propose updating it instead of duplicating.
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

## Draft vs published — the one model to internalize

`update` edits a private draft; `publish` releases it. So the safe default
loop is: `get` → discuss → `update` → let the user test → `publish` when they
confirm. If a user reports "my agent still does the old thing" after an
update, the likely cause is an unpublished draft — `get` shows
`publishable: true` when the draft differs from the published version.

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
