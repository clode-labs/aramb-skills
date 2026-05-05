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
- `npx mcporter call brahmi.send_message message="<text>" chat_location="main"`
- `npx mcporter call brahmi.ask_question question="<text>"`
- `npx mcporter call brahmi.alert_user message="<urgent text>"`

## Git
- `npx mcporter call brahmi.list_linked_repos`
- `npx mcporter call brahmi.clone_repo repo_url="<url>"`
- `npx mcporter call brahmi.git_token`

## Deployment
- `npx mcporter call brahmi.update_preview_url url="<url>" environment="local"`
- `npx mcporter call brahmi.update_preview_url url="<url>" environment="deployed"`

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

If you need to track multi-step work in your head, keep a TODO list in
your reasoning or notes in `/home/node/workspace/`. Do not call the task
MCP tools.
