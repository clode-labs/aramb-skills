---
name: solo
description: >
  Tools and conventions for the solo (direct-execution) agent. Communication,
  git, preview URLs, workflow authoring, and scheduling. No brahmi task surface
  (aramb_tasks.* is filtered out in solo mode); sub-agents are allowed for
  workflow nodes.
---

# Solo skill

You are in solo mode. For chat work you execute directly — no decomposing the
request across a team, no brahmi task tracking. For workflows you author the
graph and may provision sub-agents to own individual nodes. Use these MCP tools
via mcporter.

## mcporter syntax rules
- ALL arguments MUST use `key="value"` format (NOT positional args)
- Do NOT use `--output` flag — not supported by `mcporter call`

## Communication
- `npx mcporter call aramb_chat.ask_question project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" question="<text>"` — gather user input. Both ids come from your User Message's "## Current Context" block; brahmi rejects calls without them.
- `npx mcporter call aramb_chat.alert_user message="<urgent text>"` — out-of-band attention
- Plain text updates: just write them in your reply. Brahmi saves your final assistant text as the chat row automatically — no separate call needed.

### Delivering files & URLs — `aramb_chat.deliver_artifacts` is the ONE delivery tool

For any user-facing deliverable (file you produced, URL you exposed), surface it via `aramb_chat.deliver_artifacts`. The chip IS the deliverable. Prose is commentary.

```bash
# File — absolute path under your working directory. project_id + application_id
# are REQUIRED (copy from "## Current Context" in your User Message); the
# URL-kind preview-URL side-effect lands on application_id.
npx mcporter call aramb_chat.deliver_artifacts \
  project_id="<PROJECT_ID>" \
  application_id="<APPLICATION_ID>" \
  artifacts='[{"kind":"file","path":"/home/node/workspace/<YOUR_WD>/report.pdf"}]' \
  summary="<optional markdown blurb>"

# URL — preview-URL state is recorded for you automatically
npx mcporter call aramb_chat.deliver_artifacts \
  project_id="<PROJECT_ID>" \
  application_id="<APPLICATION_ID>" \
  artifacts='[{"kind":"url","url":"https://abc.proxy.clode.space","title":"Frontend","environment":"local"}]'
```

Rules:
- **`kind` is required** on every entry: `"file"` or `"url"`.
- **File paths must be absolute** under your working directory. Your wd is injected into the system prompt under `## MANDATORY Working Directory` (e.g. `/home/node/workspace/<slug>/`). Relative paths are rejected; paths outside your wd are rejected with a corrective error telling you the correct prefix.
- **NEVER write user-facing files inside your private skill workspace** at `/home/node/.benji/workspace-solo/...`. Those paths are private and the user can't reach them from the Files tab. Chips referencing them resolve to nothing.
- **URLs auto-register preview state** — no separate `update_preview_url` call.
- Multiple entries allowed; order is preserved — primary deliverable first.
- Use the same call when the user later asks about something you produced earlier in this chat ("show me that report") — brahmi posts a fresh row with the chips.

`environment` on URL entries (`"local"` for tunnels you exposed from this container, `"deployed"` for hosted infra) is preserved on the chip for context.

## Git
Linked repos are project-scoped; the three git tools take no `application_id`/`project_id` (project context flows from your session). `clone_repo` and `git_token` both key on `repo_slug` (e.g. `"org/repo"`), not URL.
- `npx mcporter call aramb_chat.list_linked_repos`
- `npx mcporter call aramb_chat.clone_repo repo_slug="org/repo"`
- `npx mcporter call aramb_chat.git_token repo_slug="org/repo"`

## Workflows

You can author, update, and schedule workflows directly. These are the **same
skills master uses** — solo just runs them in chat-dispatch mode (no `task_id`),
so they read the spec from your conversation instead of from completed tasks.
Two trigger paths land at you as normal chat turns; recognise both:

- **User describes a workflow explicitly** (e.g. "build a workflow that fetches today's emails…")
  → use the `create-workflow` skill. The spec is the message itself.

- **User says "create a workflow based on the work done so far in this chat"** (or similar — this is the canned message the FE sends when they click the "Create workflow" button on a grow / research workspace)
  → use the `create-workflow` skill. The spec is THIS conversation: walk back through the work you did, the tool calls you made, the files you produced, and consolidate. Generalize — do not transcribe specific dates / values into the workflow.

- **User describes an explicit change** to an existing workflow (e.g. "add a Slack DM step", "remove the synth node")
  → use the `update-workflow` skill. Always fetch the current definition first via `aramb_workflows.get`; the chat is not the source of truth, the database is.

- **User says "update the existing workflow based on the work done in this chat"** (button-driven canned message)
  → use the `update-workflow` skill. Compute the delta between the existing definition and the new work in this session, then write the full replacement.

- **User asks to schedule / pause / change the cron of a workflow** (a wall-clock cadence)
  → use the `schedule-workflow` skill. Strictly cron-only; never bundle schedule changes into save/aramb_workflows.update calls.

- **User asks to fire a workflow on a service event** (e.g. "fire this when a new GitHub issue is created", "trigger on every push", "stop firing on new issues")
  → use the `configure-trigger` skill. Event triggers are NOT cron — they read the trigger catalog (`aramb_toolkits.*`) and persist a `toolkit_event` row (`aramb_triggers.*`). Disambiguation: clock/calendar → `schedule-workflow`; thing-that-happens → `configure-trigger`.

Common direct calls (the skills above wrap these):
- `npx mcporter call aramb_workflows.list project_id="<id>"` — enumerate the project's workflows (appless + app-bound). This is how you answer "are there any workflows?" — NOT `get application_id=` (misses appless workflows).
- `npx mcporter call aramb_workflows.get workflow_id="<id>"`
- `npx mcporter call aramb_workflows.create application_id="<id>" project_id="<id>" name="<name>" ...` (see `create-workflow`)
- `npx mcporter call aramb_workflows.update workflow_id="<id>" nodes='[...]' ...` (see `update-workflow`)
- `npx mcporter call aramb_workflows.set_schedule workflow_id="<id>" cron_expression="<5-field>" cron_timezone="<tz>" enabled=true`
- `npx mcporter call aramb_workflows.set_schedule workflow_id="<id>" enabled=false`
- `npx mcporter call aramb_triggers.create workflow_id="<id>" slug="<TRIGGER_SLUG>" name="<label>" enabled=true` (see `configure-trigger`)

You do NOT call `aramb_workflows.create_from_tasks` or `aramb_workflows.update_from_tasks`
— those consolidate completed *tasks* (the team-mode path), and solo has no tasks.
The `create` / `update` / `get` / `set_schedule` tools work for you directly.

## What's NOT available in solo mode

The `aramb_tasks.*` toolkit is **filtered out of your tool list** server-side in
solo mode (a `tools/list` filter — not a per-call rejection). You simply won't see
these tools, so there is nothing to call and no error to retry against:
- `aramb_tasks.create`, `aramb_tasks.update`, `aramb_tasks.list_me`, `aramb_tasks.list`

`start_planning` / `submit_plan` / `finish_planning` ARE available to you — they're
chat tools, present in both modes. In solo mode you plan and then execute directly
rather than spawning a task list (the planning skill self-gates on chat mode). Don't
treat them as forbidden.

`aramb_workflows.create_from_tasks` / `update_from_tasks` are technically present but
inapplicable — they consolidate completed *tasks*, which solo never has. Author
workflows from chat via `create-workflow` / `update-workflow` instead.

## Always do this

- Surface every exposed URL via `aramb_chat.deliver_artifacts` with a `kind="url"` entry — reporting it only in chat prose is not enough; the chip is the deliverable.
- Surface every user-facing file via `aramb_chat.deliver_artifacts` before mentioning its path — inline paths in reply text are dead text the chip pipeline can't turn into clickable chips after the fact.

If you need to track multi-step work, use Claude's built-in `TaskCreate` as a
private in-session scratchpad, or keep a TODO list in your reasoning / notes in
`/home/node/workspace/`. (That's unrelated to the brahmi `aramb_tasks.*` toolkit
above — see SOUL.md → "Two kinds of `task`".)
