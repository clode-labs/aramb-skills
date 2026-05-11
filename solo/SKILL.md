---
name: solo
description: >
  Tools and conventions for the solo (direct-execution) agent. Communication,
  git, preview URLs, and existing-workflow scheduling. No task creation, no
  sub-agent spawning.
---

# Solo skill

You are in solo mode. You execute work directly — no decomposition, no
sub-agents, no task tracking. Use these MCP tools via mcporter.

## mcporter syntax rules
- ALL arguments MUST use `key="value"` format (NOT positional args)
- Do NOT use `--output` flag — not supported by `mcporter call`

## Communication
- `npx mcporter call brahmi.send_message content="<markdown>" chat_location="main"` — text-only updates
- `npx mcporter call brahmi.ask_question question="<text>"`
- `npx mcporter call brahmi.alert_user message="<urgent text>"`

### Delivering files

For any user-facing file you produced under your working directory in this
turn (PDF, JSON, text file, image, anything), surface it via
`deliver_artifacts`. Brahmi composes the chat row with a clickable chip that
opens the file in VS Code. There is no "the user could just read it from my
reply text" exception — any file the agent wrote means `deliver_artifacts` is
required.

1. **Write the file under your working directory** — the absolute path
   is injected into your prompt under "MANDATORY Working Directory"
   (e.g. `/home/node/workspace/<slug>/`). NEVER write user-facing files
   inside your private skill workspace at
   `/home/node/.benji/workspace-solo/...`; those paths are private to
   you and the user can't reach them from the Files tab. Chips that
   reference them resolve to nothing.
2. **Call `deliver_artifacts`** with the file paths:
   ```
   npx mcporter call brahmi.deliver_artifacts \
     artifacts='[{"path":"report.pdf"}]' \
     content="<optional markdown blurb>"
   ```

Use the same call when the user later asks about something you produced
earlier in this chat ("show me that report") — pass the relevant
artifacts and brahmi posts a fresh row with the chips.

Rules for `artifacts`:
- The `path` is workspace-relative (just `report.pdf` or
  `subdir/report.pdf`, NOT `/home/node/workspace/<slug>/report.pdf`).
  The frontend re-prefixes when opening the chip in VS Code.
- Multiple entries are allowed; order is preserved — put the primary
  deliverable first.
- `artifacts` is required and non-empty. For chat-only updates with no
  file output, use `send_message` instead.

Do not pass `produced_files` to `send_message` — that path is deprecated
in favour of `deliver_artifacts`.

## Git
- `npx mcporter call brahmi.list_linked_repos`
- `npx mcporter call brahmi.clone_repo repo_url="<url>"`
- `npx mcporter call brahmi.git_token`

## Deployment

When you expose a service the user can reach in chat (local tunnel, deployed
app, public proxy URL), surface it through TWO MCP calls. `update_preview_url`
registers the URL with brahmi (state — powers the in-app iframe and app header
preview surface). `deliver_artifacts` with `kind: "url"` emits the clickable
tile on the chat row (chip render). The two backend entry points serve
different purposes; a URL deliverable needs both.

1. **Call `update_preview_url`** — state update. Use `environment="local"`
   for tunnel-style URLs you exposed from this agent's machine,
   `environment="deployed"` for URLs pointing at hosted infrastructure.
   ```
   npx mcporter call brahmi.update_preview_url url="<url>" environment="local"
   npx mcporter call brahmi.update_preview_url url="<url>" environment="deployed"
   ```
2. **Call `deliver_artifacts`** with a `kind: "url"` entry — chip emit. The
   `environment` field on the artifact must match what you passed to
   `update_preview_url`.
   ```
   npx mcporter call brahmi.deliver_artifacts \
     artifacts='[{"kind":"url","url":"<url>","title":"Preview URL","environment":"local"}]'
   ```

Rules for preview URLs:
- The rule fires whenever a deploy / expose step produced any URL the user can reach (frontend, API, tunnel, public proxy).
- BOTH `update_preview_url` AND `deliver_artifacts` (with `kind: "url"`) are mandatory for the primary frontend URL. Order: state update first, chip emit second.
- Mentioning the URL only in chat prose is forbidden. State update and chip emit are independent responsibilities; the URL needs both calls even if the URL also appears in the reply text.
- `environment` must match between the two calls (`local` for tunnels you ran from this container, `deployed` for hosted infra).
- The chip is for the *primary* frontend URL only. Secondary backend / API URLs can stay in the plain-text summary — one URL chip per chat row is plenty.

## Workflows

You can author, update, and schedule workflows directly. Two trigger paths
land at you as normal chat turns; recognise both:

- **User describes a workflow explicitly** (e.g. "build a workflow that fetches today's emails…")
  → use the `solo-create-workflow` skill. The spec is the message itself.

- **User says "create a workflow based on the work done so far in this chat"** (or similar — this is the canned message the FE sends when they click the "Create workflow" button on a grow / research workspace)
  → use the `solo-create-workflow` skill. The spec is THIS conversation: walk back through the work you did, the tool calls you made, the files you produced, and consolidate. Generalize — do not transcribe specific dates / values into the workflow.

- **User describes an explicit change** to an existing workflow (e.g. "add a Slack DM step", "remove the synth node")
  → use the `solo-update-workflow` skill. Always fetch the current definition first via `brahmi.get_workflow`; the chat is not the source of truth, the database is.

- **User says "update the existing workflow based on the work done in this chat"** (button-driven canned message)
  → use the `solo-update-workflow` skill. Compute the delta between the existing definition and the new work in this session, then write the full replacement.

- **User asks to schedule / pause / change the cron of a workflow**
  → use the `schedule-workflow` skill. Strictly cron-only; never bundle schedule changes into save/update_workflow calls.

Common direct calls (the skills above wrap these):
- `npx mcporter call brahmi.get_workflow workflow_id="<id>"`
- `npx mcporter call brahmi.save_workflow application_id="<id>" project_id="<id>" name="<name>" ...` (see `solo-create-workflow`)
- `npx mcporter call brahmi.update_workflow workflow_id="<id>" nodes='[...]' ...` (see `solo-update-workflow`)
- `npx mcporter call brahmi.set_workflow_schedule workflow_id="<id>" cron_expression="<5-field>" cron_timezone="<tz>" enabled=true`
- `npx mcporter call brahmi.set_workflow_schedule workflow_id="<id>" enabled=false`

You do NOT call `consolidate_workflow` or `reconsolidate_workflow` — those
exist for the task-mode (master) path and the MCP server will reject them
in solo mode. The save / update / get / set_workflow_schedule tools are
not gated and work for you directly.

## Forbidden in solo mode

The MCP server will reject these calls with an explicit error message
("You are not allowed to create tasks in solo mode — continue on your
own"). When you see that error, do NOT retry; continue your work
directly.

Forbidden tools:
- `create_tasks`, `update_task`, `update_my_task`, `get_my_tasks`, `list_tasks`
- `start_planning`, `submit_plan`, `finish_planning`
- `consolidate_workflow`, `reconsolidate_workflow`

Also forbidden:
- Reporting an exposed URL only in chat prose, OR calling only one of `update_preview_url` / `deliver_artifacts` (instead of both), is forbidden. State update and chip emit are independent responsibilities; the URL needs both.
- Mentioning a workspace file path in your reply text without first calling `deliver_artifacts` is forbidden. Inline paths are dead text — the chip pipeline cannot turn them into clickable chips after the fact.

If you need to track multi-step work in your head, keep a TODO list in
your reasoning or notes in `/home/node/workspace/`. Do not call the task
MCP tools.
