---
name: watchers
description: >
  Come back to a job on your own later with a WATCHER — a private one-shot
  self-wake. Use whenever work can't finish in a single turn: waiting on
  something async (a build, an agent, a workflow), checking back on a price /
  reply / status, reminding the user at a time you promised, or keeping an eye
  on something over time. NOT for firing another agent's workflow on an external
  event (that's a toolkit trigger) — a watcher only wakes YOU.
---

# Watchers — how to not lose the thread

A **watcher** is a private, **one-shot** alarm you set for *yourself*. At the time
you pick, it wakes you — invisibly, in this same conversation — and hands you back
the `message` you wrote, so you can pick a job up and carry it forward. The user
never sees it fire; they only see you follow up when there's something real to say.

This is what turns you from a one-shot responder into an assistant who **starts
things, circles back, and drives them to done** without the user having to keep
poking you.

## The tools

- `aramb_mcp.my_triggers_create_watcher(message, in | fire_at)` — set one.
  - `message` — what you want to do when it fires, in your own words
    (e.g. `"check the architect on chat <id> and continue the build"`). It's
    delivered to you verbatim as the wake-up, so make it a clear instruction to
    your future self, including any id you'll need.
  - `in` — a delay from now as a Go duration: `"30s"`, `"2m"`, `"10m"`, `"2h"`.
  - `fire_at` — an absolute time instead, RFC3339 UTC: `"2026-09-10T17:00:00Z"`.
  - Pass exactly one of `in` / `fire_at`.
- `aramb_mcp.my_triggers_cancel_watcher(watcher_id)` — drop a pending one you no
  longer need.
- `aramb_mcp.my_triggers_list` — see your pending watchers (and their ids).

## When to reach for one

Ask "will this finish in this single turn?" If **no**, set a watcher. Common cases:

- **Async work you kicked off** — you asked something to run in the background
  (an agent build, a long agent reply, a workflow) and got back an id. Don't
  block waiting; set a watcher to come check it.
- **Check back later** — "is it in stock yet?", "did they reply?", "has the price
  dropped?" — set a watcher for a sensible interval.
- **A promised reminder** — the user said "remind me at 6" — `fire_at` that time.
- **Keep an eye on something** — monitor a page/state over a while: watcher →
  check → re-arm.

## The one rule that matters: it fires ONCE — re-arm until done

A watcher does **not** repeat. When it wakes you, do the check, then decide:

1. **Done?** → act on the result and tell the user. Don't set another.
2. **Not done yet?** → set a **new** watcher and keep going.

That re-arm loop is how you carry a long job all the way to the last mile on your
own. Keep the interval sensible (short for something imminent, longer for a slow
build) so you're not waking constantly.

## Honesty

Never tell the user you're "watching", "monitoring", or "keeping an eye on"
something unless you actually created a watcher for it. A claimed watch that
doesn't exist is a broken promise the user is counting on.
