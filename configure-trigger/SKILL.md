---
name: configure-trigger
description: >
  Configure an EVENT trigger on a workflow from a natural-language phrase —
  make a workflow fire when something happens in a connected service. Use when
  the user says things like "fire this when a new GitHub issue is created",
  "run this whenever I get a Slack DM", "trigger on every push to main", "stop
  firing on new issues", "remove the trigger". NOT for: wall-clock / cron
  schedules ("run this every Monday at 9am" → use schedule-workflow), creating
  or editing the workflow definition (use create-workflow / update-workflow), or
  triggering a single one-off run.
---

# Configure Trigger

Turn "fire this workflow when <event> happens" into a `toolkit_event` trigger
row on a workflow, by calling the `aramb_mcp.triggers_*` write tools. You read the
catalog with `aramb_mcp.toolkits_*` (read-only) and persist with `aramb_mcp.triggers_*`
(write). The two namespaces are split for security and discoverability — look up
with one, mutate with the other.

> **The `aramb_mcp.toolkits_*` call contract (`list_toolkits`, `list_triggers`,
> `get_trigger`, `check_connection` — arg is `toolkit=`, never `toolkit_slug`)
> is documented canonically in the `aramb-toolkits` skill.** This skill just uses
> those calls in its flow; read `aramb-toolkits` for the full arg reference. For
> the actual data fetch / action (not trigger wiring), that's
> `aramb_mcp.toolkits_execute` (same skill).

> **Schedules are NOT triggers.** A wall-clock cadence ("daily at 9am", "every
> Monday", a cron expression) is a *schedule* and lives on different storage with
> a different skill. See "Schedule vs trigger — route first" below. If the intent
> is a clock, hand off to `schedule-workflow` and stop.

## Schedule vs trigger — route first

Before doing anything, classify the user's intent:

- **Wall-clock schedule** → `schedule-workflow`, NOT this skill. Signals: "every
  day / week / hour", "at 9am", "on Mondays", "daily/weekly/monthly", any cron
  expression, any fixed time-of-day. These map to a cron slot on the workflow row.
- **Event trigger** → this skill. Signals: a *thing that happens* in a service —
  "when a new GitHub issue is created", "on every push", "whenever a row is added
  to the sheet", "when I receive a Slack message". These map to a
  `toolkit_event` row in `workflow_triggers`.

If the request is ambiguous or asks for **both** ("run it daily AND when a new
issue arrives"), do NOT silently configure one and drop the other. Handle the
event part here, and tell the user the schedule part is handled by
`schedule-workflow` (or, if you're master in a chat with that skill in your
loadout, do the schedule there too) — never configure both blindly. The matching
router rule lives in `schedule-workflow`; keep the two consistent.

## What you need

- **`workflow_id`** — usually in the chat context (you're on the Workflow page).
  If you don't have it, find the project's workflows and pick the right one:
  ```bash
  npx mcporter call aramb_mcp.workflows_list project_id="<PROJECT_ID>"
  ```
  (A project can hold several workflows — appless is the norm; don't assume one
  per application. If more than one matches, ask the user which.) If no workflow
  exists, tell the user there's nothing to attach a trigger to and suggest they
  create one first (`create-workflow`). Stop.
- **`project_id` + `application_id`** — from your dispatch context (the
  "## Current Context" block). Needed for `aramb_mcp.chat_ask_question`.

## Invoked from create-workflow / update-workflow (sub-mode)

When `create-workflow` (or `update-workflow`) calls you mid-authoring, the trigger
picker already ran — you arrive with a **pre-resolved `workflow_id` and a
pre-chosen catalog `slug`** (and sometimes `trigger_config`). In that case:

- **Skip steps 1, 2, 4** (parse intent, narrow toolkit, disambiguate) — the
  upstream picker already grounded the slug against `aramb_mcp.toolkits_list_triggers`.
- **Do NOT skip step 3's `get_trigger` call** when the trigger needs config. Most
  event triggers require parameters (GitHub triggers require `owner` + `repo`;
  Slack needs a channel; Sheets needs a spreadsheet id). Call
  `aramb_mcp.toolkits_get_trigger toolkit=<TK> slug=<slug>` to read `config_schema`,
  then assemble those values into **`trigger_config`** (see step 5 — the arg is
  literally `trigger_config`, never `config`). Skipping this is the #1 cause of a
  Composio 400 ("owner/repo Required") that surfaces back as a 502 from the integrations proxy.
- Then **step 5**: `aramb_mcp.toolkits_check_connection` for the slug's toolkit, then
  `aramb_mcp.triggers_create workflow_id=<id> trigger_slug=<slug> trigger_config=<…>`.
- Then **step 6**: confirm the row reaches `active` before reporting success.

The `workflow_id` already exists (create-workflow saved the workflow first), so
the precondition in "What you need" is satisfied — don't re-resolve it. Standalone
use (user invokes the skill directly) is unchanged: run the full flow below.

## Flow

### 1. Parse the intent

Pull out (a) the service the event comes from (GitHub, Slack, Gmail, …) and
(b) the event itself (issue created, push, message received). If the user named a
specific resource ("issues in `org/repo`", "the #alerts channel"), capture it —
many triggers need it as config.

If the user is asking to **disable or remove** an existing trigger ("stop firing
on new issues", "turn off the trigger"), skip to step 6.

### 2. Narrow to the toolkit

```bash
npx mcporter call aramb_mcp.toolkits_list_toolkits
```

Match the service to a real toolkit slug (uppercase, e.g. `GITHUB`, `SLACK`,
`GMAIL`). Don't guess the slug — use the catalog value verbatim. If you can't find
a toolkit for the service the user named, tell them it isn't available and stop.

### 3. Read the trigger catalog for that toolkit

```bash
npx mcporter call aramb_mcp.toolkits_list_triggers toolkit="GITHUB"
```

This returns the trigger types for the toolkit — each with a `slug` (e.g.
`GITHUB_NEW_ISSUE`), a human name, and a description. Read names + descriptions
and pick the candidate that matches the user's event.

For the chosen slug, read its detail to learn what config it needs (some triggers
require parameters like owner/repo or a channel id) and what payload it delivers:

```bash
npx mcporter call aramb_mcp.toolkits_get_trigger toolkit="GITHUB" slug="GITHUB_NEW_ISSUE"
```

### 4. Disambiguate if needed

If two triggers plausibly match the intent ("issue created" vs "issue assigned to
you"; "any push" vs "push to a specific branch"), ask ONE clarifying question via
`aramb_mcp.chat_ask_question` and stop until the user answers. Same if a required
config value is missing and you can't infer it (which repo? which channel?).

```bash
npx mcporter call aramb_mcp.chat_ask_question \
  project_id="<PROJECT_ID>" \
  application_id="<APPLICATION_ID>" \
  question="Which GitHub event should this fire on?" \
  options='["A new issue is opened", "An issue is assigned to me", "A new pull request is opened"]'
```

Don't invent a config value silently — if a trigger needs a repo and the user
didn't name one, ask.

### 5. Check the connection, then create

The toolkit must have a connected account for this application — the trigger binds
to it. Confirm:

```bash
npx mcporter call aramb_mcp.toolkits_check_connection toolkit="GITHUB"
```

If it reports no connected account, tell the user they need to connect <toolkit>
to this app first (the Connections UI), then stop — there's nothing to bind to.

Create the trigger. `trigger_slug` is the catalog trigger slug; `name` is a short
human label; **`trigger_config`** (that EXACT key — NOT `config`) carries the
required parameters from step 3's `config_schema`. Passing them under `config`
(or omitting them) makes the platform send an empty config and Composio rejects it with
a 400 ("owner/repo Required") that comes back as a confusing 502 from the integrations proxy.
GitHub issue/PR triggers REQUIRE `{"owner": "...", "repo": "..."}` inside
`trigger_config`. Do NOT pass any payload-mapping / env-binding — in v2 the
trigger payload flows to the agent verbatim via `<run_input>`; there is no
mapping step.

```bash
npx mcporter call aramb_mcp.triggers_create \
  workflow_id="<WORKFLOW_ID>" \
  trigger_slug="GITHUB_NEW_ISSUE" \
  name="New GitHub issue" \
  connected_account_id="<from check_connection>" \
  trigger_config='{"owner":"acme","repo":"web"}' \
  enabled=true
```

Exact required arg names: `workflow_id`, `trigger_slug` (NOT `slug`), `name`,
`connected_account_id` (from `check_connection` — REQUIRED, don't invent), and
`trigger_config` (NOT `config`) for triggers that need parameters. (`kind`
defaults to `toolkit_event` and `provider` to `composio` — you don't pass them.)

### 6. Confirm activation BEFORE reporting success — async lifecycle

**Creating a `toolkit_event` trigger is asynchronous upstream.** The row is born
`pending_create`; the platform then registers the trigger instance with the provider and
only then flips it to `active`. **Do NOT tell the user "done" while the status is
`pending_create`** — the registration may still fail.

Poll status until it settles:

```bash
npx mcporter call aramb_mcp.triggers_status workflow_id="<WORKFLOW_ID>" slug="GITHUB_NEW_ISSUE"
```

- `active` → success. The trigger is firing. Report it (step 7).
- `pending_create` → still registering. Wait briefly and poll again (a few times).
- `failed`, or the row is gone, or `aramb_mcp.triggers_create` itself returned an
  error → setup failed. The platform rolls back on a provider create / activation
  failure (it deletes the placeholder row and any upstream instance), so the
  trigger does NOT exist. Report the failure with the reason (`last_error` if
  present) as **"trigger setup failed: <reason>"** — do NOT claim success.

### 7. Report

On success, write a one-line confirmation in your reply text:

```
Trigger set: this workflow now fires on a new GitHub issue in acme/web. Status: active.
```

On failure, state plainly what went wrong and what the user can do (connect the
account, pick a different event, supply the missing repo) — then stop. Don't retry
a failed create with the same payload.

## Disable / remove a trigger (step 1 routed here)

To pause without deleting (`aramb_mcp.triggers_update`), or remove entirely
(`aramb_mcp.triggers_delete`):

```bash
# Pause — keeps the row, stops firing
npx mcporter call aramb_mcp.triggers_update workflow_id="<WORKFLOW_ID>" slug="GITHUB_NEW_ISSUE" enabled=false

# Remove — deletes the row and the upstream instance
npx mcporter call aramb_mcp.triggers_delete workflow_id="<WORKFLOW_ID>" slug="GITHUB_NEW_ISSUE"
```

If you don't know which trigger the user means and the workflow has more than one,
list them (`aramb_mcp.triggers_status workflow_id="<WORKFLOW_ID>"` with no slug returns
all) and ask which one. Confirm the result in your reply text.

## Authorization failures — surface, don't retry

The `aramb_mcp.triggers_*` write tools enforce application ownership at the MCP
boundary (the same check the REST surface applies). If a call is rejected for
**permission / authorization** — the workflow belongs to an application you don't
own — that is NOT a transient error. Do NOT retry, do NOT try a different payload.
Surface it cleanly:

```
I can't configure triggers on this workflow — it belongs to an application you don't have access to.
```

Then stop.

## Rules

- **Route first.** Cron / wall-clock cadence → `schedule-workflow`, not this skill.
  Event → this skill. Never silently configure both for a mixed request.
- **Ground every slug in the catalog.** Toolkit slugs via `aramb_mcp.toolkits_list_toolkits`,
  trigger slugs via `aramb_mcp.toolkits_list_triggers`. Never invent a slug from prose.
- **Read before write.** `aramb_mcp.toolkits_*` is read-only lookup; `aramb_mcp.triggers_*` is
  the write surface. Look up the trigger and its config needs before creating.
- **Ask, don't guess.** Ambiguous event or a missing required config value → one
  `aramb_mcp.chat_ask_question`, then stop until answered.
- **No payload mapping / env binding.** The trigger payload reaches the agent
  verbatim through `<run_input>` in v2 — there is nothing to map. Never pass a
  payload-mapping argument.
- **Never report success on `pending_create`.** Poll `aramb_mcp.triggers_status` until
  `active`. `failed` / rolled-back → report "trigger setup failed: <reason>".
- **Authorization rejection is terminal.** Surface "you don't have permission to
  configure triggers on this workflow" and stop — no retry.
- **Confirm in your reply text** (the platform saves it as the chat row) — success with
  the event + status, or the concise failure reason.
