# aramb-skills — Document Random Delay + Run Status Callbacks

**Workspace design doc (read first):**
`/Users/siva/workspace/claude/tasks/2026-06-21/workflow-trigger-jitter-and-callbacks.md`
**Branch:** `feat/trigger-jitter-and-callbacks` (checked out, off fresh `origin/main`)
**Model:** claude-opus-4-8[1m]

This repo owns the **agent-facing contract** for workflow schedules/triggers. Two brahmi features
are being added; document them so agents discover and use them. The MCP tool names/args below are
the agreed contract (brahmi implements the same) — match exactly.

## 1. Random delay on cron schedules (cron-only)

Two new args on `aramb_workflows.set_schedule`:
- `random_delay_enabled` (bool, default false)
- `random_delay_max_minutes` (int, optional) — absolute cap; the effective delay is
  `min(this, 80% of the interval gap)`, chosen fresh each fire. Omit ⇒ cap is just 80% of the gap.

Behavior to explain: when enabled, the run fires at a random point **after** its scheduled time, up
to the cap, so runs don't land on robotic exact times (looks less bot-like). It never spills past the
next scheduled tick. Cron-only — does not apply to event/toolkit triggers.

**Files to update:**
- `schedule-workflow/SKILL.md` — add the two args to the `set_schedule` example + a short
  "Randomize fire time" subsection; note the 80%-of-gap clamp and cron-only scope; mention the
  fields appear in `get_schedule`/schedule responses.
- `aramb-workflows/SKILL.md` — update the `set_schedule` tool args list + the `schedule` object shape
  shown in list/get responses (add `random_delay_enabled`, `random_delay_max_minutes`).
- `create-workflow/SKILL.md` + `update-workflow/SKILL.md` — where `set_schedule` examples appear, add
  the optional args; keep routing rules intact (pure schedule changes still route to
  `schedule-workflow`).
- `import-workflow/SKILL.md` — if a template carries a randomized cadence, pass the args through.

## 2. Workflow-level callback_url (run status webhook)

New tool `aramb_workflows.set_callback`:
```
npx mcporter call aramb_workflows.set_callback \
  workflow_id="<WORKFLOW_ID>" \
  callback_url="https://example.com/hooks/run-status"
```
- Returns a **signing secret ONCE** in the response — the agent must surface it to the user verbatim
  and tell them it won't be shown again (used to verify `Webhook-Signature`).
- Workflow-level: every real run of the workflow (manual, cron, event) POSTs status. Preview/test
  runs are excluded.
- Fires on **start** (`running`) and on **terminal** (`completed`/`failed`/`cancelled`).

Document the **signed payload contract** (must match brahmi exactly):
```
POST <callback_url>
Webhook-Id, Webhook-Timestamp, Webhook-Signature: v1,<base64 HMAC-SHA256(secret, "{id}.{ts}.{body}")>
{ "event","run_id","workflow_id","workflow_name","application_id","project_id",
  "status","trigger_type","started_at","finished_at","error_message","duration_ms" }
```
Explain delivery is retried with backoff (receiver should be idempotent on `Webhook-Id`).

**Files to update:**
- `aramb-workflows/SKILL.md` — add the `set_callback` tool (args, one-time-secret behavior, payload
  contract, retry note); surface `callback_url` in workflow get/list output (never the secret).
- `create-workflow/SKILL.md` + `update-workflow/SKILL.md` — add an optional "set a run-status
  callback" tail step / routing note (workflow-level config, set via `set_callback`).

## Style / guardrails
- Match the existing SKILL.md voice and structure (terse, example-first). Keep edits minimal and
  surgical — extend existing sections, don't rewrite skills.
- Do NOT invent fields beyond the contract above. `random_delay_max_minutes` (skills/agent-facing) ↔
  brahmi stores seconds; the agent always speaks minutes.
- No build step here (markdown skills). Sanity-check that every `npx mcporter call` example is
  internally consistent with the args you documented.
