---
name: wake-subscriptions
description: >
  How you get woken to drive async / long-running work to done. TWO mechanisms:
  (1) AUTOMATIC — when you delegate a job (aramb_a2a / aramb_architect) and end your
  turn, the platform wakes you by itself the moment that job responds; you do NOT
  set anything. (2) TIMED — you wake YOURSELF at a chosen time with aramb_wake.at
  (one-shot) or aramb_wake.schedule (recurring), for genuinely clock-based follow-ups
  ("re-check in 10 min", "every morning at 9"). Use whenever a job can't finish in
  one turn and no one is there to poke you. NOT for firing another agent's workflow
  on an external service event (that's a toolkit trigger).
---

# Wake subscriptions — how you come back and finish the job

You are often a one-shot responder: you reply, your turn ends, you go quiet. Long or
async work breaks that — you kick something off, but the result arrives later, after
your turn is over. **Wake subscriptions are how you come back.** There are two, and
the first one means you usually don't have to lift a finger.

## 1. Automatic completion-wake — you delegate, the platform wakes you

**When you delegate work and end your turn, the platform automatically wakes you the
moment that work responds.** You do NOT call any tool to arm this — it is built in.

It covers the two delegation tools:

- `aramb_mcp.a2a_send_message` — you message another agent / conversation.
- `aramb_mcp.architect_ask` — you ask the Architect to build or change an agent.

Send the request, then **end your turn** (say what you've kicked off and stop — do
not sit in a poll loop, do not immediately re-check). When the agent or the Architect
finishes its turn — including when it pauses to **ask you a question** like
"Go ahead?" — you are woken back in this same conversation with a note telling you
which chat responded. That's your cue to go read it (see the rule below) and act.

So the normal delegation flow is simply:

1. `a2a_send_message` / `architect_ask` → you get back a `chat_id`.
2. End your turn. (You'll be woken — no timer needed.)
3. On wake: `aramb_mcp.a2a_get_messages(chat_id="…")`, read the reply, and continue —
   answer its question, publish the built agent, or relay the result to the user.

You do **not** need a timed self-wake for delegated work, and you should not set one
"just in case" — the automatic wake already has it covered.

## 2. Timed self-wake — you pick the time

For a genuinely **time-based** follow-up that isn't tied to a delegated job — "re-check
the deploy in 10 minutes", "remind the user tomorrow morning", "post a digest every
day at 9" — wake yourself:

- `aramb_mcp.wake_at(message, in | fire_at)` — a **one-shot** self-wake. `in` is a Go
  duration (`"30s"`, `"2m"`, `"2h"`); `fire_at` is an absolute RFC3339 UTC time. Pass
  exactly one. `message` is handed back to you verbatim on wake, so write a clear
  instruction to your future self **including any id you'll need** (a `chat_id`, an
  agent id, a browser session).
- `aramb_mcp.wake_schedule(name, cron_expression, cron_timezone)` — a **recurring**
  wake, for "every morning / every hour / every Monday". Use this (not a chain of
  one-shots) when the cadence repeats. `cron_expression` is a standard 5-field cron;
  `cron_timezone` is IANA (default UTC).
- `aramb_mcp.wake_cancel(watcher_id)` — drop a pending one-shot.
- `aramb_mcp.wake_list` — see your pending wakes (and their ids).

These wakes are invisible and private to you — the user never sees them fire; they
only see you follow up when there's something real to say.

## The rule that matters: a wake carries NO state — go check

When any wake fires — automatic or timed — you know **nothing** yet beyond the note.
Go read the *actual* state, and **which tool** you use depends on what you were
waiting on:

- **An agent / the Architect** → `aramb_mcp.a2a_get_messages(chat_id)` to read its
  reply, and for a build cross-check the ground truth with `aramb_mcp.agents_get`
  (did the agent really get created / published?). Never trust the reply alone.
- **Your own browser** → your `aramb_browser` tools: what page is it on, did the step
  fail, a screenshot. A WhatsApp user isn't there to guide it, so an autonomous
  browser step that failed is *yours* to recover — on wake, check it and act: retry,
  open a fresh browser, save context, or tell the user what's blocking.
- **Something on the web / a price / a reply** → re-fetch / re-open and read it.

Then decide:

1. **Done?** → act on the real result and tell the user. Don't set another wake.
2. **Not done yet?** → for a delegated job, just end your turn again (the automatic
   wake fires on the next response); for a time-based check, set a **new**
   `wake_at` and keep going.

A one-shot `wake_at` does **not** repeat — that re-arm loop is how you carry a slow,
time-based job to the last mile. Keep the interval sensible (short for something
imminent, longer for a slow build) so you're not waking constantly. For a genuinely
repeating cadence, use `wake_schedule` instead of re-arming forever.

## Honesty

Never tell the user you're "watching", "monitoring", or "keeping an eye on" something
unless it's actually true — either you delegated a job (whose completion-wake is
automatic) or you set a `wake_at` / `wake_schedule`. A claimed watch that doesn't
exist is a broken promise the user is counting on.
