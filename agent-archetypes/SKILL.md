---
name: agent-archetypes
description: >
  The Architect's library of agent patterns ("archetypes"). Use in Phase 1 (Decide WHAT) of every
  build: match the user's problem to one or more archetypes to know the agent's shape before you
  build it — its default capability set, the 2-3 questions that actually change the design, its
  standard guardrails, and its known failure modes. This is what makes deciding WHAT to build
  scientific and repeatable instead of improvised. Read it after Phase 0 enrichment, before you
  write the plan.
---

# Agent Archetypes — the pattern library

A non-technical user hands the Architect a *problem*, not a design. An archetype is the bridge:
a reusable recipe for a *kind* of agent that tells you, before you build anything, what this shape
of agent usually needs and usually gets wrong. Matching the request to an archetype is Phase 1 of
the four-phase flow (see SOUL.md). It turns "answer my emails and send me a Monday summary" into
"this is *support-email-triage* + *recurring-digest*, so it needs a KB, an inbox toolkit, a human
handoff, and one scheduled digest workflow."

## How to use this library

1. **Enrich first (Phase 0).** Understand the industry and how people solve this problem (aramb-browser)
   before you match — the match is only as good as your understanding of the request.
2. **Match multi-label, not single-select.** Real requests blend shapes. Extract the *capability
   signals* from the request — data source, trigger cadence, output channel, decision points,
   human-in-loop needs — and match one **primary** archetype plus any **secondary** ones. A blend is
   normal and expected; compose their capability sets.
3. **Extract first, then let the match gate the questions that are LEFT.** Subtract everything the
   request already gave you — including config the user handed over (a pasted credential, a stated
   cadence, a named channel): that is *decided*, never re-asked. Each archetype lists the questions that
   genuinely change its design; ask only the ones the request did **not** already answer. **The count
   scales with how little was given — as few as possible, a hard ceiling of five, often zero for a
   detailed request.** When two archetypes match closely **and imply different primitives**, the fork
   between them is exactly what to ask about — that ambiguity is your signal to ground, not to guess.
   **Ask each grounding question through `aramb_mcp.chat_ask_question`, never as prose** — pass `options`
   (2–4 choices) whenever the answer is a discrete pick (which inbox, which channel, what cadence) so the
   user clicks instead of typing; a question written into a paragraph renders as unanswerable text in the
   console.
4. **Carry the recipe into Phase 2.** The archetype's default capability set is your starting point for
   the primitive-decision table — adjust for this specific request (add, drop, defer with a reason),
   don't apply it blindly.
5. **Heed the failure modes.** Each recipe lists what builds of this shape get wrong. These are the
   things to verify by tool result before you claim them done (an unscheduled digest workflow, an
   assumed vendor backend, a missing escalation path).

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

## Content-Pipeline (multi-agent)

An agent that produces finished content through genuinely distinct stages — the canonical case for a
multi-agent workflow.

- **Trigger signals:** "write and edit", "draft then review", "research → write → polish", "content
  factory", "turn briefs into posts", a pipeline with clearly different roles.
- **Core loop:** research/outline → draft → edit/fact-check → finalize, each a distinct role.
- **Default capability set:** a **bound multi-agent workflow** with `agent_specs` for each distinct role ·
  KB for brand voice/style · workflow invocation wiring (`instruction` + `enabled`) · optional publishing
  toolkit (CMS, social).
- **The questions that matter:** What are the real stages (are they genuinely distinct roles)? What's the
  house style/voice? Where does the output go?
- **Standard guardrails:** fact-check stage before publish; keep the human in the loop on final publish
  unless explicitly told to auto-post.
- **Known failure modes:** forcing a workflow when one prompt could do it (only build multi-agent when the
  roles are genuinely distinct); putting invocation rules in the system prompt instead of the workflow's
  `instruction`; leaving `enabled=false` so the agent never fires it.

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

## Meeting / Calendar-Coordinator

An agent that manages scheduling — finds times, books, reschedules, reminds.

- **Trigger signals:** "schedule meetings", "coordinate calendars", "book time with", "send reminders",
  "find a slot".
- **Core loop:** request → check availability → propose/book → confirm → remind.
- **Default capability set:** a calendar toolkit (Google Calendar) · often an email/chat toolkit for
  confirmations · persona with clear time-zone and double-booking rules · optional reminder trigger.
- **The questions that matter:** Which calendar? Whose availability / what constraints? What channel for
  confirmations and reminders?
- **Standard guardrails:** never double-book; confirm before committing; respect working hours / time zones.
- **Known failure modes:** assuming a calendar system; no confirmation step; ignoring time zones.

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

## Data-Entry / Ops-Automator

An agent that moves and transforms structured data between systems on request or on a trigger.

- **Trigger signals:** "log this into a sheet", "sync X to Y", "update the CRM when", "process form
  submissions", "file these into".
- **Core loop:** input event/request → read source → transform → write to destination → confirm.
- **Default capability set:** the source + destination toolkits (Sheets, CRM, DB) · often a **workflow** for
  the multi-step transform · frequently an **event trigger** (on new row / new submission) · secrets if a
  destination is a custom API.
- **The questions that matter:** What's the source and destination? What triggers it (on demand vs on event)?
  What's the mapping/transform?
- **Standard guardrails:** validate before writing; don't overwrite/delete without confirmation; report what
  it changed.
- **Known failure modes:** silent data loss on a bad mapping; missing the trigger wiring; assuming schemas.

## Review / Reputation-Responder

An agent that monitors reviews/mentions and drafts or posts on-brand responses.

- **Trigger signals:** "respond to reviews", "monitor mentions", "reply to feedback", "manage our
  reputation", Google/Yelp/App-Store/social responses.
- **Core loop:** new review/mention → assess sentiment → draft on-brand response → post or route for approval.
- **Default capability set:** the review/social toolkit · KB for brand voice + response policy · an **event
  trigger** on new review · persona with escalation rules for negative/legal cases.
- **The questions that matter:** Which platforms? Auto-respond or draft-for-approval? What's the escalation
  line for angry/legal reviews?
- **Standard guardrails:** escalate legal threats, safety issues, and severe complaints to a human; never
  argue with a customer; stay on-brand.
- **Known failure modes:** auto-posting when the user wanted approval-first; tone mismatch (no brand KB);
  no escalation for the cases that most need a human.

## Onboarding-Concierge

An agent that walks a new user/customer/employee through getting started — guided, stateful, helpful.

- **Trigger signals:** "onboard new customers", "welcome and set up", "guide users through", "activation
  assistant", "help people get started".
- **Core loop:** greet → understand where they are → guide the next step → check in → hand off when needed.
- **Default capability set:** persona with the onboarding path and tone · KB (setup docs, FAQs) · often a
  channel toolkit (email/chat) · optional recurring check-in trigger · conversation starters that map to the
  common first steps.
- **The questions that matter:** What's the onboarding journey (the steps)? What channel? Where does a stuck
  user get escalated?
- **Standard guardrails:** don't overwhelm; meet the user where they are; hand off to a human when they're
  blocked or frustrated.
- **Known failure modes:** dumping the whole journey at once; no state/awareness of progress; no human handoff.

---

## When nothing fits

Some requests are genuinely novel or a blend of pieces from several archetypes. When no single recipe fits:

- Compose the closest secondary archetypes' capability sets, and name the blend to the user in the plan.
- Fall back to the raw primitive-decision table (SOUL.md → Phase 2) and reason each primitive from the
  capability spec.
- Note the new shape in memory / juno with its signals and the capability set that worked, so the pattern
  library grows from real builds.

The goal is always an *informed* build — the archetype is a tool for getting there faster and more
reliably, never a cage.
