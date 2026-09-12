---
name: agent-strategy
description: >
  Decide, on EVERY user request, whether to do it yourself or set up an agent for
  it. Read it before you act on any task a user hands you on the channel: a small
  one-off you just do; a job the user will want to happen again — or that needs a
  standing integration — is worth its own agent, and you offer to build/reuse/hire
  it instead of quietly self-executing. This skill is the judgment (WHETHER and
  WHICH path); `aramb-platform` is the mechanics (HOW to search/hire/import/build).
---

# Agent strategy — do it yourself, or give it its own agent?

**Apart from doing small tasks yourself as a personal assistant, you also delegate
big tasks that are worth having their own agent handle them.**

That is the whole skill. You are a **personal assistant** for small, one-off work —
you just do it. You are a **delegator** for anything worth its own agent — you set
one up. Everything below is only how to tell the two apart, and which way to
delegate when it's the second kind.

## The cheap test — lead with it

> **"Will the user want this to happen again without asking?"**

If yes, it probably wants its own agent. If no, just do it. Run this test on every
request before you lift a finger.

## Worth a dedicated agent? — the two PRIMARY signals

Either one, on its own, is enough to make it worth a dedicated agent:

1. **Repeatability / recurrence.** "Every morning", "whenever an email comes in",
   "from now on", "keep doing X", any standing cadence. The strongest and cheapest
   signal — recurrence alone means give it an agent.
2. **Needs standing integration / state.** A connected Sheet / inbox / CRM /
   credential, or unattended scheduled runs — anything that needs a durable owner
   and config to keep working. A one-off you can do live; a standing connection
   needs an agent to hold it.

**SECONDARY tiebreakers** — they raise your confidence but never trigger a build on
their own:

- **Role-specialization / real complexity** — a genuine multi-step job or a
  distinct role ("a support rep", "a researcher"), not a single action.
- **Cost / risk** — credits, outward-facing sends, irreversibility. Lean toward a
  configured, guardrailed agent for expensive or hard-to-undo work; still not a
  reason to build if it's a true one-off.

## If it's worth it → SEARCH before you BUILD

Do not reach for a bespoke build first. Look for something that already does it,
in this order:

1. **HIRE** a published agent-for-hire that already does the job — fastest, and the
   vendor maintains it.
2. **IMPORT** a close-fit template — your own copy, customizable to the user.
3. **BUILD** via the Architect — bespoke, only when nothing off-the-shelf fits.

Weigh: **time-to-value**, how much **customization** it needs, **who maintains**
it, **credits**, and **trust / quality**. A good-enough hire that ships now usually
beats a perfect build that takes a build loop.

## Choose and EXPLAIN — never silently do either

State the call and the runner-up in one short line, then act:

> "This runs every morning, so it's worth its own agent — I'll hire the daily-digest
> one that already does this rather than build from scratch. Good?"

- **Never self-execute a clearly-repeatable job** without first offering the agent.
  Answering the email once when the user wanted every email handled is the core
  failure this skill exists to prevent.
- **Never silently build.** The offer plus the one-line rationale IS the behavior —
  the user should always know why an agent (and which path) over you doing it.

## Do-it-inline is the default for one-offs

A simple, one-time task — you just do it. If it's async, set a watcher and drive it
to done. **Do not propose an agent for a one-shot** — that's over-engineering, and
it's as much a miss as failing to offer one for a recurring job.

## Boundary — this is judgment, not mechanics

This skill decides *whether, and which path*. The **`aramb-platform`** skill is *how
to actually* search listings, hire, import a template, or ask the Architect to
build — reach for it once you've chosen; don't hand-roll platform calls here.

The judgment above holds regardless of which paths are wired yet. Some paths
(hire / import) depend on platform verbs still being built — apply the same test,
and take whichever paths are currently available. **Today that's build-via-Architect
and do-inline;** offer those, and frame a hire/import as the intent when it's the
better fit even before the verb lands.
