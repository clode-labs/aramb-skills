---
name: agent-archetypes
description: >
  An OPTIONAL shortcut library of a few common agent shapes for the Architect. It is NOT how you decide
  what to build — that comes from Phase-0 research of the specific business (aramb-browser) plus the
  primitive-decision table (agent-primitives), which works for any request. Reach for this only when a
  request OBVIOUSLY matches one of these common shapes, for a head-start on the usual pieces, guardrails,
  and failure modes. Most real requests won't fit cleanly — that's expected; never force one.
---

# Agent Archetypes — a shortcut library of common shapes

**This is an optional accelerator, not how you decide what to build.** You decide WHAT to build from
Phase-0 research of the *specific* business (aramb-browser) + the primitive-decision table
(agent-primitives) — that works for any request. These archetypes just name a handful of shapes that
come up a lot, so when a request *obviously* is one, you get a head-start on the usual pieces,
guardrails, and failure modes. **Most real requests won't match one cleanly — they blend, or they're
off-catalogue entirely. That's expected. Never contort a request to fit a recipe.**

## How to use it (only when a shape obviously fits)

1. **Research first (Phase 0), then check for a shape.** Ground yourself in what *this* business does
   and how AI helps it. If that lands squarely on one of the shapes below, use its capability set and
   failure modes as a *starting point* — adjusted for this request, never applied blindly. If it
   doesn't, ignore this file and design from the research + the primitive-decision table.
2. **Compose, don't force.** A request may blend two shapes (support + a weekly digest) — compose their
   pieces. If it fits none, that's fine and common — build from primitives.
3. **Heed the failure modes.** Each recipe lists what builds of this shape get wrong (an unscheduled
   digest, an assumed vendor backend, a missing escalation path) — verify against these by tool result.

(Questioning discipline — extract-first, the five-question ceiling, batching via `chat_ask_questions` —
lives in SOUL.md / AGENTS.md and applies to every build, archetype or not.)

**This library is a starting vocabulary, not a closed set.** If a request doesn't fit any archetype,
say so, build from the raw primitive-decision table, and note the new shape in memory/juno so the
library can grow. Never force a bad match.

## The recipe format

Each archetype below carries six fields:

- **Trigger signals** — phrases / shapes in the request that point to this archetype.
- **Core loop** — the fundamental behavior, in one line.
- **Default capability set** — which build primitives it usually needs (persona is always implied).
- **The questions that matter** — the 2-3 grounding questions that actually change the design.
- **Standard guardrails** — the safety / escalation defaults this shape should ship with.
- **Known failure modes** — what builds of this shape commonly get wrong; verify against these.

---

## Support-Email-Triage

An agent that reads inbound customer messages, answers the common ones correctly from the shop's own
knowledge, and hands the rest to a human.

- **Trigger signals:** "answer customer emails", "where's my order", "handle support", "reply to the
  common stuff", "set aside what it's not sure about", FAQ-shaped questions, a business with orders/returns.
- **Core loop:** receive message → classify → answer from KB **or** escalate to a human.
- **Default capability set:** KB (policies, products, FAQ) · required toolkit for the inbox (e.g. GMAIL) ·
  a human-handoff/escalation path in the persona · guardrail against inventing policy. Often paired with
  **recurring-digest** for a weekly summary.
- **The questions that matter:** Which inbox/channel does it read? Where do escalations go (a label, a
  forward, a flag)? Should it draft-only or send?
- **Standard guardrails:** never invent policy or product facts not in the KB; escalate refunds / returns /
  damaged-goods / legal / health-and-safety / anything it's unsure of; be honest about what it can't do.
- **Known failure modes:** assuming a specific commerce backend the user never named (they said "my shop",
  not "Shopify") — declare only what they confirmed; skipping the escalation path (the "set it aside for a
  human" behavior is core, not optional); answering from general knowledge instead of the KB.

## Inbound-Lead-Qualifier / Concierge

An agent that engages inbound leads, qualifies them, books time, and nudges — the front door of a sales
or service funnel.

- **Trigger signals:** "handle leads", "qualify inquiries", "book calls/viewings", "follow up with
  prospects", real-estate / B2B / services intake, "reply, qualify, schedule".
- **Core loop:** greet lead → qualify (hot/warm/cold) → book or route → nudge on no-response → summarize.
- **Default capability set:** persona with a qualification rubric and real boundaries · a calendar/booking
  toolkit · the lead channel toolkit (form, email, chat) · often a recurring-digest of the week's pipeline ·
  optional CRM toolkit.
- **The questions that matter:** Where do leads come from (channel)? What calendar/booking system? What
  makes a lead qualified (the rubric)?
- **Standard guardrails:** don't over-promise pricing/availability it can't confirm; hand off qualified-hot
  leads to a human promptly; never fabricate a booking it didn't make.
- **Known failure modes:** building the persona only and deferring every primitive (leaving it unable to
  actually book or read leads); a vague rubric that qualifies everything as "hot"; wiring no follow-up path.

## Research-&-Brief

An agent that takes a topic or question, gathers current information, and returns a synthesized brief.

- **Trigger signals:** "research X", "give me a brief on", "monitor a topic", "summarize the landscape",
  "competitive analysis", "what's new in".
- **Core loop:** take topic → gather (web/sources) → synthesize → deliver a structured brief.
- **Default capability set:** persona tuned for synthesis + citation · aramb-browser / web access ·
  frequently a **bound workflow** if the research is a repeatable multi-step routine (gather → score →
  write) · optional recurring trigger if it should run on a schedule.
- **The questions that matter:** What sources / scope? How deep (a paragraph vs a full brief)? On demand
  or on a schedule?
- **Standard guardrails:** cite sources; mark inference vs fact; don't present stale or unverified claims
  as current.
- **Known failure modes:** answering from memory instead of actually looking; no structure to the output;
  building a workflow when a single well-prompted agent would do (only decompose if it genuinely repeats).

## Recurring-Digest / Report

An agent (or an agent-level trigger + workflow) that runs on a schedule and delivers a periodic summary.

- **Trigger signals:** "every Monday morning", "daily summary", "weekly report", "a digest of", "recap of
  what happened", any explicit cadence.
- **Core loop:** on schedule → gather from sources → summarize → deliver to a channel.
- **Default capability set:** a **workflow** that gathers + summarizes · **an agent-level trigger** (cron)
  so it fires on the clock · the source toolkits (inbox, sheet, analytics) · a delivery toolkit (email/Slack).
- **The questions that matter:** What cadence exactly? What sources feed it? Where is the digest delivered?
- **Standard guardrails:** don't fabricate a summary when there's no data — say "nothing this period";
  respect the delivery channel's audience.
- **Known failure modes (the big one):** creating the workflow but leaving it **unscheduled / draft** so it
  never fires — a recurring digest without a cron trigger and a publish is not done. Remember: the schedule
  is an **agent-level trigger**, not something on the bound workflow. Verify the trigger exists and the
  agent is published before calling it live.

## Internal-Knowledge-QA

An agent that answers questions from an organization's internal documents — an on-demand expert over a
knowledge base.

- **Trigger signals:** "answer questions about our docs/policies/handbook", "internal helpdesk", "a bot that
  knows our X", "onboarding questions", "search our knowledge".
- **Core loop:** question → retrieve from KB → answer with citation, or say it doesn't know.
- **Default capability set:** KB (the docs) · persona scoped to answer *from* the KB and not guess ·
  isolation/mode considerations if it's org-internal · usually no workflow.
- **The questions that matter:** What documents? Who asks (audience/scope)? What should it do when the answer
  isn't in the docs?
- **Standard guardrails:** answer only from the KB; say "not in our docs — check with <owner>" rather than
  guessing; don't leak documents outside the intended audience.
- **Known failure modes:** answering from general knowledge instead of the KB; over-refusing when the answer
  IS in the docs; no fallback for the not-found case.

## When nothing fits

Some requests are genuinely novel or a blend of pieces from several archetypes. When no single recipe fits:

- Compose the closest secondary archetypes' capability sets, and name the blend to the user in the plan.
- Fall back to the raw primitive-decision table (SOUL.md → Phase 2) and reason each primitive from the
  capability spec.
- Note the new shape in memory / juno with its signals and the capability set that worked, so the pattern
  library grows from real builds.

The goal is always an *informed* build — the archetype is a tool for getting there faster and more
reliably, never a cage.
