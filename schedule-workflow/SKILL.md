---
name: schedule-workflow
description: >
  Configure a cron schedule on a workflow from a natural-language phrase.
  Use when the user says things like "run this weekly", "every Monday at 9am",
  "stop the schedule", "pause it", "disable the schedule". NOT for: event-driven
  triggers ("fire when a new GitHub issue is created" → use configure-trigger),
  triggering a single one-off run, or editing the workflow definition.
---

# Schedule Workflow

Translate a user's natural-language schedule request into a cron expression
+ timezone, then call `aramb_workflows.set_schedule`. The workflow already has a
schedule slot (one schedule per workflow) — this skill writes to it.

You are typically replying to a chat message on the Workflow page. The user
asked something like:
- "Run this every Monday at 9am"
- "Set it to run weekly"
- "Schedule for 2pm UTC every weekday"
- "Stop the schedule" / "Pause it"

The workflow_id is in the chat context (from the Workflow page). If you don't
have it, list the project's workflows and pick the right one:
`aramb_workflows.list project_id="<PROJECT_ID>"` (a project can hold several
workflows — appless is the norm; if more than one matches, ask which).

## Schedule vs trigger — route first

This skill only handles **wall-clock schedules** (cron): a fixed cadence or
time-of-day. If the user instead wants the workflow to fire on an **event** in a
connected service ("when a new GitHub issue is created", "on every push", "when I
get a Slack DM"), that's an event trigger — hand off to the `configure-trigger`
skill and stop. Signals that mean event, not schedule: a *thing that happens*
rather than a clock or calendar.

If the request asks for **both** ("run it daily AND when a new issue arrives"),
handle the cron part here and tell the user the event part is configured via
`configure-trigger` — don't silently drop it. (The matching router rule lives in
`configure-trigger`; keep the two consistent.)

## Invoked from create-workflow / update-workflow (sub-mode)

When `create-workflow` (or `update-workflow`) calls you mid-authoring after the
trigger picker chose **cron**, you arrive with a pre-resolved `workflow_id` and
the cadence the user already gave. **Skip step 2 (clarify)** — the cadence is
settled. Map it to a cron expression (step 3) and call `aramb_workflows.set_schedule`
(step 4) directly. Only fall back to a clarifying `aramb_chat.ask_question` if the
supplied cadence genuinely can't be mapped (missing time-of-day, ambiguous day).
Standalone use (user invokes directly) runs the full flow below.

## Workflow

### 1. Decide intent

Three branches:

- **Pause / disable** ("stop", "pause", "disable", "turn off"): go to step 4
  with `enabled=false`.
- **Set / update** ("run weekly", "every Monday at 9am", "schedule for 2pm UTC"):
  go to step 2.
- **Read / confirm** ("what's the schedule?", "when does this run?"): call
  `aramb_workflows.get_schedule workflow_id="<workflow_id>"` and report what you find.
  No write needed.

### 2. Clarify if ambiguous

Some phrases do not have enough information to map to a cron expression. Ask
the user **one** clarifying question via `aramb_chat.ask_question` and stop until
they answer. Do NOT invent a default like "Sunday midnight UTC" silently.

Phrases that need a clarifying question:

- "weekly" → which day? what time?
- "monthly" → which day of the month? what time?
- "every day" / "daily" → what time?
- Any time-of-day request without a timezone, when the workspace's timezone is
  not known.

Phrases that DO have enough information (act directly):

- "every Monday at 9am UTC" → `0 9 * * 1` UTC
- "weekdays at 2pm Pacific" → `0 14 * * 1-5` America/Los_Angeles
- "first of every month at midnight UTC" → `0 0 1 * *` UTC
- "every 6 hours" → `0 */6 * * *` UTC
- "every 30 minutes" → `*/30 * * * *` UTC

When you ask, give 2–3 specific options:

```
Question: When should this run weekly?
1. Mondays at 9am UTC
2. Sundays at midnight UTC
3. Specify your own day + time
```

### 3. Map to a cron expression

Use the standard 5-field format: `M H DoM Mon DoW`.

- M = minute (0–59), H = hour (0–23, 24h)
- DoM = day of month (1–31), Mon = month (1–12), DoW = day of week (0–6, Sunday=0)
- `*` = every value, `*/N` = every Nth, `1-5` = range, `1,3,5` = list.

Common patterns:
- Daily at 9am: `0 9 * * *`
- Weekly on Monday at 9am: `0 9 * * 1`
- Weekdays at 9am: `0 9 * * 1-5`
- Hourly on the hour: `0 * * * *`
- Monthly on the 1st at midnight: `0 0 1 * *`

Default timezone: **UTC**. If the user named a timezone ("Pacific", "EST",
"London"), translate to its IANA name (`America/Los_Angeles`, `America/New_York`,
`Europe/London`) and use that. **Tell the user explicitly which timezone you
used** in your reply — never silently apply one.

### 4. Call aramb_workflows.set_schedule

For an enable / update:

```bash
npx mcporter call aramb_workflows.set_schedule \
  workflow_id="<workflow_id>" \
  cron_expression="0 9 * * 1" \
  cron_timezone="UTC" \
  enabled=true
```

For a pause / disable:

```bash
npx mcporter call aramb_workflows.set_schedule \
  workflow_id="<workflow_id>" \
  enabled=false
```

The response includes the resulting `schedule` view: `cron_expression`,
`cron_timezone`, `enabled`, `next_run_at`, `auto_triggerable`,
`missing_required_env`, plus `random_delay_enabled` + `random_delay_max_minutes`
(see "Randomize fire time" below). If `auto_triggerable` is `false`, the schedule
was saved but won't fire until the user provides the listed env values — relay
that to the user.

### 4a. Randomize fire time (cron-only — optional)

If the user wants runs to NOT land on robotic exact times ("don't fire at exactly
9:00", "stagger it a bit", "make it look less bot-like"), enable random delay. Two
extra args on the same `set_schedule` call:

- `random_delay_enabled` (bool, default `false`)
- `random_delay_max_minutes` (int, optional) — an absolute cap on the delay

```bash
npx mcporter call aramb_workflows.set_schedule \
  workflow_id="<workflow_id>" \
  cron_expression="0 9 * * *" \
  cron_timezone="UTC" \
  random_delay_enabled=true \
  random_delay_max_minutes=20 \
  enabled=true
```

How it behaves: each fire lands at a random point **after** the scheduled tick, up
to a cap chosen fresh every fire. The cap is `min(random_delay_max_minutes, 80% of
the gap to the next tick)` — so a jittered run **always** lands before the next
scheduled tick (no overlap, no skipped run) even if the user sets a large cap. Omit
`random_delay_max_minutes` ⇒ the cap is just 80% of the gap. The fields are echoed
in `get_schedule`/the `schedule` response view.

**Cron-only.** Random delay applies to wall-clock schedules only — it does not
apply to event/toolkit triggers (those fire on external events, with no scheduled
gap to jitter within). Default is off; only enable it when the user asks.

### 5. Confirm in chat

Write the confirmation in your reply text (brahmi saves it as the chat row — no MCP call needed). Confirm:

- The cron expression in plain English ("Mondays at 9am UTC")
- The next scheduled run (from `next_run_at` in the response)
- Any caveats (auto_triggerable=false, missing_required_env list)

```
Schedule set: every Monday at 9am UTC. Next run: 2026-05-04 09:00 UTC.
```

For a pause:

```
Schedule paused. The workflow won't run on its schedule until you re-enable it.
```

## Rules

- Never silently default an ambiguous phrase. Ask one clarifying question with
  2–3 options, then stop.
- Default timezone is UTC. State the timezone you used in your reply.
- Use 5-field cron only. No seconds field.
- Random delay (`random_delay_enabled` / `random_delay_max_minutes`) is optional,
  off by default, and cron-only — enable it only when the user asks. The effective
  delay is clamped to 80% of the gap to the next tick, so a jittered run never
  spills past it.
- For pause/disable, `cron_expression` and `cron_timezone` can be omitted — the
  saved values stay so the user can re-enable later without retyping.
- Do not edit the workflow definition from this skill — that's update-workflow.
