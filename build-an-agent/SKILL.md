---
name: build-an-agent
description: >
  How to get a new agent built, verified, published and handed over — by
  delegating to the Architect (`aramb_mcp.architect_ask`), driving it to done,
  and confirming with `aramb_mcp.agents_get` before you claim anything. Use ONLY
  when the user EXPLICITLY asks for an agent ("build me an agent", "make a bot
  that…", "change/publish my agent"). NOT a routing step — never ask yourself
  "should this be an agent?" about ordinary work; that work goes to a worker (see
  `delegation`). NOT for building a webpage, an app, or a script, and NOT for
  creating a workflow.
---

# Building an agent

Building an agent is delegated work like any other: the **Architect** builds it, you
drive it to done, verify it, publish it, and hand it over. You do not write agent
configs yourself and you do not hand-roll platform calls.

The Architect is a *special* agent — there is exactly **one per user**, you never name
it (it is resolved from your identity), and it decides create-vs-update for itself.

## This fires on an explicit request, and only then

- The user asks for an agent in so many words → you are in the right place.
- The user asks for **work** — find something, book something, compare something,
  produce something → that is a worker's job. Route it with `delegation`.

**"Should this be an agent?" is not a question you ask.** It is not a step in any
routing decision, it is not a suggestion you volunteer, and an agent is never something
you build because a request looked repeatable. If the user did not ask for one, they do
not get one.

And **never build a workflow for yourself.** Standalone workflow triggers are
deprecated for you; what you need instead is a worker (`delegation`) or a wake
(`wake-subscriptions`).

## The build loop

1. **Get the spec.** A couple of quick questions — what the agent does, who it is for,
   how it should behave, any tools or integrations it needs, an example or two. Then
   move; do not interview.
2. **Delegate** — `aramb_mcp.architect_ask(request=<a full, plain-language spec>)`. It
   returns a `chat_id` and builds **asynchronously**, over minutes. Pass
   `auto_publish=true` if it should go live the moment it is built.
3. **End your turn.** You are woken automatically when the Architect responds — you do
   **not** arm a watcher for a delegated build, and you do not poll. Say what you kicked
   off, and stop.
4. **On wake, find out what actually happened.** The wake carries no state. Read it:
   `aramb_mcp.a2a_get_messages(chat_id)`.
   - **It asked a question** → relay it to the user in short, plain words, take their
     answer, feed it back with `aramb_mcp.a2a_send_message(chat_id=…, message=…)`, and
     end your turn again.
   - **It is still working** → end your turn; the next response wakes you.
5. **Verify before you claim** — `aramb_mcp.agents_get` (or `agents_list`). Does the
   agent actually exist, with the configuration the Architect described? *"The Architect
   said so"* is not evidence. Only report it built once the read returns it.
6. **Publish** — `aramb_mcp.agents_publish`, unless it rode `auto_publish`. Confirm it
   is really published before you say it is.
7. **Let the user try it.** Talk to the built agent for real:
   `aramb_mcp.a2a_send_message(agent_id=<the new agent>, message=…)` → read its **actual**
   reply with `aramb_mcp.a2a_get_messages(chat_id)` and relay that. A scripted "it works"
   is not a preview. Then hand it over.

## Your tools here

- `aramb_mcp.architect_ask` — delegate a build or a change to your single Architect.
- `aramb_mcp.a2a_send_message` / `aramb_mcp.a2a_get_messages` — talk to the Architect on
  its `chat_id`, and to the built agent on its `agent_id`.
- `aramb_mcp.agents_list` / `aramb_mcp.agents_get` — see and **verify** the agents you
  manage.
- `aramb_mcp.agents_publish` — make a built agent live.

You hold **read + publish** over agents. Creating and configuring is the Architect's
job; yours is to brief it clearly, drive it, verify it, publish it, and deliver it.

## Hard lines

- **Never** read `mcporter.json`, `native-mcp.json`, or any bearer/auth token.
- **Never** `curl` or otherwise hand-hit the MCP endpoint. The tools above are the only
  sanctioned way to reach the platform.
- **Never** build, configure, test, or run an agent through `Bash` or a script. A
  capability missing from your tools is missing on purpose — delegate it, don't force it.
- **Never** claim an agent was built, published, or tried unless a tool returned it:
  `agents_get` for existence, `a2a_get_messages` for a real reply.
- "Drive it to completion" means **finish the delegation loop**. It never means going
  around the platform's own tools or narrating an outcome you did not observe.
