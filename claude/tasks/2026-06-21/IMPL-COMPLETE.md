# IMPL-COMPLETE — aramb-skills: random delay + run status callbacks

**Branch:** `feat/trigger-jitter-and-callbacks`
**Task doc:** `claude/tasks/2026-06-21/trigger-jitter-and-callbacks.md`
**Workspace design doc:** `/Users/siva/workspace/claude/tasks/2026-06-21/workflow-trigger-jitter-and-callbacks.md`

Documentation-only change (markdown SKILL.md files — no build step). All `npx mcporter call`
examples were sanity-checked for internal consistency with the documented args.

## New MCP surface documented (agreed contract — matches brahmi)

### Feature 1 — Random delay (cron-only)
Two optional args on `aramb_mcp.workflows_set_schedule`:
- `random_delay_enabled` (bool, default `false`)
- `random_delay_max_minutes` (int, optional) — absolute cap; effective delay =
  `min(random_delay_max_minutes, 80% of the gap to the next tick)`, chosen fresh each fire.
  Omit ⇒ cap is purely 80% of the gap. **Cron-only**; does not apply to event/toolkit triggers.
- Echoed in `get_schedule` / the `schedule` response view.
- Agent speaks **minutes**; brahmi stores seconds (never surfaced in skills).

### Feature 2 — Run status callback (workflow-level webhook)
New tool `aramb_mcp.workflows_set_callback`:
- Args: `workflow_id`, `callback_url`.
- Returns a **signing secret ONCE** — agent surfaces it verbatim and warns it won't be shown again.
- Fires on every real run (manual, cron, event); preview/test runs excluded. POSTs on start
  (`running`) and terminal (`completed`/`failed`/`cancelled`).
- Signed payload contract documented (headers `Webhook-Id`, `Webhook-Timestamp`,
  `Webhook-Signature: v1,<base64 HMAC-SHA256(secret, "{Webhook-Id}.{Webhook-Timestamp}.{raw-body}")>`;
  body fields `event, run_id, workflow_id, workflow_name, application_id, project_id, status,
  trigger_type, started_at, finished_at, error_message, duration_ms`).
- Retried with backoff; receiver must be idempotent on `Webhook-Id`.
- `callback_url` surfaced in `get`/`list` output; the secret is never returned again.

## Files + sections changed

### `schedule-workflow/SKILL.md`
- **Step 4 (response fields):** added `random_delay_enabled` + `random_delay_max_minutes` to the
  documented `schedule` response view.
- **New "### 4a. Randomize fire time (cron-only — optional)" subsection:** the two args, an example
  `set_schedule` call using them, the 80%-of-gap clamp, never-spills-past-next-tick invariant, and
  cron-only scope.
- **Rules:** added a line noting random delay is optional, off by default, cron-only, and clamped.

### `aramb-workflows/SKILL.md`
- **List-row shape:** added `callback_url` to the row JSON; added `random_delay_enabled` +
  `random_delay_max_minutes` to the `schedule` object; noted secret is never returned in list.
- **Single-workflow `get`:** added `callback_url` to the returned-fields sentence.
- **"Set / update schedule":** added the optional `random_delay_enabled` /
  `random_delay_max_minutes` bullet with the clamp + cron-only note.
- **"Read schedule":** added `random_delay_enabled`, `random_delay_max_minutes` to the returned fields.
- **New "## Run status callbacks (workflow-level webhook)" section:** the `set_callback` tool
  (args, one-time-secret behavior), the full signed payload contract, and the retry/idempotency note.

### `create-workflow/SKILL.md`
- **Section 6 (chat dispatch cron reminder):** added the optional `random_delay_enabled` /
  `random_delay_max_minutes` cron-only args to the `set_schedule` example note.
- **New "## 4.6 Run-status callback — optional, only if asked" section:** `set_callback` tail step
  (after create succeeds), one-time-secret surfacing, "only if the user asked" guardrail, pointer to
  the `aramb-workflows` contract. Routing rules unchanged (pure schedule changes still route to
  `schedule-workflow`).

### `update-workflow/SKILL.md`
- **Step 3 (firing-condition routing):** added "stagger the fire time" as a cron-shaped phrase
  routing to `schedule-workflow`, noting the `random_delay_*` jitter lives in the cron columns; added
  a new **Run-status callback** routing bullet (set via `aramb_mcp.workflows_set_callback`, NOT a
  definition change, do not call `aramb_mcp.workflows_update` for it).

### `import-workflow/SKILL.md`
- **Step 5 (Schedule):** added a note to pass `random_delay_enabled` / `random_delay_max_minutes`
  through when a template carries a randomized cadence; omit for plain cron.

## Guardrails honored
- No push / no PR.
- No fields invented beyond the agreed contract.
- Edits are surgical extensions of existing sections; skill voice/structure preserved.
- Agent-facing docs speak minutes only; "seconds" never leaked.

## Run-flow addendum

**Task doc:** `claude/tasks/2026-06-21/run-workflow-mcp-addendum.md`

Documented the new `aramb_mcp.workflows_run` tool + the confirm-first "run an existing workflow"
flow. **Locked policy: ALWAYS confirm the specific workflow before running, even on an exact
name match** (list → fuzzy-match → confirm → run).

### New MCP surface documented
`aramb_mcp.workflows_run`:
- Args: `workflow_id` (required), `custom_instruction` (optional free-form text passed into the
  workflow's first step `<run_input>` — included only if the user gave extra per-run context).
- Kicks off a single manual run; returns a `run_id`.

### Files + sections changed
- **`aramb-workflows/SKILL.md`** — intro overview line now enumerates `aramb_mcp.workflows_run`
  (confirm-first); new **"## Running an existing workflow (manual run)"** section: trigger phrases,
  the 4-step list→match→confirm→run flow, multiple-match / no-match / non-runnable-status handling,
  the optional `custom_instruction`, and the guardrails (never run without explicit confirmation,
  never guess a `workflow_id`, one run per confirmation).
- **`workspace-solo/AGENTS.md`** — added a one-line `aramb_mcp.workflows_run` (confirm-first) bullet to
  the workflow tool inventory.
- **`workspace-master/AGENTS.md`** — added the same one-line bullet under Tools & Skills.

### Guardrails honored
- Confirm-first policy stated explicitly; no run path that skips confirmation.
- No invented args beyond `workflow_id` + optional `custom_instruction`.
- Surgical edits; terse example-first voice preserved. No push / PR.
