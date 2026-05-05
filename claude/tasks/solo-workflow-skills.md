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

Solo authors / edits / schedules workflows directly via
`brahmi.save_workflow`, `brahmi.update_workflow`, and
`brahmi.set_workflow_schedule` — no `consolidate_workflow`, no system task.

`schedule-workflow` is already in solo's loadout and works as-is (it's
schedule-only, not task-coupled). This phase only adds creation + update.

### Two trigger paths converge on the same skills

Solo's create/update workflow skills must handle **both** trigger modes
that exist in the product today:

| Trigger | Spec source for the workflow |
|---|---|
| **Conversational** — user types "build a workflow that fetches today's emails, writes them to a sheet, emails me when done" | The user's prompt content. Explicit. |
| **Button** — user clicks "Create workflow" / "Update workflow" in the Workflows tab (visible on grow / research workspaces). FE redirects to a canned chat message: e.g. *"Create a workflow based on the work done so far in this chat"* / *"Update the existing workflow based on the work done in this chat"* | The session itself: solo's prior tool calls, files written, ordered actions taken in this conversation. **Symmetric to how master's `create-workflow` consolidates from completed tasks today** — but the evidence is conversation history, not task records. |

Both paths land as a normal chat turn at solo. The agent infers which
mode applies from the message content (explicit description vs.
"based on work done"). The skills cover both.

### FE button redirect (in scope)

The "Create workflow" / "Update workflow" buttons on grow / research
workspaces today dispatch `brahmi.consolidate_workflow` /
`brahmi.reconsolidate_workflow` — task-coupled MCP calls that solo
mode rejects. In solo mode, the buttons must instead **send a chat
message** through the normal send-message endpoint with canned text:

- "Create workflow" → `Create a workflow based on the work done so far in this chat.`
- "Update workflow" → `Update the existing workflow based on the work done in this chat.`

That message routes through brahmi → solo → the new skill → save_workflow.
Branch on `chatSettings.tasks_enabled`:
- `true` → existing flow (consolidate_workflow MCP).
- `false` → send canned chat message instead.

This is a small FE change in `web-app-v2`. Captured separately at the
end of this doc and in `web-app-v2/claude/tasks/solo-mode.md` so the
FE session can pick it up alongside the chat-settings work.

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
| Frontmatter (`name`, `description`) | Rewrite — name `solo-create-workflow`, description "Author a new workflow — for solo agent. Triggered either by an explicit user request or by 'create a workflow based on the work done so far' (button-driven). NOT for: dispatching as a task." |
| Intro paragraph | Rewrite — "You are solo. The user wants you to author a new workflow. The spec comes from one of two sources: an explicit description in their message, or the work you've already done in this conversation. Identify which, then design and save." |
| MUST rules (1 closing instruction, 2 required_toolkits, 3 save_workflow once) | **Keep verbatim** (with rule 4 about `update_task` removed — solo never closes a task) |
| "You are running as a task assigned to master" paragraph | **Replace** with: "You're running as solo in a regular chat dispatch. There's no task_id. The workflow spec comes from one of: (a) the user's explicit description in their most recent message, (b) the work already done in this chat (their message will be a canned 'create a workflow based on the work done so far' / similar phrasing — that's the consolidate-from-history signal)." |
| Progress reports section (update_task with `## Progress`) | **Replace** with: "Stream short progress updates via `brahmi.send_message chat_location='main'` at three checkpoints: 1) restating the workflow you're about to build (and which evidence source you're using), 2) when designing nodes, 3) just before save." |
| Step 1: Fetch completed tasks via `list_tasks` | **Replace** with: <br/>**Step 1 (solo): Identify spec source, then gather it.**<br/><br/>First, classify the user's message: <br/>- *Explicit description* (e.g. "build a workflow that fetches today's emails…"): the spec **is** the message. Don't analyze conversation history. <br/>- *History-derived* (e.g. "create a workflow based on the work done so far", "based on what we just did, build a workflow", or any phrasing that points at the conversation as the evidence): consolidate from your own session. Identify the ordered steps you took, the tool calls made, the files written, the toolkits touched. This is the same role master's `create-workflow` plays today — but the evidence is your conversation history, not completed tasks.<br/><br/>For history-derived intent, walk back through the conversation and produce, in your reasoning: <br/>(a) ordered list of meaningful steps the user/you took, <br/>(b) the explicit and implicit data hand-offs between them, <br/>(c) the Composio toolkit slugs you actually called (Gmail, Sheets, Slack, etc. — be honest, infer from real tool calls), <br/>(d) any constants or specific values that should NOT be re-parameterized (the recipe baked-in vs. the env-vars you genuinely need). <br/><br/>**Generalize, don't transcribe.** A workflow is a *learned recipe* that should run again. If you fetched yesterday's emails for the user as a one-off, the workflow node should be "fetch the most recent day's emails", not "fetch emails dated 2026-05-04". Same for sheet ranges, time windows, etc.<br/><br/>If under-specified (either path), ask 1–2 targeted clarifying questions via `brahmi.ask_question` BEFORE designing. Don't ask more than 2; pick sensible defaults for the rest and tell the user what you picked. |
| Step 2: Analyze tasks | **Replace** with: "Decompose the spec into ordered steps in your reasoning. For each step: what data flows in (from user / previous step), what the step produces, which agent identity should run it, which Composio toolkit slugs it touches. For history-derived intent, this is the merge / generalize / split pass — combine adjacent same-agent calls into one node where it makes the workflow cleaner; split steps that mixed responsibilities." |
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
- Step 2 (Fetch completed tasks via `list_tasks`): **replace with dual-mode spec source**, mirroring the create skill:
  - *Explicit change* in the user's message ("add a Slack DM step", "remove the email triage", "change the synth step to also include the calendar"): use that as the change spec verbatim, same as today's `update-workflow`.
  - *History-derived change* (canned button message: "update the existing workflow based on the work done in this chat"): treat your conversation since the existing workflow was last saved as the evidence. Identify what new work happened, what was tried-and-discarded, which steps gained new logic, then design the delta.
- Step 3 (Analyze the delta): **adapt**. The delta is the difference between the existing workflow definition and either (a) the user's explicit change spec, or (b) the new work done in this conversation. Read both, compute the change, design the new full nodes/edges set. **Lean on the existing definition** — carry forward node prompts and assignments unless they need to change.
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

You can author, update, and schedule workflows directly. Two trigger
paths land at you as normal chat turns; recognise both:

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

You do NOT call `consolidate_workflow` or `reconsolidate_workflow` — those
exist for the task-mode (master) path and the MCP server will reject them
in solo mode. The save / update / get / set_workflow_schedule tools are
not gated and work for you directly.
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

### Path E5: button-driven create from history

In a solo-mode chat on a grow / research workspace, do some real work
first (e.g. "fetch my last 5 emails and write them to a sheet" — solo
runs the actions). Then click **Create workflow** in the Workflows tab.
The FE should send `Create a workflow based on the work done so far in
this chat.` as a chat message. Expect:
- Solo recognises the canned phrase, classifies as history-derived intent
- Solo walks its conversation: identifies the email-fetch + sheet-write
  steps, the toolkits used, the data flow
- Solo calls `brahmi.save_workflow` once with generalised node prompts
  (no "today's date" hardcoding)
- Confirmation message + workflow visible in the Workflows tab

### Path E6: button-driven update from history

In a solo-mode chat that has an existing workflow + new work done after
the workflow was last saved, click **Update workflow**. FE sends `Update
the existing workflow based on the work done in this chat.`. Expect:
- Solo calls `brahmi.get_workflow` first
- Solo computes delta between the existing definition and the new work
  done since
- Solo calls `brahmi.update_workflow` once with the merged node/edge set
- Confirmation message including the "demoted to draft — re-publish" note

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
