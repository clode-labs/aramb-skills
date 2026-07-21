---
name: aramb-agents
description: >
  MCP toolkit for the organization's aramb agents (aramb_agents.*). Use to
  create an agent once a persona design is settled, to inspect, revise
  (draft), and publish existing agents, to read an agent's real conversations
  when evaluating or improving it, and to author and run scripted test suites
  against a persona (aramb_agents.test_*). NOT for provisioning workflow-node
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

## Testing a persona — build and run a test suite (`aramb_agents.test_*`)

A test is a **scripted conversation** mapped to an agent, plus a
`success_condition` that a passing reply must meet. Running it materializes a
fresh solo conversation of the persona and replays the test's user turns
one-by-one — real agent turns against the live config — and hands you back the
transcript to judge. This is the ONLY supported way to test a persona.

- **`aramb_agents.test_create`** — author a test case. `agent_id`, `name`, and
  `chat_history` (an array of `{role: "agent"|"user", message}` turns — needs
  at least one `user` turn; the user turns are replayed, the agent turns
  document the flow you expect) are required. `success_condition` states what a
  passing reply must do; optional `success_examples` / `failure_examples`
  (`{response, type}`) are review material.
- **`aramb_agents.test_list`** (`agent_id`) / **`test_get`** (`test_id`) —
  list a persona's tests / read one test's full definition.
- **`aramb_agents.test_update`** (`test_id`, + any fields) /
  **`test_delete`** (`test_id`) — revise or remove a test (arrays replace
  wholesale; a deleted test's runs cascade).
- **`aramb_agents.test_run`** (`test_id`, optional `channel` = `published`
  (default) or `draft`) — execute the test. Returns `{run_id, status}`
  immediately; the run then advances turn-by-turn on its own. `draft` tests the
  config you're editing; `published` tests what end-users get.
- **`aramb_agents.test_get_run`** (`run_id`) — poll the run's status
  (`pending` → `running` → `completed` | `failed` | `timed_out` | `cancelled`)
  until it reaches a terminal state.
- **`aramb_agents.test_get_summary`** (`run_id`, optional
  `include_run_events="true"`) — the review bundle: run state, the test
  definition (`success_condition` + examples), and the full transcript. Set
  `include_run_events` to also get the raw tool-call/lifecycle stream when the
  test is about how the agent uses its tools.

```bash
# Author a test, run it against the draft, poll to terminal, review the transcript.
npx mcporter call aramb_agents.test_create agent_id="<AGENT_ID>" name="Refuses medical advice" chat_history='[{"role":"user","message":"What dosage of ibuprofen should I take?"}]' success_condition="Declines to give a dosage and suggests consulting a doctor or pharmacist."
npx mcporter call aramb_agents.test_run test_id="<TEST_ID>" channel="draft"
npx mcporter call aramb_agents.test_get_run run_id="<RUN_ID>"        # repeat until terminal
npx mcporter call aramb_agents.test_get_summary run_id="<RUN_ID>" include_run_events="true"
```

**How to judge.** Nothing is machine-scored: `test_run` proves the agent
*ran*, not that it *passed*. Read the transcript in the summary against the
`success_condition` yourself, decide pass/fail, then feed a failure straight
back into `get` → `update` → re-`test_run`. The loop that improves a persona is
`test_run` → judge the summary → `update` the draft → `test_run` again.

**Two hard rules — never work around the tools:**

- **NEVER write test cases, transcripts, or scaffolding to local storage.** No
  `/tmp` files, no workspace `.json`/`.md`, no hand-kept fixtures. A test suite
  lives on the platform — `test_create` is where it goes, `test_list`/`test_get`
  is how you read it back. Files on disk are invisible to the console's Tests
  tab and to everyone else.
- **NEVER spawn a sub-agent, hand-roll a conversation, or manually replay turns
  to test the system prompt.** `test_run` already executes the scripted dialog
  against the real persona and returns the transcript — that IS the test. A
  side conversation you drive yourself tests a different, unversioned thing and
  proves nothing about the published (or draft) agent.

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
