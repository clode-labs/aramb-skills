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

Turn "fire this workflow when <event> happens" into a `composio_event` trigger
row on a workflow, by calling the `aramb_triggers.*` write tools. You read the
catalog with `aramb_tools.*` (read-only) and persist with `aramb_triggers.*`
(write). The two namespaces are split for security and discoverability — look up
with one, mutate with the other.

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
  `composio_event` row in `workflow_triggers`.

If the request is ambiguous or asks for **both** ("run it daily AND when a new
issue arrives"), do NOT silently configure one and drop the other. Handle the
event part here, and tell the user the schedule part is handled by
`schedule-workflow` (or, if you're master in a chat with that skill in your
loadout, do the schedule there too) — never configure both blindly. The matching
router rule lives in `schedule-workflow`; keep the two consistent.

## What you need

- **`workflow_id`** — usually in the chat context (you're on the Workflow page).
  If you don't have it, resolve it from the application (one workflow per app):
  ```bash
  npx mcporter call aramb_workflows.get application_id="<APPLICATION_ID>"
  ```
  If no workflow exists, tell the user there's nothing to attach a trigger to and
  suggest they create one first (`create-workflow`). Stop.
- **`project_id` + `application_id`** — from your dispatch context (the
  "## Current Context" block). Needed for `aramb_chat.ask_question`.

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
npx mcporter call aramb_tools.list_toolkits
```

Match the service to a real toolkit slug (uppercase, e.g. `GITHUB`, `SLACK`,
`GMAIL`). Don't guess the slug — use the catalog value verbatim. If you can't find
a toolkit for the service the user named, tell them it isn't available and stop.

### 3. Read the trigger catalog for that toolkit

```bash
npx mcporter call aramb_tools.list_triggers toolkit="GITHUB"
```

This returns the trigger types for the toolkit — each with a `slug` (e.g.
`GITHUB_NEW_ISSUE`), a human name, and a description. Read names + descriptions
and pick the candidate that matches the user's event.

For the chosen slug, read its detail to learn what config it needs (some triggers
require parameters like owner/repo or a channel id) and what payload it delivers:

```bash
npx mcporter call aramb_tools.get_trigger toolkit="GITHUB" slug="GITHUB_NEW_ISSUE"
```

### 4. Disambiguate if needed

If two triggers plausibly match the intent ("issue created" vs "issue assigned to
you"; "any push" vs "push to a specific branch"), ask ONE clarifying question via
`aramb_chat.ask_question` and stop until the user answers. Same if a required
config value is missing and you can't infer it (which repo? which channel?).

```bash
npx mcporter call aramb_chat.ask_question \
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
npx mcporter call aramb_tools.check_connection toolkit="GITHUB"
```

If it reports no connected account, tell the user they need to connect <toolkit>
to this app first (the Connections UI), then stop — there's nothing to bind to.

Create the trigger. `slug` is the catalog trigger slug; `name` is a short
human label; `trigger_config` carries any required parameters from step 3 (omit
when the trigger needs none). Do NOT pass any payload-mapping / env-binding — in
v2 the trigger payload flows to the agent verbatim via `<run_input>`; there is no
mapping step.

```bash
npx mcporter call aramb_triggers.create \
  workflow_id="<WORKFLOW_ID>" \
  slug="GITHUB_NEW_ISSUE" \
  name="New GitHub issue" \
  trigger_config='{"owner":"acme","repo":"web"}' \
  enabled=true
```

(`kind` defaults to `composio_event` and `provider` to `composio` — you don't pass
them. If `check_connection` returned a specific account and the app has more than
one, pass `connected_account_id` too.)

### 6. Confirm activation BEFORE reporting success — async lifecycle

**Creating a `composio_event` trigger is asynchronous upstream.** The row is born
`pending_create`; brahmi then registers the trigger instance with the provider and
only then flips it to `active`. **Do NOT tell the user "done" while the status is
`pending_create`** — the registration may still fail.

Poll status until it settles:

```bash
npx mcporter call aramb_triggers.status workflow_id="<WORKFLOW_ID>" slug="GITHUB_NEW_ISSUE"
```

- `active` → success. The trigger is firing. Report it (step 7).
- `pending_create` → still registering. Wait briefly and poll again (a few times).
- `failed`, or the row is gone, or `aramb_triggers.create` itself returned an
  error → setup failed. brahmi rolls back on a provider create / activation
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

To pause without deleting (`aramb_triggers.update`), or remove entirely
(`aramb_triggers.delete`):

```bash
# Pause — keeps the row, stops firing
npx mcporter call aramb_triggers.update workflow_id="<WORKFLOW_ID>" slug="GITHUB_NEW_ISSUE" enabled=false

# Remove — deletes the row and the upstream instance
npx mcporter call aramb_triggers.delete workflow_id="<WORKFLOW_ID>" slug="GITHUB_NEW_ISSUE"
```

If you don't know which trigger the user means and the workflow has more than one,
list them (`aramb_triggers.status workflow_id="<WORKFLOW_ID>"` with no slug returns
all) and ask which one. Confirm the result in your reply text.

## Authorization failures — surface, don't retry

The `aramb_triggers.*` write tools enforce application ownership at the MCP
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
- **Ground every slug in the catalog.** Toolkit slugs via `aramb_tools.list_toolkits`,
  trigger slugs via `aramb_tools.list_triggers`. Never invent a slug from prose.
- **Read before write.** `aramb_tools.*` is read-only lookup; `aramb_triggers.*` is
  the write surface. Look up the trigger and its config needs before creating.
- **Ask, don't guess.** Ambiguous event or a missing required config value → one
  `aramb_chat.ask_question`, then stop until answered.
- **No payload mapping / env binding.** The trigger payload reaches the agent
  verbatim through `<run_input>` in v2 — there is nothing to map. Never pass a
  payload-mapping argument.
- **Never report success on `pending_create`.** Poll `aramb_triggers.status` until
  `active`. `failed` / rolled-back → report "trigger setup failed: <reason>".
- **Authorization rejection is terminal.** Surface "you don't have permission to
  configure triggers on this workflow" and stop — no retry.
- **Confirm in your reply text** (brahmi saves it as the chat row) — success with
  the event + status, or the concise failure reason.
