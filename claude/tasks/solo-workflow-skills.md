# Solo Workflow Skills — Phase 2 of Solo Mode

> Follow-up to the solo-mode work documented in
> [/Users/siva/workspace/claude/tasks/solo-mode.md](../../../claude/tasks/solo-mode.md).
> Phase 1 shipped solo as a code/build agent. This phase teaches solo to
> author and update workflows directly from a user prompt — bypassing the
> master/task path entirely.

## Prerequisites

- Phase 1 (solo skill, brahmi solo-mode routing, FE chat-settings wiring)
  is merged or in testing.
- Solo persona dir is present in agent containers
  (`/home/node/.benji/workspace-solo/`) with the 15-skill loadout.

## Goal

When a chat in solo mode receives a request like:
- "build a workflow that fetches today's emails, writes them to a sheet,
  emails me when done"
- "add a Slack DM step at the end of the existing workflow"
- "schedule the workflow to run weekdays at 9am"

solo authors / edits / schedules the workflow directly via
`brahmi.save_workflow`, `brahmi.update_workflow`, and
`brahmi.set_workflow_schedule` — no `consolidate_workflow`, no system task.

`schedule-workflow` is already in solo's loadout and works as-is (it's
schedule-only, not task-coupled). This phase only adds creation + update.

## Two new skills to write

```
aramb-skills/solo-create-workflow/SKILL.md
aramb-skills/solo-update-workflow/SKILL.md
```

Both adapted from the existing `create-workflow` / `update-workflow`
skills in the same repo. Same schema knowledge; different "where does
the spec come from" step.

### Strategy: copy schema-load-bearing sections verbatim, replace task-coupled ones

For **`solo-create-workflow`**, source map from `create-workflow/SKILL.md`:

| Section in create-workflow | Solo treatment |
|---|---|
| Frontmatter (`name`, `description`) | Rewrite — name `solo-create-workflow`, description "Author a new workflow directly from the user's prompt — for solo agent. NOT for: dispatching as a task." |
| Intro paragraph | Rewrite — "You are solo. The user described a workflow in chat. Your job is to design and save it." |
| MUST rules (1 closing instruction, 2 required_toolkits, 3 save_workflow once) | **Keep verbatim** (with rule 4 about `update_task` removed — solo never closes a task) |
| "You are running as a task assigned to master" paragraph | **Replace** with: "You're running as solo in a regular chat dispatch. There's no task_id. The workflow spec comes from the user's most recent message + this chat's history." |
| Progress reports section (update_task with `## Progress`) | **Replace** with: "Stream short progress updates via `brahmi.send_message chat_location='main'` at three checkpoints: 1) restating the workflow you're about to build, 2) when designing nodes, 3) just before save." |
| Step 1: Fetch completed tasks via `list_tasks` | **Replace** with: "Read the user's most recent message in chat — that's the workflow spec. If under-specified (no clear sequence, no clear trigger, no clear data flow), ask 1–2 specific clarifying questions via `brahmi.ask_question` BEFORE designing. Don't ask more than 2; pick sensible defaults for the rest and tell the user what you picked." |
| Step 2: Analyze tasks | **Replace** with: "Decompose the user's intent into ordered steps in your reasoning. For each step: what data flows in (from user / previous step), what the step produces, which agent identity should run it, which Composio toolkit slugs it touches." |
| Step 3: Design the workflow (the bullet list of design rules) | **Keep verbatim** — same schema rules apply. The only line to drop: "Source the slugs from the source tasks' `required_toolkits` field (primary)" — replace with "infer slugs from the action you're describing (Gmail action → `[\"GMAIL\"]`, Google Sheets → `[\"GOOGLESHEETS\"]`, etc.)." |
| Closing instruction per node | **Keep verbatim** — `update_my_workflow_step` is the same in both modes. |
| Default node settings (workflow-level) | **Keep verbatim** — same defaults block, same per-node override heuristics. |
| Step 4: Identify env variables | **Keep verbatim**. The "be stingy" guidance is identical. |
| Step 5: Save the workflow | **Mostly keep verbatim**. The pre-flight checklist's `source_task_id` line: drop "Required whenever this node consolidates from one user task" — replace with "Solo doesn't have source tasks; omit `source_task_id` for every node, OR pass `null`. Brahmi accepts both." |
| Step 6: Close your task | **Delete entirely**. Solo doesn't close a task. Replace with: "Confirm to the user via `brahmi.send_message`: \"Workflow created — `<name>` (`<workflow_id>`) — `<n>` steps. View it in the Workflows tab.\" If save_workflow returned an error, tell the user the concise reason and what they could change." |
| "Compound-schedule handoff" via task outputs | **Replace** with: "If the user's message *also* contained a scheduling phrase, immediately call `set_workflow_schedule` yourself after `save_workflow` succeeds — don't surface a hint, just do it. The `schedule-workflow` skill is already in your loadout if you need to consult cron-format guidance." |
| Rules section at the bottom | **Mostly keep verbatim**, drop bullets that reference `update_task`, task closing, or `task_id`. |

For **`solo-update-workflow`**, source map from `update-workflow/SKILL.md`:

Same translation rules as above, plus:
- "If you were NOT dispatched" branch: **delete** (solo is never dispatched as a task; always called from chat).
- Step 1 (Fetch existing definition via `get_workflow`): **keep verbatim** — works the same in solo.
- Step 2 (Fetch completed tasks via `list_tasks`): **delete entirely**. The change spec comes from the user's chat message, not from new tasks.
- Step 3 (Analyze the delta): **adapt**. The delta is the difference between the existing workflow definition and what the user just asked for in chat. Read both, compute the change, design the new full nodes/edges set.
- Step 4 (Call update_workflow): **keep verbatim** — same schema, same atomic-replace semantics.
- Step 5 (Tell the user about side effects + setting changes): **keep verbatim** — solo should still surface "this update demoted the workflow back to draft; re-publish to make it live again" via `send_message`.
- Step 6 (Close your task): **delete**.
- Schedule-shaped change request rejection: **keep** — if the user's update message is "make it run on Mondays", that's a schedule-workflow concern; solo should redirect.

### Both skills end up roughly 200–250 lines

That's smaller than the originals because all the task-bookkeeping verbiage drops out and the schema knowledge stays the same.

## Solo SOUL.md update

Edit `aramb-skills/solo/` companion file or solo's persona SOUL.md (whichever
is canonical for solo). Find this block:

```
## Workflows

- The Workflows tab stays visible in the user's chat. Existing workflows can be read and rescheduled via `brahmi.get_workflow` and `brahmi.set_workflow_schedule`.
- Creating new workflows from scratch in solo mode is not yet supported. If the user asks for one, tell them: "creating workflows in solo mode is coming — switch back to task mode for now (Settings → Disable task mode → off)."
```

Replace with:

```
## Workflows

You can author, update, and schedule workflows directly:

- **User asks to build a new workflow** → use the `solo-create-workflow` skill. Read its SKILL.md, gather/clarify the spec from the user's message, design nodes + edges, call `brahmi.save_workflow` once.
- **User asks to update / refresh / regenerate / tweak an existing workflow** → use the `solo-update-workflow` skill. Always look up the current definition with `brahmi.get_workflow` first; the chat is not the source of truth, the database is.
- **User asks to schedule / pause / change the cron of a workflow** → use the `schedule-workflow` skill. Strictly cron-only; never bundle schedule changes into save/update_workflow calls.

You do NOT call `consolidate_workflow` or `reconsolidate_workflow` — those exist for the task-mode (master) path and the MCP server will reject them in solo mode. The save/update/schedule workflow tools are not gated and work for you directly.
```

## Add to solo's skill loadout

The 15-skill list in the canonical solo-mode design doc grows to **17**:
add `solo-create-workflow` and `solo-update-workflow`.

Update these references:
- `claude/tasks/solo-mode.md` (workspace canonical) — bump count + add to the include table
- `aramb-skills/claude/tasks/solo-mode.md` (per-repo aramb-skills doc)
- `benji/claude/tasks/solo-mode.md` (per-repo benji doc — the
  agent-factory `solo` agent spec needs the two extra skills in its
  `required_skills` / `skills:` list)

## Container injection (for testing without the agent-factory rebuild)

Same pattern as Phase 1:

```bash
# 1. Stage the new skills locally
mkdir -p /tmp/solo-skills-update
cp -r /Users/siva/workspace/aramb-skills/solo-create-workflow /tmp/solo-skills-update/
cp -r /Users/siva/workspace/aramb-skills/solo-update-workflow /tmp/solo-skills-update/

# 2. Find the running agent container (current is aramb-agent-10f486b3)
CONTAINER=$(docker ps --filter name=aramb-agent --format '{{.Names}}' | head -1)

# 3. Copy into solo's persona dir
docker cp /tmp/solo-skills-update/solo-create-workflow "$CONTAINER:/home/node/.benji/workspace-solo/skills/solo-create-workflow"
docker cp /tmp/solo-skills-update/solo-update-workflow "$CONTAINER:/home/node/.benji/workspace-solo/skills/solo-update-workflow"
docker exec --user root "$CONTAINER" chown -R node:node /home/node/.benji/workspace-solo/skills/solo-create-workflow /home/node/.benji/workspace-solo/skills/solo-update-workflow

# 4. Update solo's SOUL.md in the container (the Workflows section)
docker exec "$CONTAINER" cat /home/node/.benji/workspace-solo/SOUL.md | head
# … replace the Workflows section per the spec above. Use docker cp to push the new SOUL.md.

# 5. Restart benji so the agent re-reads its workspace
docker restart "$CONTAINER"
sleep 5
docker logs "$CONTAINER" --since 30s 2>&1 | grep -E "agentCount|skills"
```

`agentCount` should remain unchanged (skills are workspace-scoped; the
agent count is still 10). What changes is solo's available skills list
when it boots up its system prompt.

## Verification

End-to-end test paths once the skills are in:

### Path E1: create from prompt

In a chat with `tasks_enabled=false`, send: "build a workflow that fetches
today's emails I received, writes them to a Google Sheet, and emails me
when done". Expect:
- Solo sends a clarifying-question or two if details are missing
  (calendar account, sheet name, recipient email)
- Solo calls `brahmi.save_workflow` exactly once
- Workflow appears in the Workflows tab with three nodes (Gmail fetch,
  Sheets append, Gmail notify)
- Each node has `required_toolkits` populated, closing instruction in
  prompt, `default_node_settings` populated on the workflow

Verify in DB:
```sql
SELECT id, name, default_node_settings FROM workflows ORDER BY created_at DESC LIMIT 1;
SELECT unique_id, name, required_toolkits, settings FROM workflow_nodes WHERE workflow_id = '<id>' ORDER BY unique_id;
```

### Path E2: update from prompt

In the same chat, send: "actually also post to #general in Slack at the end".
Expect:
- Solo calls `brahmi.get_workflow workflow_id="<existing>"` first
- Solo calls `brahmi.update_workflow` with the new edges + a new Slack node
- Workflow status drops to `draft` (per the existing update-workflow
  side-effect rule); solo tells the user "demoted to draft — re-publish
  to make it live"

### Path E3: schedule alongside create

In a fresh solo chat, send: "build a daily-pulse workflow that runs at
8am IST". Expect:
- Solo creates the workflow (save_workflow) AND immediately calls
  `brahmi.set_workflow_schedule cron_expression="0 8 * * *" cron_timezone="Asia/Kolkata" enabled=true`
- One confirmation message containing both the workflow id and the schedule

### Path E4: MCP rejection still works

Manually inject a `consolidate_workflow` MCP call from solo's session.
Brahmi MCP guard should reject with "You are not allowed to create tasks
in solo mode" — confirms the gating doesn't accidentally exempt
workflow-consolidation tools.

## Out of scope for this phase

- Plan-mode for workflow creation in solo. The master/task path uses
  `start_planning` / `submit_plan` / `finish_planning`; solo doesn't
  have those (gated). For solo, "ask 1–2 clarifying questions before
  designing" replaces the plan-mode dance. Add a richer plan-mode for
  solo only if user feedback shows the clarifying-question path doesn't
  scale.
- Refactoring the existing `create-workflow` / `update-workflow` skills
  into a shared schema reference. Possible long-term cleanup once both
  variants are battle-tested; not now.
- Workflow execution-side changes. The runtime (workflow_run_steps,
  per-step dispatch) is unchanged — solo authors workflows that the
  existing executor agents (developer / aramb-deployer / etc.) run
  exactly as today.

## PR / commit guidance

Same branch as Phase 1 in aramb-skills (`feat/solo-mode`). One commit
per skill keeps the diff readable:

1. `feat(solo): add solo-create-workflow skill (prompt-driven)`
2. `feat(solo): add solo-update-workflow skill (prompt-driven)`
3. `feat(solo): point SOUL.md workflow guidance at the new skills`

Reference the parent design doc and this Phase 2 doc in the PR body.
