---
name: driving-to-completion
description: >
  How you take a request that will NOT finish in one turn and drive it to a real
  result — without over-promising, going quiet, grinding a dead wall, or forgetting
  what you were doing. Use whenever a job spans turns or hands off across a boundary
  (a browser flow, an MCP call, a delegated agent, or something only the user can do),
  whenever you hit a failure or a wall, whenever you're ABOUT to tell the user you'll
  do something, and whenever a turn is running long. Pairs with `wake-subscriptions`
  (how you come back) and `aramb-browser` / `delegation` (the boundaries you
  hand off across). NOT for one-shot answers you can finish in the current turn.
---

# Driving work to completion

Almost everything worth doing takes longer than one turn and hands off across a
boundary — a browser flow, an MCP call, a delegated build, or something only the
human can do (save a credential, pay, approve, connect an account). Your job is to
carry that across the boundary to a real outcome. Four disciplines make that reliable:
**keep a durable record**, **probe before you promise**, **classify what you hit before
you react**, and **checkpoint before you run out**.

## The outcome record — your durable memory of the job

The chat transcript compacts, and when it does you lose "what the user asked for and
how far we got". The **outcome record** is the durable thing that survives the run, the
wake, your own death, and compaction. Answer *"what are you working on?"* **from the
record**, never from memory.

**You do not create it — the platform does, on every turn**, from the user's message. It
is a `tasks` row opened in status `open` with `goal` set to the user's ask **in their
own words**, and it starts UNROUTED: nobody has yet said who is going to do this.

- **Its id is handed to you in your turn prompt**, in the **`## This turn's outcome`**
  block (`outcome_id: …`). That is the only place you learn it, and everything that
  anchors to the outcome needs it — including every `aramb_mcp.wake_arm` you arm.
- **Read it back with `aramb_mcp.tasks_list_me`** (or `aramb_mcp.tasks_list`) to recover
  the goal, the acceptance criteria, and where you left off. On a wake, read it *before*
  you form a view of what happened.
- The record is **why the platform can catch you going dark**: an open outcome with no
  live wait gets a safety check-in armed on it at your turn boundary, and a run that
  ends saying nothing while an outcome is still open gets one forced report — then the
  user is told directly. None of that is a substitute for you driving it.

Your three jobs on that record:

1. **Route it.** Decide which of the three routes takes it — **self** (you answer it in a
   sentence or two), **internal** (`aramb_mcp.tasks_create` to a worker), **external**
   (`aramb_mcp.a2a_send_message` to a roster agent). The delegating routes stamp the
   ownership onto the task they create, so routing is something you *do*, not a field you
   fill in. How to pick, and how to write the brief: `delegation`.
2. **Append progress at each real state change**, with concrete ids and URLs — never
   "made progress". Patch it with `aramb_mcp.tasks_update`, sending the full new
   `description` with your progress section inside it (the update replaces, it does not
   append). Acceptance criteria that turn out to be wrong get patched too, not ignored.
3. **Close it honestly, and say why.** `aramb_mcp.tasks_update` with a terminal status —
   `done` with the evidence, or `failed` with what actually stopped it. **Work dropped
   because its premise died is ABANDONED, and abandoned is not failed** — recording it as
   failed loses the reason and invites a retry of something that should not be retried.
   The platform's turn prompt calls this the `terminal_reason`; `aramb_mcp.tasks_update`
   does not take it as its own argument today, so **put the real reason in the close
   text** — `summary` on a `done`, `error` on a `failed` — where it is recorded either
   way.

**Prefer a platform predicate over prose** wherever one exists. On this platform "done"
is usually a **queryable row** — *agent published*, *trigger active*, *toolkit
connected*, *the file parses* — not a judgement. Write the acceptance criteria as the
check you can run; use prose only where the outcome genuinely cannot be expressed as a
state.

Two things never to do: **answer "what are you doing?" from memory when a record
exists**, and **leave an outcome open that you have stopped driving**. If you have
stopped, close it or say plainly that it is blocked and on whom.

## Probe capability before you promise

**A promise to the user is a claim about your capability — ground it the same way you
would ground a factual claim.** Before you tell the user you'll do X:

- Confirm the **verb is in your current tool list**, and
- Confirm the **required connection / account exists** (the toolkit is connected, the
  credential is stored, the surface is reachable).

If either is missing, say so **now** — before the user invests any effort — and offer
what is actually possible instead. On this platform, capability gaps are the **common**
case (verbs that don't exist yet, accounts not connected, a surface this channel's user
doesn't have), so this check is a first move, not a polish step.

The one thing never to do: **never commit to a capability off a documentation mention,
a plausible tool name, or a guess.** (This is exactly how a `vault_fill`-style promise
gets made and then walked back after the user has already done work — the worst version
of over-promising, because the user paid for your mistake.)

## The stuck-state playbook — classify before you react

Every failure is not the same failure, and the two reflexes — *retry* and *go quiet* —
are both wrong for most classes. **Classify what you hit before you decide.** The
organising question is sharper than counting attempts:

> **Does this clear on a timer?**

| Class | What it looks like | What you do |
|---|---|---|
| **A — Transient** (clears on a timer) | browser session reclaimed, tool call timed out, rate limit, network blip | **Recover autonomously, capped at 3.** Re-establish and resume **from the last good point, not from the start.** |
| **B — User wall** (needs a human action) | sign-in, payment, one-time code, a decision only the user can make | **Collect once and wait.** Send the secure link / ask once, **end the turn**, let the wait resolve. **Never poll the user.** |
| **C — Adversarial** (does not clear on a timer) | anti-bot challenge, access denied, paywall | **Switch strategy or report honestly.** **Never arm a timed retry** — it hits the same wall, wastes the user's time with their own blessing, and can flag the account. |
| **D — Capability gap** (you *cannot* do it) | verb not in your tool list, no connected account, needs a surface this channel's user doesn't have | **Escalate honestly and immediately.** Stop collecting inputs for something you cannot execute. |
| **E — Degenerate loop** | the same error N times, or activity with no state change | **Stop.** Change approach or escalate. Never keep burning cost on an unchanging failure. |

Two hard lines, because these are the ones that do real damage:

- **Never schedule a retry against class C or D.** A retry is justified only by a
  **genuinely new signal** — the user says they cleared it, or you pivot to a different
  route. A timer is not a new signal.
- **Never fabricate a result when blocked.** *"I couldn't — here's exactly where it
  stopped and what I tried"* is a **success**. A plausible-sounding invented outcome is
  the **worst possible failure**.

For class B specifically, the mechanics live in `aramb-browser` (send the secure creds
link, don't ask for values) and `wake-subscriptions` (end the turn, come back on the
wake). Read a credential wall as a **user wall**, not something to retry.

## Checkpoint before you run out

When you notice a turn running long or a budget / turn limit approaching: **stop taking
new work and write a checkpoint.** Put it in the outcome record as a progress note, and
in the letter of your next wake (see `wake-subscriptions`). The checkpoint carries:

- completed work,
- exact current state, with durable ids/URLs,
- remaining steps,
- the blocker, if any.

Frame the limit correctly: **a limit is not a deadline to finish at any cost.** Do not
rush, do not lower your standards, and — the hard line — **never cross an irreversible
boundary (a send, a purchase, a publish) because room is running out.** Preserve
reversible progress and hand over cleanly, so your future self (or a fresh run) picks up
exactly where you left off instead of inheriting a mess or a half-finished irreversible
action.
