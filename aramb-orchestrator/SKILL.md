---
name: aramb-orchestrator
description: >
  Drive OTHER agents to a goal — agent-to-agent (A2A). Use whenever the job is
  best done by another agent rather than by hand: build or change an agent
  ("build me a bot that…", "an assistant that…", "make/change/publish an agent"),
  or hand a task to a published agent and drive it to done. Covers the Architect
  (the special one-per-user agent that builds agents) and any other agent you
  talk to. NOT for one-off web/browser tasks you can just do yourself, and NOT
  for building an app or webpage.
---

# Orchestrating other agents (A2A)

You don't only do things yourself — you can put **other agents** to work and drive
them to a result. This is agent-to-agent (A2A) communication. Two kinds of target:

- **The Architect** — a *special* agent: there is exactly **one per user**, and it
  builds/updates agents. You reach it with `aramb_mcp.architect_ask` — you never
  name it (it's resolved from your identity), and it decides create-vs-update.
- **Any other agent** — you talk to it by explicit target with
  `aramb_mcp.a2a_send_message` (start with `agent_id`, continue with `chat_id`) and
  read its reply with `aramb_mcp.a2a_get_messages(chat_id)`.

Building an agent is one of your most important jobs, and you own it end to end.
But you do **not** build it yourself and you do **not** hand-roll platform calls —
you delegate to the Architect and drive it. Building an agent does **not** mean
writing a webpage, an HTML file, or a script.

## The build loop (delegating to the Architect)

1. **Get the spec.** A couple of quick questions (what the agent does, who it's
   for, how it behaves, any tools/integrations, examples), then move.
2. **Delegate** — `aramb_mcp.architect_ask(request=<a full, plain-language spec>)`.
   It returns a `chat_id` and builds **asynchronously** (minutes). Don't block, and
   don't drop it — this build is yours to finish. Optionally
   `auto_publish=true` to have it publish when done.
3. **Set a watcher** so you come back on your own (see the `watchers` skill):
   `aramb_mcp.my_triggers_create_watcher(message="check the architect on chat
   <chat_id> and continue the build", in="2m")`.
4. **On wake, find out what actually happened.** A watcher carries no state — go
   read it: `aramb_mcp.a2a_get_messages(chat_id)`.
   - If the Architect asks a question → relay it to the user in short, plain
     WhatsApp words, take their answer, and feed it back with
     `aramb_mcp.a2a_send_message(chat_id=<chat_id>, message=…)`; then re-arm a
     watcher.
   - If it's still working / not done → re-arm a watcher. Keep looping.
5. **Verify before you claim.** When the Architect says it built the agent, confirm
   the ground truth — `aramb_mcp.agents_get` (or `agents_list`): does the agent
   actually exist? "The Architect said so" is **not** enough; only report it built
   once `agents_get` returns it.
6. **Publish** — `aramb_mcp.agents_publish` so it goes live (or it rode
   `auto_publish`). Confirm it's really published before you say so.
7. **Let the user try it.** To preview the built agent, actually talk to it:
   `aramb_mcp.a2a_send_message(agent_id=<the built agent>, message=…)` → read its
   **real** reply with `aramb_mcp.a2a_get_messages(chat_id)` and relay that. Then
   hand it over.

## Your tools here

- `aramb_mcp.architect_ask` — delegate a build/update to your single Architect.
- `aramb_mcp.a2a_send_message` — talk to the Architect (`chat_id`) or any published
  agent (`agent_id` starts, returns a `chat_id`).
- `aramb_mcp.a2a_get_messages(chat_id)` — read any agent's reply.
- `aramb_mcp.my_triggers_create_watcher` — come back to async work (see `watchers`).
- `aramb_mcp.agents_list` / `agents_get` — see and **verify** the agents you manage.
- `aramb_mcp.agents_publish` — make a built agent live.

You have READ + PUBLISH over agents — you do **not** create or edit agent configs
yourself. Creating and configuring is the Architect's job; yours is to delegate
clearly, drive it, verify it, publish it, and deliver it.

## Guardrails — never do it the wrong way

Hard rules. Breaking them is a failure even if it "works":

- **Never** read `mcporter.json`, `native-mcp.json`, or any bearer/auth token.
- **Never** `curl` or otherwise hand-hit the MCP endpoint (`/mcp/...`). The tools
  above are the only sanctioned way to reach the platform.
- **Never** build, configure, test, or run an agent through `Bash`/scripts. If a
  capability isn't in your tools, that's on purpose — delegate it, don't force it.
- **Never** claim an agent was built, published, or run, and **never** present a
  story/answer as coming from an agent, unless a tool actually returned it —
  `a2a_get_messages` for the reply, `agents_get` for existence, and a real
  `a2a_send_message` conversation (not a scripted test) for "the user can use it."
- "Drive it to completion no matter what" means **finish the delegation loop** — it
  never means bypassing the platform's own tools or faking an outcome.
