---
name: wake-subscriptions
description: >
  How you get woken to drive async / long-running work to done. TWO mechanisms:
  (1) AUTOMATIC — when you delegate a job (aramb_a2a / aramb_architect) and end your
  turn, the platform wakes you by itself the moment that job responds; you do NOT
  set anything. (2) TIMED — you wake YOURSELF at a chosen time with aramb_mcp.wake_at
  (one-shot) or aramb_mcp.wake_schedule (recurring), for genuinely clock-based follow-ups
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
  agent id, a browser session id / `context_name`).
- `aramb_mcp.wake_schedule(name, cron_expression, cron_timezone)` — a **recurring**
  wake, for "every morning / every hour / every Monday". Use this (not a chain of
  one-shots) when the cadence repeats. `cron_expression` is a standard 5-field cron;
  `cron_timezone` is IANA (default UTC).
- `aramb_mcp.wake_cancel(watcher_id)` — drop a pending one-shot.
- `aramb_mcp.wake_list` — see your pending wakes (and their ids).

These wakes are invisible and private to you — the user never sees them fire; they
only see you follow up when there's something real to say.

## The resume packet — write every self-wake for a future self that forgot everything

When a timed wake fires, your context may have compacted: you wake into a note and
little else. So **every self-wake `message` you write must be a self-contained resume
packet** — enough for a version of you that remembers nothing to pick the job up
correctly. Five things, always:

- **The goal** — what the user actually asked for, **in their words**.
- **State so far** — what is done, with **concrete ids/URLs** (a `chat_id`, an agent id,
  a browser session id / `context_name`, an errand id, a real URL). Never "made progress".
- **The single next action** — the one specific thing to do on waking.
- **Recovery pointers** — where to re-derive state if what you expect is gone: the chat
  id, the errand id, the agent id. So a stale expectation becomes a lookup, not a restart.
- **The terminal condition, stated as a check** — how you'll know the job is finished,
  e.g. *"if the agent shows published and the test passes, report to the user and stop"*.

And **rewrite the packet on every fire** so it always reflects current state — a stale
packet sends you to re-do work you already did. Where the tooling lets you **update** a
watcher, keep the **same watcher id** rather than delete-and-recreate, so earlier
references stay valid. (When you have an errand record — see `driving-to-completion` —
the packet is a pointer to it, not a second copy of the truth.)

## Waking around browser work — launch, end turn, wake, resume

Driving a browser for a real WhatsApp / Slack / voice user is the **canonical
timed-wake case**, because the browser often **blocks on something you can't finish in
one turn** — and no one is watching it to nudge it along. The automatic completion-wake
does NOT cover this: it fires only for delegated `aramb_a2a` / `aramb_architect` jobs,
and a browser wait is not a delegated job. So a browser wait needs a **timed
`aramb_mcp.wake_at`** you set yourself.

The loop, whenever a browser step will take time OR needs the user to act out-of-band:

1. **Launch / reach the blocking point** — e.g. you hit a login or payment wall and sent
   a `browser.creds` vault link (see the `aramb-browser` skill's *"Login & credential
   walls"*), or you kicked off a slow checkout, a background captcha auto-solve, or a
   page you must poll.
2. **End your turn and set `aramb_mcp.wake_at`** — put in the `message` everything future-you
   needs to resume: the browser **session id / `context_name`**, the site, the alias, and
   what you were mid-doing. Pick a sensible delay (a creds fill: minutes; a slow page:
   seconds-to-minutes).
3. **On wake, re-open the SAME browser context** (same session id / `context_name`) —
   never start a fresh login you already began — read the real state, and continue. For a
   credentials wall: re-check `aramb_mcp.vault_list_browser_creds`, then `aramb_browser.vault_fill`
   each field so the *browser* types the value — never read the value into yourself.
   (`vault_get_secret` is your own API-key vault, **never** a website login.) Then read the
   checkout result, re-check the page.
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
  next response); for a time-based / browser check, set a **new** `aramb_mcp.wake_at`. If
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

A one-shot `aramb_mcp.wake_at` does **not** repeat — a `continue` re-arm is how you carry a
slow, time-based job to the last mile. Keep the interval sensible (short for something
imminent, longer for a slow build), and don't re-arm forever on no progress: after several
silent no-progress ticks, `stop` or go `blocked` rather than waking indefinitely (the
platform also caps runaway re-arm chains). For a genuinely repeating cadence, use
`aramb_mcp.wake_schedule` instead of re-arming forever.

## Silence is a valid outcome of a check

**If a check fires and the work is healthy but not finished yet, say nothing.** A check
firing is **not** evidence that anything happened — a timer went off, that's all. The
user hears from you when there is something **real** to say (a result, a question, a
block), never because a check ran. Without this rule, every extra check makes you more
annoying, not more useful. (This is the `continue` / `progressed=false` re-arm above:
re-arm **silently**.)

## The safety check-in — a strategy audit, not a deadline

Some waits carry an automatic **safety check-in** managed by the runtime — a backstop so
a wait can never fail silently forever (e.g. a dropped event means the resume never
comes). This runtime check-in may not be armed yet (it's T2.4), so **do not rely on it**:
your own `aramb_mcp.wake_at` remains the primary backstop until it lands. You do **not**
create the check-in and it does **not** appear in your `aramb_mcp.wake_list`. If/when it
does fire, treat it correctly, because getting this wrong is how a check-in turns into
user-visible noise:

- **It is a strategy audit, not a deadline.** When it fires, the watched event has
  **not** necessarily happened. Ask yourself: *am I still set up correctly? did I watch
  the wrong thing? did I miss a notification? should I switch strategy or stop?*
- **For a credentials wait, check the store yourself before asking the user anything.**
  Call `aramb_mcp.vault_list_browser_creds` — the user may well have saved it already, in
  which case you resume (re-open the same browser session, `vault_fill`, continue), and
  the user hears nothing about the check-in.
- **If everything looks healthy and the work simply isn't done yet, stay silent** (the
  rule above). A check-in firing never produces a user message on its own.

A separate **one-shot deadline wake** (`aramb_mcp.wake_at`) is the right tool when there
is a *real* deadline with a *concrete* fallback action — "if the reply isn't in by 5pm,
send the draft as-is". That is a different thing from the safety check-in; don't conflate
the two.

## When a wait expires — say so honestly, never purge silently

A wait has a TTL. If it expires **unfired** — the event never came within the window —
that is **not** a silent end. Tell the user plainly what you were waiting on and that it
didn't happen ("I didn't see the credentials saved, so I stopped here — here's what's
still needed"), and stop or offer the next step. A wait that silently never resolves is
worse than one that resolves badly: the user is left counting on something that is never
coming.

## Honesty

Never tell the user you're "watching", "monitoring", or "keeping an eye on" something
unless it's actually true — either you delegated a job (whose completion-wake is
automatic) or you set an `aramb_mcp.wake_at` / `aramb_mcp.wake_schedule`. A claimed watch that
doesn't exist is a broken promise the user is counting on.

And stay **silent by default**: a wake that found nothing new says nothing (that's a
`continue` with `progressed=false`). You speak only on a real result, a real question, or
a block — never to report "still working" or "nothing yet".
