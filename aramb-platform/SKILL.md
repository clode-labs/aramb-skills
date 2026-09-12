---
name: aramb-platform
description: >
  HOW to operate the aramb platform on the user's behalf — the full action-set a
  console power-user has, driven from the channel. Use once you've decided a task
  is worth an agent: build or change an agent via the Architect and drive it to
  live; talk to / run any published agent; reuse a template; hire, fire, or manage
  a listing; and finish setup (create a trigger, connect a toolkit) so the user
  doesn't have to touch a console. This is the MECHANICS; `agent-strategy` is the
  JUDGMENT (WHETHER, and WHICH path). NOT for one-off web/browser tasks you just do
  yourself, and NOT for building an app or webpage.
---

# Operating the aramb platform (on the user's behalf)

> **Supersedes `aramb-orchestrator`.** This skill renames and broadens it. The old
> `aramb-orchestrator` (unmerged, on `feat/woky-orchestration-skills`) should be
> renamed to `aramb-platform`; do not ship both. It also **corrects the namespace**:
> the old skill's `aramb_mcp.architect_ask` / `a2a_send_message` names were wrong —
> the real wire namespace is `aramb_orchestrate.*` (see below).

You don't only do things yourself. You can put the **whole platform** to work for a
channel-only user who has no console: build agents, run them, hire ready-made ones,
and wire up their triggers and toolkits — all through your tools, so the user acts
by tapping a WhatsApp link at most.

## Judgment first, then these mechanics

Decide **whether** to build/reuse and **which** path with **`agent-strategy`** —
that's the judgment (will the user want this again? hire vs import vs build?). This
skill is only **how** to execute the path you chose. Don't re-litigate the decision
here; don't hand-roll platform calls there.

## Namespace — every action is a real MCP tool

Three namespaces, and nothing else reaches the platform:

- **`aramb_orchestrate.*`** — your main surface: delegate to the Architect, talk to
  agents, and (as they land) reuse/hire/setup verbs.
- **`aramb_agents.*`** — you have **exactly three**: `list`, `get`, `publish`. Read
  and publish only; you never create or edit an agent config yourself.
- **`aramb_my_triggers.*`** — your own watchers/crons (self-scoped to you). See the
  **`watchers`** skill for the drive-to-done loop.

Some verbs below are **LIVE** today; others are **being wired** (Slice C/D of this
epic). Call a being-wired verb only once it actually appears in your tools — if it
isn't there yet, frame the intent to the user and take a LIVE path instead. Never
force a missing capability through `Bash` or by hand-hitting `/mcp`.

---

## Build / change an agent  — LIVE

Building an agent is one of your most important jobs and you own it end to end — but
you **delegate** it to the Architect (the special one-per-user agent that builds
agents) and **drive** it. You never write the agent yourself, and "build an agent"
never means writing a webpage, HTML, or a script.

**The build loop:**

1. **Get the spec.** A couple of quick channel questions — what it does, who it's
   for, how it behaves, any tools/integrations, an example — then move.
2. **Delegate** — `aramb_orchestrate.ask_architect(request=<a full, plain-language
   spec>)`. Returns a `chat_id`; it builds **asynchronously** (minutes). Optional
   `auto_publish=true` is only an **advisory nudge** in the request text — you still
   drive publish yourself (step 6). Don't block; don't drop it.
3. **Set a watcher** so you come back on your own —
   `aramb_my_triggers.create_watcher(message="check the architect on chat <chat_id>
   and continue the build", in="2m")`. (See **`watchers`**.)
4. **On wake, read the real state** — a watcher carries none:
   `aramb_orchestrate.get_messages(chat_id)`.
   - Architect asks a question → relay it to the user in short, plain WhatsApp words,
     take their answer, feed it back with
     `aramb_orchestrate.send_message(chat_id=<chat_id>, message=…)`, then re-arm a
     watcher.
   - Still working / not done → re-arm a watcher and keep looping.
5. **Verify before you claim** — `aramb_agents.get` (or `aramb_agents.list`): does
   the agent actually exist? "The Architect said so" is not enough.
6. **Publish** — `aramb_agents.publish`. Confirm it's really published before you say
   so.
7. **Let the user try it** — talk to the built agent for real:
   `aramb_orchestrate.send_message(agent_id=<built agent>, message=…)` → read its
   **real** reply with `aramb_orchestrate.get_messages(chat_id)` and relay that. Then
   hand it over.

## Talk to / run an agent (A2A)  — LIVE

Put any published agent to work and read its reply:

- `aramb_orchestrate.send_message({message, agent_id | chat_id})` → `{chat_id}`.
  Start a conversation with a published agent by `agent_id`; continue it with the
  returned `chat_id`. Auto-wakes the target.
- `aramb_orchestrate.get_messages({chat_id, since?})` — read the recent tail. Fire
  a message, set a watcher, then read on wake — never assume a reply arrived.

## Reuse a template  — being wired (Slice C)

Prefer an existing template over a bespoke build when `agent-strategy` says so:

- `aramb_orchestrate.templates_search({query?, limit?})` — browse the catalog.
- `aramb_orchestrate.templates_import({slug, name?})` — instantiate a template into
  the user's org as their own customizable copy.

## Hire / manage a listing  — being wired (Slice C)

The fastest path — a vendor-maintained agent that already does the job:

- `aramb_orchestrate.listings_search({query?, limit?})` — browse agents-for-hire.
- `aramb_orchestrate.hire({slug, version?})` — hire a published listing into the
  user's org.
- `aramb_orchestrate.fire({agent_id})` — end a hire. Always go through this verb; a
  fired hire is denied active routes by design — don't try to unwind a hire any other
  way.

## Finish setup on the user's behalf  — being wired (Slice C/D)

A channel-only user has no console, so **you** complete the wiring instead of handing
them a card of manual steps. Do everything that can be done without a genuinely
user-only secret; only a real OAuth tap or a real secret value goes back to the user.

- **Create a trigger on the built/hired agent** —
  `aramb_orchestrate.agents_trigger_create({agent_id, kind, cron_expression? |
  trigger_slug? + connected_account_id? | message_key?})`. Because you run in the
  user's own lane, the trigger is **owned by the user** (accountable member) — you
  can own it where the Architect (a service account) cannot. Use this to put "every
  morning" / "whenever an email comes" onto the agent you just set up. *Being wired.*
- **Connect a toolkit via a one-time link (the magic-link)** — for a toolkit the user
  must authorize (Gmail, a Sheet, etc.):
  1. `aramb_orchestrate.request_toolkit_connection({toolkit, agent_id})` →
     `{connect_url, expires_at, toolkit, agent_id}`. `agent_id` is **required** — a
     connection is made at the agent level (an unscoped one never resolves at
     runtime). `connect_url` is a brahmi-signed, single-use, ~15-min link.
  2. Send `connect_url` over the channel — the user taps it once and authorizes with
     the provider (no console login). The link is one-time and expiring; if it lapses,
     mint a fresh one.
  3. Set a watcher, then on wake confirm with
     `aramb_orchestrate.check_toolkit_connection({agent_id, toolkit | connected_account_id})`
     → `{connected, status, connected_account_id}`; continue only once it reads
     connected. *Being wired (Slice D).*
- **No-auth / non-secret MCP** — you do **not** attach this yourself; the **Architect**
  binds no-auth MCP (and drops dummy placeholders for real secrets) during the build.
  Put the integration in your `ask_architect` spec and let it finish that setup. Only
  genuinely user-only steps (an OAuth tap, a binary upload, a real secret value) ever
  come back to the user.

**Honesty about setup (P6):** never tell the user an agent is "live / ready /
running" while a required toolkit, MCP, or trigger is still unconnected. The honest
line is "built — setup incomplete: <what's missing>", followed by the magic-link or
question that closes it.

---

## LIVE today vs being wired

| Action | Verb | Status |
|--------|------|--------|
| Delegate a build/update to the Architect | `aramb_orchestrate.ask_architect` | **LIVE** |
| Talk to / run an agent | `aramb_orchestrate.send_message` | **LIVE** |
| Read an agent's reply | `aramb_orchestrate.get_messages` | **LIVE** |
| See / verify agents | `aramb_agents.list` / `aramb_agents.get` | **LIVE** |
| Publish a built agent | `aramb_agents.publish` | **LIVE** |
| Watchers / crons (your own) | `aramb_my_triggers.create_watcher` / `create_cron` / `list` / `cancel_watcher` | **LIVE** |
| Search templates | `aramb_orchestrate.templates_search` | being wired |
| Import a template | `aramb_orchestrate.templates_import` | being wired |
| Search listings | `aramb_orchestrate.listings_search` | being wired |
| Hire a listing | `aramb_orchestrate.hire` | being wired |
| Fire a hire | `aramb_orchestrate.fire` | being wired |
| Trigger on the built agent | `aramb_orchestrate.agents_trigger_create` | being wired |
| Toolkit connect (magic-link) | `aramb_orchestrate.request_toolkit_connection` | being wired |
| Confirm a toolkit connection | `aramb_orchestrate.check_toolkit_connection` | being wired |

`aramb_agents` beyond `list/get/publish` (create / update / trigger_create / kb /
templates) is **not yours** — it's Architect/builder-only. Delegate that work to the
Architect; don't reach for it.

## Guardrails — never do it the wrong way

Hard rules. Breaking them is a failure even if it "works":

- **Never** read `mcporter.json`, `native-mcp.json`, or any bearer/auth token.
- **Never** `curl` or otherwise hand-hit the MCP endpoint (`/mcp/...`). The tools
  above are the only sanctioned way to reach the platform.
- **Never** build, configure, hire, trigger, connect, test, or run an agent through
  `Bash`/scripts. If a capability isn't in your tools, that's on purpose — delegate
  it or wait for the verb; don't force it.
- **Never** call a **being-wired** verb before it appears in your tools. Frame the
  intent to the user and take a LIVE path instead.
- **Never** claim an agent was built, published, hired, or run — and never present a
  story/answer as coming from an agent — unless a tool actually returned it:
  `aramb_orchestrate.get_messages` for the reply, `aramb_agents.get` for existence,
  a real `aramb_orchestrate.send_message` conversation for "the user can use it", and
  `aramb_orchestrate.check_toolkit_connection` for a connected toolkit.
- **"Drive it to completion no matter what"** means **finish the delegation loop** —
  it never means bypassing the platform's own tools or faking an outcome.
