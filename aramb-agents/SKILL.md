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

## Authoring the persona — system prompt, soul, AND agents doc

`aramb_agents.create` / `update` carry the whole persona, not just one prompt
field. For a real domain agent, author its **soul** and (when its operating flow
is non-trivial) its **agents doc** — leaving them empty ships the platform's
domain-neutral defaults, which is rarely what a purpose-built agent wants.

- **`system_prompt`** (required on create) — the agent's full persona / system
  prompt, verbatim. `system_prompt_mode`: `replace` (default) sends it as the
  entire system prompt; `append` keeps the runtime preset.
- **`soul`** — the agent's **SOUL.md**: who it is, its personality and
  behavioural voice, its disposition and boundaries. Delivered to the container
  as a file. Empty ⇒ platform default (domain-neutral). Author this for any
  agent with a real character — a warm support triager, a terse ops bot, a
  careful medical-intake screener read very differently, and the soul is where
  that lives.
- **`agents_doc`** — the agent's **AGENTS.md**: its operational playbook — how it
  works, the order it does things, when to reach for which tool, how it handles
  edge cases. Delivered as a file. Empty ⇒ platform default. Author this when the
  agent's job is more than one-shot Q&A (a multi-step routine, tool sequencing,
  hand-off rules).

Both are **snake_case** on the main persona (`soul`, `agents_doc`). Do not confuse
them with the workflow **sub-agent** shape inside `agent_specs`, which uses
camelCase `soul` / `agentsDoc` (create-agent / aramb-workflows skills) — those
author a workflow node's sub-agent, these author the product agent itself.

```bash
# Author the main persona with a soul and an operating playbook, not just a prompt.
npx mcporter call aramb_agents.create name="Support Triage" \
  system_prompt="You triage inbound support and route each ticket to the right queue…" \
  soul="You are calm and concise. You never guess a policy — you check the KB or say you'll find out…" \
  agents_doc="1. Read the ticket. 2. Classify: billing / bug / how-to. 3. If billing, check the refund-policy KB before replying. 4. Route with a one-line rationale…"

# Patch just the soul later — partial merge, other fields untouched.
npx mcporter call aramb_agents.update agent_id="<AGENT_ID>" soul="You are warmer now — open with a short acknowledgement before triaging…"
```

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

## Knowledge Base — list / add / remove docs (`aramb_agents.kb_*`)

An agent can carry a **Knowledge Base**: documents the persona draws on at
runtime. You are no longer limited to pointing the user at the console — for the
text/markdown docs you author yourself, manage the KB directly with these verbs.
They are fenced to the calling agent's organization like every other
`aramb_agents` call.

- **`aramb_agents.kb_list`** (`agent_id`) — list the agent's KB documents. Returns
  `{documents: [{doc_id, filename, folder, content_type, size, created_at}]}`. Call
  this first to find a `doc_id` before `kb_remove`, or to pick which docs should
  travel into a template.
- **`aramb_agents.kb_add`** (`agent_id`, `filename`, `content`, optional `folder`) —
  add a KB document from **inline text**. Only `.txt` and `.md` filenames are
  accepted: the content is passed inline as text, so binary formats (PDF, DOCX, …)
  are **NOT** supported through this verb. Use it for KB docs the Architect itself
  authors (markdown / plain text). For a PDF, DOCX, or any binary document, tell the
  user to upload it via the console (**Knowledge Base → Add document**).
- **`aramb_agents.kb_remove`** (`agent_id`, `doc_id`) — remove one KB document by the
  `doc_id` from `kb_list`. Idempotent — an unknown `doc_id` still succeeds. The doc
  drops from the agent's containers on the next sync.

```bash
# List the KB, author a new markdown doc inline, then remove one by id.
npx mcporter call aramb_agents.kb_list agent_id="<AGENT_ID>"
npx mcporter call aramb_agents.kb_add agent_id="<AGENT_ID>" filename="refund-policy.md" content="# Refund policy\n\nRefunds are honored within 30 days of purchase." folder="policies"
npx mcporter call aramb_agents.kb_remove agent_id="<AGENT_ID>" doc_id="<DOC_ID>"
```

## Export the agent as a reusable template (`aramb_agents.export_template`)

- **`aramb_agents.export_template`** (`agent_id`, `slug`, `name`, optional
  `description`, `category`, `tags`, `publish_first`, `include_knowledge_doc_ids`) —
  export the agent into the shared catalog as a reusable template.
  `publish_first` defaults **true** — it publishes the agent's current draft before
  exporting, so the template captures a live version. `include_knowledge_doc_ids` (a
  comma-separated list of `doc_id`s from `kb_list`) chooses which KB docs travel into
  the template; omit it and the template carries **no** knowledge.

```bash
npx mcporter call aramb_agents.export_template agent_id="<AGENT_ID>" slug="support-triage" name="Support Triage Agent" description="Triages inbound support and routes to the right queue." category="support" tags="support,triage" publish_first=true include_knowledge_doc_ids="<DOC_ID_1>,<DOC_ID_2>"
```

**This is an outward, irreversible action** — the template goes into the shared
catalog and cannot be pulled back. **Confirm with the user before calling it**,
including which KB docs (if any) should travel with it.

## Draft vs published — the one model to internalize

`update` edits a private draft; `publish` releases it. So the safe default
loop is: `get` → discuss → `update` → let the user test → `publish` when they
confirm. If a user reports "my agent still does the old thing" after an
update, the likely cause is an unpublished draft — `get` shows
`publishable: true` when the draft differs from the published version.

## Required toolkits — you DECLARE them, the USER connects them

An agent's persona declares the toolkits it needs (its **required toolkits** /
ports — GMAIL, SLACK, GOOGLESHEETS…) via `required_toolkits` on
`aramb_agents.create` / `update`. Declaring a port is not enough to run: each
required toolkit needs a **connected account** (a real account a human authorized
via OAuth) before the agent can use it. You do **not** pick or pin the exact
account — which account an agent uses for a toolkit is resolved automatically from
the account the user connected on their own runtime project.

**Your half of the contract is the declaration, and only the declaration:**

```bash
# Ground every slug against the real catalog first — never invent one.
npx mcporter call aramb_toolkits.list_toolkits

# Then declare them on the agent.
npx mcporter call aramb_agents.update agent_id="<AGENT_ID>" required_toolkits='["GMAIL"]'
```

Then tell the user to connect each account themselves, in the console, on the
agent's **Tools** page. A run is gated until every required toolkit has a
connected account.

**You cannot connect a toolkit, and the connect tools are not in your tool list.**
`aramb_toolkits.connect_toolkit` / `request_connection` / `get_github_credential`
are deliberately not advertised to the agent-builder persona. The reason is not
politeness — a connection you brokered would be scoped to the **builder's own
project**, which never executes, so the account the user authorized would be
invisible at run time. The user connecting from the console lands it on their
runtime project, which is the only place execution looks.

So: never mint or paste an authorization link (never a raw `connect.composio.dev`
URL), never start OAuth, never inspect connection state, and never say a toolkit
is connected. If the user asks you to connect one, say plainly that you declare it
and they connect it on the Tools page.

**Truthfulness — do not get ahead of the tool result.** Never tell the user a
toolkit is connected: you have no way to observe that. Say "I've declared Gmail as
a required toolkit — connect your account on the agent's Tools page and it'll be
ready", not "Gmail is connected". This is the same truthfulness rule that governs
the rest of this skill (never claim a state you haven't observed).

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
