---
name: aramb-agents
description: >
  MCP toolkit for the organization's aramb agents (aramb_agents.*). Use to
  create an agent once a persona design is settled, to inspect, revise
  (draft), and publish existing agents, and to read an agent's real
  conversations when evaluating or improving it. NOT for provisioning
  workflow-node sub-agents — that is the create-agent skill.
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
- **You need to see how the agent actually behaves with users** →
  `aramb_agents.conversation_search` then `aramb_agents.conversation_get`.
  Read real conversations before judging or revising a persona — ground the
  change in what users actually said and how the agent replied, not a guess.

## Reading conversations (evaluate → improve)

To improve an agent from evidence, read its conversations, then feed what you
learn back into the `get` → `update` → `publish` loop.

- **`aramb_agents.conversation_search`** — list an agent's conversations,
  most-recent-activity first. Optional `from`/`to` (RFC3339) window the
  activity, `order` is `recent` (default) or `oldest`, `limit` defaults to 50
  (max 200). Returns `{conversations: [{conversation_id, title, created_at,
  last_message_at}], has_more}`.
- **`aramb_agents.conversation_get`** — one conversation's messages, oldest
  first. Optional `from`/`to` (RFC3339) window the messages (`to` is also the
  backwards-paging cursor — pass the returned `next_before` to page older),
  `order` is `asc` (default) or `desc`, `limit` defaults to 50 (max 200). Set
  `include_run_events=true` to also get the agent's run/tool-event stream when
  you need to review how it used its tools. Returns `{messages: [{role,
  message_type, content, created_at}], has_more, next_before, run_events?}`.

```bash
# Find the agent's recent conversations, then read one transcript.
npx mcporter call aramb_agents.conversation_search agent_id="<AGENT_ID>" order="recent" limit="20"
npx mcporter call aramb_agents.conversation_get agent_id="<AGENT_ID>" conversation_id="<CONVERSATION_ID>"

# Narrow to a time window, and pull tool usage when diagnosing a tool problem.
npx mcporter call aramb_agents.conversation_get agent_id="<AGENT_ID>" conversation_id="<CONVERSATION_ID>" from="2026-07-01T00:00:00Z" to="2026-07-08T00:00:00Z" include_run_events="true"
```

These reads are transcript-only: they surface `role` (user / assistant),
message text, and time — never the end-user's identity or tenancy. Use them to
spot where the agent misunderstands, over-refuses, or misses context, then
patch the draft with `update` and `publish` once confirmed.

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
