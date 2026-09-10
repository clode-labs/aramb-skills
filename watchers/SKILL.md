---
name: watchers
description: >
  Drive autonomous / async work to completion by scheduling YOURSELF to come back
  — a WATCHER. Use whenever a job can't finish in one turn and no one is there to
  poke you: waiting on something async (an agent build, another agent, a workflow),
  recovering an autonomous browser step that failed, checking back on a price /
  reply / status, or reminding the user at a time you promised. Use the recurring
  variant for "do X every morning / every hour". NOT for firing another agent's
  workflow on an external service event (that's a toolkit trigger).
---

# Watchers — how to drive work to done on your own

A **watcher** is a private alarm you set for *yourself*. At the time you pick it
wakes you — invisibly, in this same conversation — and hands you back the `message`
you wrote. It's what turns you from a one-shot responder into an assistant who
**starts things, comes back, and drives them to done** without the user keeping you
alive. The user never sees it fire; they only see you follow up when there's
something real to say.

## The tools

- `aramb_mcp.my_triggers_create_watcher(message, in | fire_at)` — a **one-shot**
  wake. `in` is a Go duration (`"30s"`, `"2m"`, `"2h"`); `fire_at` is an absolute
  RFC3339 UTC time. Pass exactly one. `message` is delivered to you verbatim on
  wake, so write a clear instruction to your future self **including any id you'll
  need** (a `chat_id`, an agent id, a browser session).
- `aramb_mcp.my_triggers_create_cron(...)` — a **recurring** schedule, for "every
  morning / every hour / every Monday". Use this (not a chain of one-shots) when the
  cadence repeats.
- `aramb_mcp.my_triggers_cancel_watcher(watcher_id)` — drop a pending one.
- `aramb_mcp.my_triggers_list` — see your pending ones (and their ids).

## The rule that matters: a watcher carries NO state — go check

When a watcher wakes you, you know **nothing** yet — it's just a timer. You have to
go read the *actual* state, and **which tool** you use depends on what you were
watching:

- **An agent / the Architect** → `aramb_mcp.a2a_get_messages(chat_id)` to read its
  reply, and for a build cross-check the ground truth with `aramb_mcp.agents_get`
  (did the agent really get created / published?). Never trust the reply alone.
- **Your own browser** → your `aramb_browser` tools: what page is it on, did the
  step fail, a screenshot. A WhatsApp user isn't there to guide it, so an
  autonomous browser step that fails is *yours* to recover — on wake, check it and
  act: retry, open a fresh browser, save context, or tell the user what's blocking.
- **Something on the web / a price / a reply** → re-fetch / re-open and read it.

Then decide:

1. **Done?** → act on the real result and tell the user. Don't set another.
2. **Not done yet?** → set a **new** watcher and keep going.

A one-shot watcher does **not** repeat — that re-arm loop is how you carry a long
job to the last mile. Keep the interval sensible (short for something imminent,
longer for a slow build) so you're not waking constantly. For a genuinely repeating
cadence, use `create_cron` instead of re-arming forever.

## Honesty

Never tell the user you're "watching", "monitoring", or "keeping an eye on"
something unless you actually created a watcher (or cron) for it. A claimed watch
that doesn't exist is a broken promise the user is counting on.
