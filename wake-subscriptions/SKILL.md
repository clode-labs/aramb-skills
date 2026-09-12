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

- `aramb_wake.at(message, in | fire_at)` — a **one-shot** self-wake. `in` is a Go
  duration (`"30s"`, `"2m"`, `"2h"`); `fire_at` is an absolute RFC3339 UTC time. Pass
  exactly one. `message` is handed back to you verbatim on wake, so write a clear
  instruction to your future self **including any id you'll need** (a `chat_id`, an
  agent id, a browser session id / `context_name`).
- `aramb_wake.schedule(name, cron_expression, cron_timezone)` — a **recurring**
  wake, for "every morning / every hour / every Monday". Use this (not a chain of
  one-shots) when the cadence repeats. `cron_expression` is a standard 5-field cron;
  `cron_timezone` is IANA (default UTC).
- `aramb_wake.cancel(watcher_id)` — drop a pending one-shot.
- `aramb_wake.list` — see your pending wakes (and their ids).

These wakes are invisible and private to you — the user never sees them fire; they
only see you follow up when there's something real to say.

## Waking around browser work — launch, end turn, wake, resume

Driving a browser for a real WhatsApp / Slack / voice user is the **canonical
timed-wake case**, because the browser often **blocks on something you can't finish in
one turn** — and no one is watching it to nudge it along. The automatic completion-wake
does NOT cover this: it fires only for delegated `aramb_a2a` / `aramb_architect` jobs,
and a browser wait is not a delegated job. So a browser wait needs a **timed
`aramb_wake.at`** you set yourself.

The loop, whenever a browser step will take time OR needs the user to act out-of-band:

1. **Launch / reach the blocking point** — e.g. you hit a login or payment wall and sent
   a `browser.creds` vault link (see the `aramb-browser` skill's *"Login & credential
   walls"*), or you kicked off a slow checkout, a background captcha auto-solve, or a
   page you must poll.
2. **End your turn and set `aramb_wake.at`** — put in the `message` everything future-you
   needs to resume: the browser **session id / `context_name`**, the site, the alias, and
   what you were mid-doing. Pick a sensible delay (a creds fill: minutes; a slow page:
   seconds-to-minutes).
3. **On wake, re-open the SAME browser context** (same session id / `context_name`) —
   never start a fresh login you already began — read the real state, and continue:
   `vault_get_secret` and fill, read the checkout result, re-check the page.
4. **End in the typed outcome below.** Creds are in and you continued → `stop` (or
   `notify_user` with the result). Still not filled / page still loading → `continue`
   with `progressed=false` (a **silent** re-arm, no user message) up to your wait budget.
   Wait budget exhausted → `blocked` (tell the user plainly what's still needed).

Cases this covers: waiting for a user to fill a **`browser.creds` vault link** (send link
→ end turn → wake → re-open session → continue login/payment), an **OTP / email** the
user must forward, a **slow page or checkout**, a **captcha** auto-solving in the
background, or **polling** a site for a state change. In every one: end the turn, set the
wake, don't sit and spin.

## The rule that matters: a wake carries NO state — go check

When any wake fires — automatic or timed — you know **nothing** yet beyond the note.
Go read the *actual* state, and **which tool** you use depends on what you were
waiting on:

- **An agent / the Architect** → `aramb_mcp.a2a_get_messages(chat_id)` to read its
  reply, and for a build cross-check the ground truth with `aramb_mcp.agents_get`
  (did the agent really get created / published?). Never trust the reply alone.
- **Your own browser** → your `aramb_browser` tools: what page is it on, did the step
  fail, a screenshot. A WhatsApp user isn't there to guide it, so an autonomous browser
  step is *yours* to drive to done — on wake, re-open the same session, check it, and act:
  fill the now-stored creds and continue, retry, save context, or tell the user what's
  blocking. (This is how you drive a **long or blocked** browser task, not only recover a
  failed one — see *Waking around browser work* above.)
- **Something on the web / a price / a reply** → re-fetch / re-open and read it.

Then end the wake in exactly ONE typed outcome — this is the decision, not loose
"am I done?" prose:

- **stop** — the work is done or abandoned. Disarm; write to the user only if there's a
  real result to deliver.
- **continue** — re-arm and keep going, and be honest about whether anything actually
  changed. For a delegated job, just end your turn again (the automatic wake fires on the
  next response); for a time-based / browser check, set a **new** `aramb_wake.at`. If
  **nothing changed** this tick (`progressed = false` — the delegate is still working, the
  vault is still empty, the page hasn't moved), re-arm **silently**: do NOT message the
  user. A silent re-check that surfaces "still working / nothing yet / all done" is spam —
  the exact failure to avoid.
- **notify the user** — surface something ONLY when there's a real result, a real
  question, or a decision the user must make. This is the ONLY outcome that produces a
  user message on its own.
- **blocked** — you can't proceed without the user or an external event (creds still not
  filled past your wait budget, an approval, an outage). Say plainly what's blocking and
  what you need, then stop or park — don't keep re-arming into a wall.

A one-shot `aramb_wake.at` does **not** repeat — a `continue` re-arm is how you carry a
slow, time-based job to the last mile. Keep the interval sensible (short for something
imminent, longer for a slow build), and don't re-arm forever on no progress: after several
silent no-progress ticks, `stop` or go `blocked` rather than waking indefinitely (the
platform also caps runaway re-arm chains). For a genuinely repeating cadence, use
`aramb_wake.schedule` instead of re-arming forever.

## Honesty

Never tell the user you're "watching", "monitoring", or "keeping an eye on" something
unless it's actually true — either you delegated a job (whose completion-wake is
automatic) or you set an `aramb_wake.at` / `aramb_wake.schedule`. A claimed watch that
doesn't exist is a broken promise the user is counting on.

And stay **silent by default**: a wake that found nothing new says nothing (that's a
`continue` with `progressed=false`). You speak only on a real result, a real question, or
a block — never to report "still working" or "nothing yet".
