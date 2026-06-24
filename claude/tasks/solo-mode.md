# Solo Mode — Aramb Skills

> Per-repo plan split from
> [/Users/siva/workspace/claude/tasks/solo-mode.md](../../../claude/tasks/solo-mode.md).
> Read that for full context, design, and rationale.
>
> **Phase 2** (workflow skills) is a separate plan in
> [solo-workflow-skills.md](./solo-workflow-skills.md) — adds
> `solo-create-workflow` and `solo-update-workflow` skills and the
> SOUL.md routing block to use them.

## Prerequisites

- No dependency on other repos. This PR ships first because the
  agent-factory PR consumes the new skill.

## Summary

Add one new skill: `solo`. It enumerates the MCP tools that solo (the
direct-execution agent) is allowed to call. It replaces the role that
`brahmi/SKILL.md` plays for master, but with the task-related tool surface
removed and the educational rejection contract documented.

Nothing else in this repo changes — existing skills are reused as-is.

## Files to add

```
aramb-skills/solo/SKILL.md
```

(Optionally also `solo/README.md` if other skills carry one — check
neighbours and match.)

## SKILL.md content shape

```markdown
---
name: solo
description: Tools and conventions for the solo (direct-execution) agent.
  Communication, git, preview URLs. No task creation, no sub-agent spawning.
---

# Solo skill

You are in solo mode. You execute work directly — no decomposition, no
sub-agents, no task tracking. Use these MCP tools via mcporter.

## Communication
- npx mcporter call brahmi.send_message message="<text>" chat_location="main"
- npx mcporter call brahmi.ask_question question="<text>"
- npx mcporter call brahmi.alert_user message="<urgent text>"

## Git
- npx mcporter call aramb_toolkits.check_connection toolkit="GITHUB"
- npx mcporter call aramb_toolkits.connect_toolkit toolkit="github"   # when check_connection.connected=false; share returned redirect_url
- npx mcporter call aramb_toolkits.get_github_credential               # then export GH_TOKEN and use native git/gh CLI

## Deployment
- npx mcporter call brahmi.update_preview_url url="<url>" environment="local"|"deployed"

## Workflows (existing only — creation deferred)
You can read and schedule existing workflows:
- npx mcporter call brahmi.get_workflow workflow_id="<id>"
- npx mcporter call brahmi.set_workflow_schedule workflow_id="<id>" cron_expression="<5-field>" cron_timezone="<tz>" enabled=true|false
You cannot create new workflows in solo mode (deferred to a future phase
where solo authors workflows directly from prompts).

## Forbidden in solo mode
The MCP server will reject these calls with an explicit error message
("You are not allowed to create tasks in solo mode — continue on your
own"). When you see that error, do NOT retry; continue your work
directly.

Forbidden tools:
- create_tasks, update_task, update_my_task, get_my_tasks, list_tasks
- start_planning, submit_plan, finish_planning
- consolidate_workflow, reconsolidate_workflow

If you need to track multi-step work in your head, keep a TODO list in
your reasoning or notes in /home/node/workspace/. Do not call the task
MCP tools.
```

Match the frontmatter style of an existing simple skill (e.g.
`aramb-skills/dev-workflow/SKILL.md`) — `name`, `description`, then body.

## Verification

```bash
cd /Users/siva/workspace/aramb-skills
ls solo/SKILL.md                                    # file exists
head -20 solo/SKILL.md                              # frontmatter sane
grep -E "^- npx mcporter" solo/SKILL.md | wc -l     # all tool calls listed
```

No build / test step in this repo.

## Out of scope

- Editing any existing skill (master's `brahmi/SKILL.md` etc. stays put;
  master mode keeps using it).
- A `create-workflow-direct` skill for prompt-based workflow creation —
  that's a future phase.
- Adding `frontend-development` / `backend-development` / `*-planner` /
  `*-critique` / `skill-creator` to solo. They aren't in any current
  baked persona; don't introduce drift.

## PR template

Title: `feat(solo): add solo skill for direct-execution agent`

Body should reference `/Users/siva/workspace/claude/tasks/solo-mode.md`.
