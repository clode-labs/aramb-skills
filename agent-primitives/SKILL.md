---
name: agent-primitives
description: >
  The Architect's structured catalog of everything it can equip an agent with — the build
  primitives. Use in Phase 2 (Map HOW) of every build: for each primitive, know WHAT it is, WHICH
  tools/params support it, WHEN to use it, its GOTCHAS, and WHERE it lives in the console. This is
  the reference behind the primitive-decision table. Read it after Phase 1 (archetype), before you
  write the plan. Pair with the agent-archetypes skill (which tells you the SHAPE; this tells you
  the PIECES).
---

# Agent Primitives — the build-block catalog

An agent is assembled from primitives. The agent-archetypes skill tells you which *shape* you're
building; this skill is the structured catalog of the *pieces* you assemble it from — the full set of
capabilities the Architect has at its disposal. Phase 2 (Map HOW) walks this catalog and decides, for
each primitive, **needed / defer / n-a** with a reason. Every "needed" primitive that depends on the
*user* to finish (a connection, an upload, a real secret) becomes a completion item in the build
summary.

Each entry is structured the same way:

- **What it is** — the capability in one or two lines.
- **Supporting tools / params** — the exact `aramb_*` tool or `aramb_mcp.agents_create/update` field.
- **When to use** — the signal that calls for it.
- **Gotchas** — the correctness rules that are easy to get wrong.
- **Where (console)** — the screen the user sees it on (for the build summary + the guided tour).

> All agent create/inspect/revise/publish goes through `aramb_mcp.agents_*` only — never a CLI
> (see the aramb-agents skill and SOUL.md). The console locations below are for guiding the USER and
> for the build summary; they are not an alternate build path for you.

---

## A · Identity & behavior (the core — almost always "needed")

### Persona
- **What it is:** who the agent is — its instructions, voice, and operating playbook.
- **Supporting tools / params:** `aramb_mcp.agents_create` / `update` → `system_prompt` (+ `system_prompt_mode`: replace|append), `soul` (personality/voice), `agents_doc` (operating playbook), `name`.
- **When to use:** every agent. This is the one primitive that is always needed.
- **Gotchas:** say WHEN/WHY to use a capability in the prompt, never HOW to call it (the runtime supplies mechanics). Keep the prompt coherent as capabilities are added/removed.
- **Where:** Configure → **Agent** (system prompt, first message, starters).

### Opening — greeting OR conversation starters (never both)
- **What it is:** how a new conversation starts.
- **Supporting tools / params:** `greeting` **or** `conversation_starters` (3–6 short clickable prompts). Set one, leave the other empty; the platform keeps only one.
- **When to use:** starters when the agent does several distinct things (they advertise capability); a greeting for a single-purpose agent.
- **Gotchas:** setting both is invalid. When switching, clear the one you drop in the same update.
- **Where:** Configure → **Agent**.

### Model
- **What it is:** the LLM the agent runs on.
- **Supporting tools / params:** `model` (bare model id).
- **When to use:** leave default unless there's a concrete reason (cost, a capability the task needs).
- **Where:** Configure → **Agent** (right rail, LLM picker).

### Behavior mode & isolation — fixed, don't touch
- Every agent you build is **solo** (it works alone) and **per_user** (each end-user gets their own isolated space). These are the only supported modes — never set `mode=team` or `isolation_mode=shared`. There is no decision to make here; leave both at their defaults.

---

## B · Knowledge

### Knowledge Base
- **What it is:** reference material the agent answers *from* — policies, product facts, brand voice, FAQs.
- **Supporting tools / params:** `aramb_mcp.agents_kb_add` — args are **`filename`** (must end `.txt`/`.md`) + **`content`** (NOT `title`/`name`; a `title=` call fails `missing required argument: filename`). `kb_list` / `kb_remove` to manage.
- **When to use:** whenever the agent should answer from a fixed body of reference material rather than general knowledge or guesswork.
- **⚠️ NEVER fabricate the user's real-world data as `[PLACEHOLDER]` KB docs.** Their schedule, prices, policies, addresses, contacts — you don't have them, and **KB docs cannot be edited in the console** (Add / download / delete only — no inline edit), so a placeholder is *worse than none*: the user must delete each and re-add. Author a KB doc yourself **only** from content the user actually gave you (or genuinely-general reference that isn't their private data). Otherwise, list what to upload and make it a **completion item with a clickable link** to Knowledge Base → Add document — one doc or many, their format.
- **Gotchas:** scope the persona to answer *from* the KB and to say it doesn't know (and hand off) when the KB is empty/silent — so the draft is correct before and after the upload. What you couldn't author from real content (text you don't have, and every binary/PDF) is a **build-summary completion item**.
- **Where:** Configure → **Knowledge Base → Sources** (`/app/agents/<agent-id>/knowledge`, **Add document**).

---

## C · Capabilities the agent can call (the tools at its disposal)

These are the primitives that give the agent *reach* — the things it can actually do beyond talk.
Toolkits, browser, external MCP, model tools, and (emerging) voice all live here.

### Skills
- **What it is:** reusable registry playbooks that lift the agent's performance at a task.
- **Supporting tools / params:** discover with the **aramb-skills** skill (`aramb-skills search`); attach via `aramb_mcp.agents_update` → `skills` (registry ids, max 20). Never invent an id.
- **When to use:** when a proven playbook exists for the agent's domain (prospecting, outreach, a support flow).
- **Gotchas:** search before attaching; if nothing fits, tell the user skills can be added later from the Skills page.
- **Where:** agent sidebar → **Skills** (its own page).

### Toolkits / Integrations
- **What it is:** managed connections to external SaaS the agent uses — mail, sheets, drive, calendars, chat apps, CRMs (1,000+ services). The provider behind them is an implementation detail; all you touch is `aramb_toolkits`.
- **Supporting tools / params:** ground slugs with `aramb_mcp.toolkits_list_toolkits`; record on the agent as `required_toolkits` (uppercase catalog slugs). The USER connects each account.
- **When to use:** whenever the job touches an external service you can name (send mail, read a sheet, post to Slack).
- **Gotchas:** ⚠️ **you DECLARE, the user CONNECTS.** No OAuth, no authorization link, no inspecting connection state, never claim a toolkit is connected — a connection authorized through you lands on the wrong project. A run is gated until every required toolkit has a connected account. **Declared toolkits are a build-summary completion item.**
- **Where:** Configure → **Tools → Integrations** tab (the user connects their account here).

### Browser
- **What it is:** live web capability at *runtime* — the built agent can read web pages / do web research while it works.
- **Supporting tools / params:** `aramb_mcp.agents_create` / `update` → `browser: true`. This injects the browser usage guideline so the agent uses its built-in browser skill for the web (rather than a raw fetch/search).
- **When to use:** when the agent's job needs current, live web information at runtime — research, looking up a page, checking a live source. (Distinct from YOUR Phase-0 research with the aramb-browser skill: this gives the *built agent* its own browsing.)
- **Gotchas:** it's a capability flag on the agent — set it when the design needs live web; don't set it for an agent that only answers from its KB.
- **Where:** set on the agent; no separate user connect step.

### External MCP servers
- **What it is:** connect the agent to an external Model Context Protocol server so it gains that server's tools — a company's own MCP, or a third-party MCP not covered by the toolkit catalog.
- **Supporting tools / params:** **`aramb_mcp.agents_create_mcp_connection`** — YOU create and attach the connection: `agent_id`, `name` (the mcporter tool-namespace key, e.g. `indeed` → the agent calls `mcp__indeed__*`), `url` (the server's `https` Streamable-HTTP endpoint), optional `display_name` / `description` / `headers` (non-secret) / `enabled`. Read existing servers with `aramb_mcp.agents_list_mcp_connections`; on export mark each required/optional via `mcp_required`. The connection is proxied server-side so any secret never enters the container.
- **When to use:** whenever the agent needs tools from a specific external MCP the managed toolkits don't cover. **If you know the server's URL — and most public MCPs publish it — create it YOURSELF. Do not push a "go add it in the console" step onto the user for a public server; that's the old flow.**
- **Auth / secrets:** many public MCPs need none — pass just the `url` and it's done, no user step at all. For a server that needs a header credential: create a **dummy placeholder secret** with `vault_create_platform_secret` (name + description) and hand the user a **Vault edit link** to fill the real value (secrets are editable in place — same pattern as every other secret). NOTE: today `create_mcp_connection` persists only non-secret headers (it returns `needs_secrets: true` when it drops a `{{…}}` placeholder), so for the secret header itself also tell the user to add it on the connection in **Tools → MCP** while they fill the Vault value.
- **Gotchas:** the connection is org+agent-scoped; `url` must be `https` and public (loopback/private/metadata IPs are rejected). A public no-auth server is **done** the moment you create it — it's a build-summary completion item only when it needs a user-supplied secret. `name` can't collide with a platform namespace (`aramb*`/juno/chil/intervix/vault).
- **Where:** you create it via the tool; the user only edits secret VALUES in the **Vault** tab. The console **Tools → MCP** tab also lists/edits connections.
- **First-party (in-house) MCP servers — SITUATIONAL, not core.** The platform hosts a few of its own MCPs for capabilities that are genuinely hard to reach otherwise, and you attach one by passing **`first_party="<key>"`** to `create_mcp_connection` (no `url`/`name`/`headers` — brahmi fills the environment-correct URL and server name itself; the URL differs dev↔prod, so never hardcode it). These are **NOT default capabilities every agent gets** — reach for one ONLY when the agent's job specifically calls for it, exactly like declaring a toolkit. Available keys today:
  - **`indeed`** — Indeed job search (`search_jobs`, `get_company`; anonymous public postings). It exists *because Indeed is hostile to browse/scrape directly.* Use it only when the agent needs **Indeed** specifically. It is **not** a general job-search tool: for other job boards (LinkedIn, Glassdoor, company career pages) or open-ended job search, the agent should **browse**, not this. Pair it with the `indeed-mcp` skill for the usage playbook.

  If `first_party` returns "not configured in this environment," the key isn't available in this env — fall back to browsing (or a bring-your-own MCP) and note it, rather than inventing a URL.

### Model tools (the built-in tool allowlist)
- **What it is:** the agent's built-in MODEL tools — Read / Write / Bash / WebSearch and the like — and which of them it's allowed to use.
- **Supporting tools / params:** `aramb_mcp.agents_create` / `update` → `tools` (an explicit ALLOWLIST that *replaces* the default toolset) and `disabled_tools` (remove specific tools from the default profile).
- **When to use:** when you need to narrow a capable agent's built-in toolset (a locked-down support bot) or ensure a specific built-in tool is available. Most agents keep the default profile.
- **Gotchas:** ⚠️ `tools` is whitelisting — when set it REPLACES the default, so pass the full intended set, not just an addition. Prefer `disabled_tools` for small subtractions. Don't confuse these built-in MODEL tools with toolkits (external SaaS) or external MCP servers.
- **Where:** Configure → **Tools → Model tools** tab.

### Voice (emerging)
- **What it is:** marks the agent as voice-capable so clients can offer a live voice chat (served by the platform's voice runtime).
- **Supporting tools / params:** `aramb_mcp.agents_create` / `update` → `voice: true`. A capability marker only — it has no prompt or dispatch effect on its own.
- **When to use:** when the agent should be usable as a live voice assistant, not just text. (Treat as forward-looking — set the flag when the use case is voice-first; it doesn't change how the agent reasons.)
- **Gotchas:** it's a marker, not a behavior — pair it with a persona written for spoken interaction if voice is the primary surface.
- **Where:** set on the agent.

---

## D · Automation

### Bound workflow (single- or multi-agent)
- **What it is:** a multi-step routine bound to the agent as its own internal tool, run inline when the agent orchestrates it. Multi-agent when the nodes are genuinely distinct roles.
- **Supporting tools / params:** the workflow skills (`aramb_mcp.workflows_create` / `update`, create-workflow / import-workflow). Distinct-role nodes → author each role's sub-agent spec INLINE in the `agent_specs` array.
- **When to use:** only when one prompt genuinely can't do the job — genuinely distinct roles (research→write→edit, fetch→score→route) or a real repeated multi-step routine. Default to a single well-prompted solo agent; a workflow is never for "more instructions".
- **Gotchas:** ⚠️ a bound workflow has **NO schedule or trigger of its own** (there's no such surface; attempting one is refused). If the agent must run on a clock/event, that's an **agent trigger** (below). A workflow ships when its owning agent is published — its toolkits must be connected or it won't run.
- **Where:** Configure → **Workflow** (the shape/canvas) + **Tools → Workflows** (its invocation).

### Workflow invocation wiring
- **What it is:** how/when the agent actually FIRES a bound workflow, and what input it passes.
- **Supporting tools / params:** `aramb_mcp.workflows_update` → the workflow's `instruction` (how/when to invoke, what input) + `enabled: true`.
- **When to use:** whenever a bound workflow should be invoked on a condition ("run this whenever the user gives a topic").
- **Gotchas:** ⚠️ this is **NOT a system-prompt edit.** Putting invocation rules in `system_prompt` is the wrong layer and the agent won't fire the workflow. The prompt says who the agent is; the workflow's `instruction` says when it fires. Leaving `enabled=false` means it never runs.
- **Where:** Configure → **Tools → Workflows** tab (the instruction + enable box).

### Agent triggers
- **What it is:** make the AGENT itself run on its own — on a clock (cron), on a service event, or on a webhook.
- **Supporting tools / params:** `aramb_mcp.agents_trigger_create` / `trigger_list`. `trigger_create` requires `agent_id` + `name` (phrase it as the task) + `kind` (cron / webhook / toolkit_event); **cron also requires `cron_expression` (5-field, e.g. `0 8 * * *`)** + optional `cron_timezone` (IANA). Create it yourself when a cadence is given — never hand the schedule back, never use `workflows_set_schedule` for an agent-bound workflow.
- **When to use:** when the agent should act without a user prompt — a Monday-morning digest, a "when a new lead arrives" reaction.
- **Gotchas:** ⚠️ the trigger goes on the **agent**, never on a bound workflow. A trigger fires the agent's PUBLISHED version, so publish before relying on it. A recurring routine that's created but left un-triggered/draft will never fire — the classic recurring-digest failure.
- **Where:** agent sidebar → **Triggers**.

---

## E · Credentials & safety

### Secrets (Vault)
- **What it is:** a labeled, write-only placeholder for a credential the platform doesn't manage for you — a custom API key, an external-MCP header token, a webhook signing secret.
- **Supporting tools / params:** `aramb_mcp.vault_create_platform_secret` — args **`name`** + **`description`** (+ optional `value`, a dummy the user overwrites). A write-only placeholder the USER fills; you never see or ask for the real value.
- **When to use:** only when the design introduces a genuine standalone credential (a custom API, an external MCP server's auth). **NOT for OAuth toolkits** — those are connected, not keyed.
- **✅ DO create the placeholder with a dummy value + give a clickable edit link.** Unlike KB docs, **secrets ARE editable in the console** — so a dummy-valued placeholder is the *right* move (the opposite of KB): the user just edits the value in place. Create it, then make it a **build-summary completion item with a link** to the Vault tab.
- **Gotchas:** you create the placeholder; the user fills the real value. Never put the real secret anywhere you can see it.
- **Where:** the agent's **Vault** tab (`/app/agents/<agent-id>/vault`).

### Guardrails
- **What it is:** enforced safety/behavior rules — refusals, escalation, hand-off, "don't invent policy".
- **Supporting tools / params:** `aramb_mcp.agents_add_guardrail` / `list_guardrails` / `update_guardrail` / `remove_guardrail`, plus `set_default_guardrail` and `set_guardrails_config` (toggle the platform defaults + the master switch).
- **When to use:** whenever the archetype calls for boundaries — support/clinical/reputation agents especially (escalate refunds, legal, health, angry customers; don't guess).
- **Gotchas:** build the archetype's escalation path in as a first-class part of the design, not an afterthought. The platform ships default guardrails (no-fabrication, security, safe-actions) you can toggle per agent.
- **Where:** the agent's guardrails configuration.

---

## F · Verify & ship

### Tests
- **What it is:** scripted test suites that replay user turns against the real agent and grade the result against a `success_condition`.
- **Supporting tools / params:** the agent-tests skill → `aramb_mcp.agents_test_create` / `test_run` / `test_get_run` / `test_get_summary`. Each test scripts ≥3 user turns.
- **When to use:** when a persona has behaviors worth pinning — a safety gate, a refusal, a tone, a required tool call — so they survive future edits.
- **Gotchas:** ⚠️ `test_run` against the real persona IS the test — never hand-roll a side chat or write fixtures to disk. Offer a test suite in the build summary; build on a go-ahead.
- **Where:** agent sidebar → **Tests**.

### Publish
- **What it is:** own-use deploy — snapshots the draft as the live version end-users get.
- **Supporting tools / params:** `aramb_mcp.agents_publish` (proof = `published_version`).
- **When to use:** on the user's explicit go-ahead. Draft freely; publish deliberately.
- **Gotchas:** ⚠️ claim "published" ONLY when the result returns `published_version`. `workflow_publish_blockers` mean a bound workflow won't RUN until its toolkits are connected — name them; don't call it fully live.
- **Where:** top bar → **Publish** (lights up when the draft differs from the published version).

### Share / Export
- **What it is:** a public share link, or exporting the agent as a reusable template for OTHER orgs.
- **Supporting tools / params:** Share is a console action. Export is the platform's **Export** action — it runs the safety review and packages/variabilizes server-side. NOT your action.
- **When to use:** share to hand out a live link; export to publish a reusable template.
- **Gotchas:** ⚠️ never claim you variabilized/scanned/exported a template yourself — point the user to the Export action.
- **Where:** top bar → **Share**; the console **Export** action for templates.

### Monitor
- **What it is:** where the built agent is watched once it ships — real conversations and usage.
- **Supporting tools / params:** read real chats with `aramb_mcp.agents_conversation_search` / `conversation_get` (analyse-conversation skill) to ground improvements.
- **When to use:** after publish, to evaluate and iterate from real behavior (an UPDATE flow).
- **Where:** Monitor group → **Conversations**, **Dashboards**.

---

## Using this catalog in Phase 2

1. Start from the archetype's **default capability set** (agent-archetypes skill).
2. Walk this catalog top-to-bottom; for each primitive decide **needed / defer / n-a** + a one-line reason grounded in the capability spec. Don't add reflexively (a FAQ bot needs none of C beyond its KB); don't silently skip (name the deferral).
3. Collect the **build-summary completion items** as you go — every "needed" primitive that only the user can finish: toolkit connections (Tools → Integrations), external-MCP connections (Tools → MCP), binary KB uploads (Knowledge Base), real secret values (Vault).
4. Carry the decisions into the Phase-3 plan; execute the ones you can, hand back the rest in the build summary.
