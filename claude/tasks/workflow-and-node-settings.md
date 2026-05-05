# Workflow & Node Settings — aramb-skills Implementation

**Workspace design doc:** `/Users/siva/workspace/claude/tasks/workflow-and-node-settings.md`
(read first for taxonomy, decisions, validation matrix)

This doc covers only **aramb-skills** changes. Backend lives in
`brahmi/claude/tasks/workflow-and-node-settings.md`. UI lives in
`web-app-v2/claude/tasks/workflow-and-node-settings.md`.

---

## Scope

Skill changes are **secondary** and **not blocking**. The brahmi + FE work
ships independently; skills only need updates so generated workflows look
"complete" with sensible defaults out of the box.

The two skills that emit workflow definitions:

- `create-workflow/SKILL.md` — used when master consolidates a fresh
  workflow from chat history.
- `update-workflow/SKILL.md` — used when master updates an existing
  workflow per a user instruction.

Both currently emit nodes via `brahmi.consolidate_workflow` /
`brahmi.update_workflow` MCP tool calls. The MCP tool shapes accept
`DefinitionNode` (Go side) — see brahmi doc Phase A for the new shape that
includes `settings`.

---

## Changes per skill

### workspace-master/AGENTS.md — schedule routing block (NEW)

Master today has a **"Workflow create + update routing"** section that
catches `create / update / regenerate` intents and dispatches to the
respective skill rather than designing inline. There is **no analogous
block for scheduling**, even though the `schedule-workflow` skill and the
`set_workflow_schedule` / `get_workflow_schedule` MCP tools already exist.

Result: when a user says *"schedule this to run weekdays at 9am"*, master
either tries to invent a cron inline or just acknowledges and forgets.

Add a section parallel to the create+update routing block:

```markdown
### Workflow scheduling routing

When the user asks to **schedule**, **un-schedule**, **pause**, or
**re-time** a workflow run, do NOT design the cron expression yourself
and do NOT enter planning. The `schedule-workflow` skill handles this:
it translates natural-language phrases into cron + timezone and calls
`set_workflow_schedule`.

Decision tree:

1. **Always look up the workflow first** (same rule as create+update —
   the chat is not source of truth):
   `npx mcporter call brahmi.get_workflow application_id="<APP_ID>"`
2. Load and run the `schedule-workflow` skill with the user's exact
   phrase. Do not paraphrase the time expression.
3. After the skill returns, send a one-line confirmation via
   `brahmi.send_message` showing the resulting cron + timezone +
   next_run_at.

Intent triggers to watch for:
- "schedule it", "run it daily/weekly/every Monday/at 9am"
- "pause the schedule", "stop running it on a schedule"
- "what's the schedule", "when does this run next"
- "change the schedule to ..."

If the user combines a scheduling intent with a create/update intent
("create a daily standup workflow that runs at 9am every weekday"), do
the create/update FIRST, then the schedule, in that order. The
workflow_id from the create response is what the schedule call needs.
```

### create-workflow/SKILL.md

When generating the workflow:

- Always set `default_node_settings` with sensible defaults rather than
  leaving the JSONB empty:
  ```yaml
  default_node_settings:
    model: claude-sonnet-4-6
    effort: medium
    thinking: adaptive
    max_turns: 35
    admin: false
    budget_usd: 25.0
    approval_mode: auto
    instructions: ""        # may be filled from chat history if user
                            # expressed cross-workflow style ("respond
                            # in IST", "use markdown")
  ```
- Per-node `settings` typically left empty (`{}`) unless the user
  explicitly asked for per-step variation. If a node clearly does
  something dangerous (e.g. "post to Linear", "delete files"), the skill
  should set `settings.approval_mode = 'manual'` for that node.
- Per-node attachments only if the user explicitly mentioned files in
  chat. The skill should never invent attachments.
- **Compound scheduling intent**: if the user's create message also
  contains a schedule phrase ("a daily standup workflow that runs at 9am"),
  the create-workflow skill itself does NOT set the schedule — it
  produces the workflow only. The skill must end with a note in its
  output telling master *"User also mentioned a schedule: 'daily at 9am'.
  Run the schedule-workflow skill next with workflow_id=<id>."* Master
  then dispatches the schedule skill as a follow-up. Keeps responsibility
  separation clean.

### update-workflow/SKILL.md

When the user says e.g. "switch the synth step to Opus" or "increase the
budget to $50":

- Recognize the intent and apply the change at the right level:
  - "all steps should use Opus" → workflow `default_node_settings.model`
  - "the synth step should use Opus" → that one node's
    `settings.model = 'claude-opus-4-6'` (override)
  - "give it a $50 budget" → workflow `default_node_settings.budget_usd`
    (no node-level edit)
  - "this step shouldn't auto-approve" → that one node's
    `settings.approval_mode = 'manual'`

The skill text should call out the **inheritance model** to the user when
relevant — e.g. "Set the workflow default to Opus and cleared the node
override on the synth step so it inherits."

**Schedule-shaped change requests** ("change the schedule to weekly", "stop
the cron", "move it to UTC") should be **rejected** by update-workflow with
a note telling master to dispatch the `schedule-workflow` skill instead.
update-workflow only handles definition / settings changes; cron belongs to
schedule-workflow.

---

## Phase order (skills)

1. **Master AGENTS.md scheduling routing** — independent of brahmi schema
   work; can ship today. The infrastructure is already in place
   (`set_workflow_schedule` + `schedule-workflow` skill).
2. Wait for brahmi Phase A schema lockdown — confirm exact JSON shape of
   `default_node_settings` and `NodeSettings`.
3. Update `create-workflow/SKILL.md` — defaults block + manual-approval
   heuristic + compound-schedule handoff note.
4. Update `update-workflow/SKILL.md` — intent recognition for setting
   changes; inheritance-aware language; schedule-intent rejection.
5. Sync to container during local-testing (`docker exec` cp from host).
6. Smoke tests:
   - "Schedule this to run daily at 9am IST" — master should dispatch
     `schedule-workflow` skill, NOT design inline. Verify `cron_expression`
     written, `cron_timezone='Asia/Kolkata'`.
   - "Build a weekly digest workflow that runs Monday at 8am" — master
     dispatches create-workflow first (workflow created), then
     schedule-workflow (cron set). Two skill calls in sequence.
   - "Switch the model to Opus" — update-workflow handles, sets
     `default_node_settings.model='claude-opus-4-6'`.
   - "Stop the schedule" — schedule-workflow handles with `enabled=false`.

These are pure markdown edits — no DB or code changes. Low risk.

---

## Out of scope here

- Skill changes for **honoring** these settings inside the agent
  (instructions, attachments). That belongs in each skill's task-execution
  section but is more naturally driven by the `instructions` and
  `## Attachments` sections that brahmi adds to the dispatched prompt at
  runtime — the agent doesn't need to be told via skill, the prompt
  itself carries the context.
- The `brahmi/SKILL.md` currently teaches step-agents about
  `update_my_workflow_step` (the F17 fix). It does NOT need updates for
  this milestone.
