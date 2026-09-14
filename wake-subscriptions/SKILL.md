---
name: wake-subscriptions
description: >
  How you survive "later" — coming back to work that could not finish in one turn,
  and driving it to a real end. TWO mechanisms: (1) AUTOMATIC — delegate a job
  (`aramb_mcp.a2a_send_message` / `aramb_mcp.architect_ask`), end your turn, and the
  platform wakes you the moment it responds; you arm nothing. (2) TIMED — you wake
  YOURSELF with `aramb_mcp.wake_at` (one-shot) or `aramb_mcp.wake_schedule`
  (recurring). Use whenever a job spans turns, waits on a user action, or waits on
  an external event, and nobody is there to poke you. NOT for firing another agent's
  workflow on a third-party service event (that is a toolkit trigger).
---

# Wake subscriptions — how you come back and finish the job

You are a one-shot responder: you reply, your turn ends, you go quiet. Long, blocked,
or delegated work breaks that — the result arrives after your turn is over. **A wake is
how you come back.** Two mechanisms, and the first one you get for free.

A wake is a **durable note that says: wake me, with this context, when this condition
can be true.** Two rules make wakes trustworthy, and everything below is downstream of
them:

> **1. The trigger is a verifiable binary state.**
> **2. The letter carries everything a self that remembers nothing needs to act.**

## 1. Automatic completion-wake — you delegate, the platform wakes you

**When you delegate work and end your turn, the platform wakes you the moment that work
responds.** You do not call anything to arm this. It covers:

- `aramb_mcp.a2a_send_message` — you messaged another agent.
- `aramb_mcp.architect_ask` — you asked the Architect to build or change an agent.

So the delegation loop is simply: send → **end your turn** → be woken →
`aramb_mcp.a2a_get_messages(chat_id)` → act. Do not arm a timer "just in case", and do
not sit in a poll loop — both are noise against a wake that already has it covered.

## 2. Timed self-wake — you pick the moment

For a follow-up that is genuinely **time-based** or waiting on an event nobody will
announce to you:

- `aramb_mcp.wake_at(message, in | fire_at)` — **one-shot**. `in` is a Go duration
  (`"30s"`, `"10m"`, `"2h"`); `fire_at` is an absolute RFC3339 UTC time. Pass exactly
  one. `message` comes back to you verbatim — it is the letter, see below.
- `aramb_mcp.wake_schedule(name, cron_expression, cron_timezone)` — **recurring**, for a
  cadence that genuinely repeats ("every morning at 9"). Use this instead of chaining
  one-shots forever. 5-field cron; IANA timezone, default UTC.
- `aramb_mcp.wake_cancel(watcher_id)` — drop a pending one-shot.
- `aramb_mcp.wake_list` — your pending wakes and their ids.

These are invisible to the user. They never see one fire; they only ever see you follow
up when there is something real to say.

## The trigger — a binary state, never a vibe

Before you arm anything, write down the condition in a form where the observable data
answers **true or false**, with no judgement in between.

| | |
|---|---|
| ✅ | "the browser-creds store lists alias `linkedin` with a `password` field" |
| ✅ | "`a2a_get_messages(chat_id=…)` shows a reply after the message I sent" |
| ✅ | "`agents_get(<id>)` returns the agent with status published" |
| ❌ | "when the build looks ready" |
| ❌ | "if anything important has changed" |

If the condition you actually want is fuzzy, do one of two things — **define the rubric
that makes it binary**, or **accept that you will wake every time and judge on each
wake**. What you may not do is arm a vague trigger and hope your future self works out
what you meant.

**Cadence: the slowest check that cannot change the outcome for the user.** A page load
is seconds; a credential the user must go and save is minutes; a build is minutes; a
renewal is days. Do not poll out of anxiety — every extra tick costs the user money and
buys nothing. Know which kind of clock you are on: *cadence* (only staleness matters,
drift is fine), *clock* (the wall-clock time carries meaning, lateness is tolerable if
it cannot change the outcome), *exact* (a real external deadline). Only the last one
earns tight timing.

**Limits worth knowing:** timing is minute-precision, not second-precision. Polling is
polling — be honest with yourself that that is what you are doing. And an arrival feed
can go stale silently, so a wake that waits on an *event* always carries a **time-based
fallback** as well; otherwise a dropped event means you wait forever.

## The letter — write to a self that remembers nothing

When a timed wake fires your context may have compacted: you wake into your own note
and almost nothing else. So **every `message` you write is a self-contained letter to a
forgetful self.** Five things, every time:

- **The original ask** — what the user actually wanted, **in their words**.
- **State so far, with a timestamp** — what is done, with **concrete ids and URLs**: the
  `chat_id`, the agent id, the browser session id / `context_name`, the task id, a real
  URL. Never "made progress".
- **The exact next action** — the one specific thing to do on waking, not a theme.
- **The outcome anchor** — the id of the work unit this belongs to, so a stale
  expectation becomes a lookup instead of a restart.
- **The terminal condition, written as a check** — *"if the agent shows published and
  the reply reads sensibly, tell the user and stop"*.

**A wake that cannot drive the work forward without asking the user again is a failed
wake.** And **rewrite the letter on every fire** so it always reflects current state —
a stale letter sends you to redo work you already did. Where the tooling lets you update
a wake in place, keep the **same id** rather than delete-and-recreate, so earlier
references stay valid.

## Silence until the trigger holds

**A watcher that reports "nothing changed" has failed its only job.** A wake firing is
not evidence that anything happened — a timer went off, that is all.

- Trigger unmet, work healthy → **say nothing**, re-arm silently.
- Trigger met → the report (**exact observed state + timestamp**) and the teardown ship
  in the same action.

Without this rule every extra check makes you more annoying rather than more useful.
"Still working", "nothing yet", "just checking in" are the exact failure to avoid.

## Self-chain or kill

Every fire ends in one of two shapes and never in a shrug:

- **Work incomplete →** write the **next** wake with updated state, and keep going.
- **Outcome landed, or its premise died →** **cancel the wake** (`wake_cancel`). No
  orphan pings about work that is over. A recurring `wake_schedule` you no longer need
  is the same rule: kill it.

**Dedup before you stack.** Before arming a wake on a piece of work, check
`aramb_mcp.wake_list` for one that already watches it and **update that one instead**.
Two live watchers on one outcome means two wakes, two reports, and two chances to
double-act.

## On every fire: re-verify, then choose ONE outcome

A wake carries **no state**. Go read the actual world before you form a view — and read
it with the right tool:

- **An agent / the Architect** → `aramb_mcp.a2a_get_messages(chat_id)` for the reply,
  and for a build cross-check the ground truth with `aramb_mcp.agents_get`. Never trust
  the reply alone.
- **A browser flow** → your `aramb_browser` tools: what page is it on, did the step
  fail, a screenshot. Re-open the **same** session / `context_name` — never start a
  fresh login you already began.
- **A credential wait** → `aramb_mcp.vault_list_browser_creds` (metadata only), then
  `aramb_browser.vault_fill` each field so the *browser* types the value. Never read a
  website credential into yourself.
- **Something on the web** → re-fetch and read it.

**Re-verify the trigger from fresh observations, never from the wake's own text.** The
letter is your instruction; it is not evidence that the condition holds.

> **The one distinction that matters here.** Re-verifying the **trigger** is mandatory —
> that is the whole point of the check. But when a wake or a hand-off **asserts state**
> ("the credentials were stored", "the file is at this path") and you hold **no
> contradicting evidence**, act on the assertion. Investigation is for contradicting an
> assertion, not for re-confirming one. Re-deriving state you were just handed burns the
> user's budget to learn what you already knew.

Then end in exactly **one** typed outcome — this is a decision, not loose prose:

- **stop** — done or abandoned. Disarm the wake. Write to the user only if there is a
  real result to deliver.
- **continue** — re-arm with a fresh letter. If nothing changed this tick
  (`progressed = false`), re-arm **silently**: no user message. For a delegated job,
  just end your turn again — the automatic wake covers the next response.
- **notify the user** — the only outcome that produces a message on its own, and only
  for a real result, a real question, or a decision the user must make.
- **blocked** — you cannot proceed without the user or an external event. Say plainly
  what is blocking and what you need, then stop or park. **Do not re-arm into a wall.**

A one-shot `wake_at` does not repeat; a `continue` re-arm is how a slow job reaches the
last mile. But do not re-arm forever on no progress — after several silent no-progress
ticks, `stop` or go `blocked` rather than waking indefinitely (the platform also caps
runaway chains). For a genuinely repeating cadence use `wake_schedule` instead.

## Waking around browser work

A browser flow is the canonical timed-wake case: it blocks on something you cannot
finish in one turn, and the automatic completion-wake does **not** cover it (that fires
only for delegated agent jobs). So:

1. **Reach the blocking point** — a login or payment wall where you sent a
   `browser.creds` vault link, a slow checkout, a captcha clearing in the background, a
   page you must re-read.
2. **End your turn and arm `aramb_mcp.wake_at`** — with a letter carrying the **session
   id / `context_name`**, the site, the alias, and exactly what you were mid-doing. Pick
   a sensible delay: a creds fill is minutes; a slow page is seconds-to-minutes.
3. **On wake, re-open the SAME context**, read the real state, and continue —
   re-check `vault_list_browser_creds`, `vault_fill`, read the result.
4. **End in a typed outcome** as above. Filled and continued → `stop` or `notify`. Still
   empty, still loading → `continue` with `progressed=false`, **silently**. Wait budget
   exhausted → `blocked`, and say what is still needed.

Full mechanics live in `aramb-browser`; how to classify what you hit at the wall lives
in `driving-to-completion`.

## The safety check-in — a strategy audit, not a deadline

Some waits carry a runtime-managed **safety check-in**: a backstop so a wait cannot fail
silently forever (a dropped event, a child that died without reporting). You do not
create it and it does not appear in `wake_list`. When one fires:

- **It is a strategy audit.** The watched event has **not** necessarily happened. Ask:
  am I still set up correctly? did I watch the wrong thing? did I miss the event? should
  I switch approach or stop?
- **Check the store yourself before asking the user anything** — for a credentials wait,
  call `vault_list_browser_creds` first. They may well have saved it already, in which
  case you resume and they hear nothing about the check-in.
- **Healthy but not finished → stay silent.** A check-in never produces a user message
  on its own.

A one-shot **deadline** wake is a different thing: use `wake_at` when there is a real
deadline with a concrete fallback action ("if the reply isn't in by 5pm, send the draft
as-is"). Don't conflate the two.

## When a wait expires — say so, never purge silently

A wait has a TTL. If it expires **unfired** — the event never came inside the window —
that is not a silent ending. **Tell the user plainly** what you were waiting on and that
it did not happen ("I didn't see the credentials saved, so I've stopped here — here's
what's still needed"), then stop or offer the next step. A wait that quietly never
resolves is worse than one that resolves badly: the user is left counting on something
that is never coming.

## Honesty

Never tell the user you are "watching", "monitoring", or "keeping an eye on" something
unless it is literally true — you delegated a job (whose completion-wake is automatic)
or you armed a `wake_at` / `wake_schedule` and the tool returned. A claimed watch that
does not exist is a promise the user is counting on and will not get.

And never narrate the machinery. The user does not hear about watchers, wakes, letters,
or triggers. They hear the result, the question, or the block.
