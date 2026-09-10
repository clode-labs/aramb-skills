---
name: woky-orchestrator
description: >
  Build or change an AGENT for the user by delegating to the Architect and
  driving it to done. Use whenever the user wants an agent — "build me a bot
  that…", "an assistant that…", "something that answers…", "make/change/publish
  an agent" — or when you've pitched a repeatable use-case and they said yes.
  Covers the whole loop: brief the Architect, watch for its reply, relay its
  questions, publish, and let the user try the result. NOT for one-off web/browser
  tasks (just do those) and NOT for building an app or webpage.
---

# Building agents — you delegate to the Architect and drive it to done

Building an agent is one of your most important jobs, and you own it end to end.
But you do **not** build it yourself and you do **not** hand-roll platform calls.
You have exactly one builder — the **Architect** — and a small set of tools to
direct it and deliver the result. Building an agent does **not** mean writing a
webpage, an HTML file, or a script; it means standing up a real aramb agent
through the Architect.

## The loop

1. **Get the spec.** Ask only what you genuinely need (what the agent does, who
   it's for, how it should behave, any tools/integrations, examples). A couple of
   quick questions, then move.
2. **Delegate to the Architect** — `aramb_mcp.orchestrate_ask_architect(request=<a
   full, plain-language spec>)`. There is **one Architect per user**; it works out
   whether to create a new agent or update an existing one, so just describe what
   you want. It returns a `chat_id` and builds **asynchronously** (minutes) — do
   not block on it, and do not drop it: this build is yours to finish.
3. **Set a watcher** so you come back on your own (see the `watchers` skill):
   `aramb_mcp.my_triggers_create_watcher(message="check the architect on chat
   <chat_id> and continue the build", in="2m")`.
4. **On wake, read the reply** — `aramb_mcp.orchestrate_get_messages(chat_id)`.
   - If the Architect asks something → relay it to the user in short, plain
     WhatsApp words (never tool/platform jargon), take their answer, and feed it
     back with `aramb_mcp.orchestrate_send_message(chat_id=<chat_id>, message=…)`.
   - Then **re-arm a watcher**. Keep looping — don't stop, and don't tell the user
     it's done, until the Architect confirms a built, working agent.
5. **Publish it** so it goes live — `aramb_mcp.orchestrate_ask_architect(...,
   auto_publish=true)` handles this, or publish it yourself with
   `aramb_mcp.agents_publish`. Confirm it's really published before you say so.
6. **Let the user try it.** To preview the built agent, actually talk to it:
   `aramb_mcp.orchestrate_send_message(agent_id=<the built agent>, message=…)` →
   read its real reply with `aramb_mcp.orchestrate_get_messages(chat_id)` and relay
   that. Then hand it over.

## Your tools here

- `aramb_mcp.orchestrate_ask_architect` — delegate a build/update to the Architect.
- `aramb_mcp.orchestrate_send_message` — talk to the Architect (`chat_id`) or to a
  published agent (`agent_id` starts a conversation, returns a `chat_id`).
- `aramb_mcp.orchestrate_get_messages(chat_id)` — read a reply.
- `aramb_mcp.my_triggers_create_watcher` — come back to async work (see `watchers`).
- `aramb_mcp.agents_list` / `agents_get` — see and inspect the agents you look after.
- `aramb_mcp.agents_publish` — make a built agent live.

You have READ + PUBLISH over agents — you do **not** create or edit agent configs
yourself. Creating and configuring is the Architect's job; yours is to delegate
clearly, drive it, publish it, and deliver it.

## Guardrails — never do it the wrong way

These are hard rules. Breaking them is a failure even if it "works":

- **Never** read `mcporter.json`, `native-mcp.json`, or any bearer/auth token.
- **Never** `curl` or otherwise hand-hit the MCP endpoint (`/mcp/...`). Use the
  tools above — that's the only sanctioned way to reach the platform.
- **Never** build, configure, test, or run an agent through `Bash`/scripts. If a
  capability isn't in your tools, that's on purpose — delegate it, don't force it.
- **Never** claim an agent was built, published, or run, and **never** present a
  story/answer as coming from an agent, unless a tool actually returned it. Running
  a scripted test is not the same as the agent working for the user — don't pass one
  off as the other. Report only what `get_messages` really returned.
- "Drive it to completion no matter what" means **finish the delegation loop** — it
  never means bypassing the platform's own tools or faking an outcome.
