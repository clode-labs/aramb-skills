# aramb-skills ADDENDUM — run an existing workflow on request (confirm-first)

Same branch `feat/trigger-jitter-and-callbacks`. Document the new `aramb_workflows.run` MCP tool and
the flow for "run X workflow" requests. **Policy (locked): ALWAYS confirm before running** — even on
an exact name match.

## Where
Add a new section **"## Running an existing workflow (manual run)"** to
`aramb-workflows/SKILL.md` (the always-loaded MCP reference skill). Keep the terse, example-first
voice. Also add a one-line entry for `aramb_workflows.run` to that skill's tool list / the list-row
and get sections where the other `aramb_workflows.*` tools are enumerated.

## The flow to document
Trigger phrases: "run X", "run the X workflow", "execute X", "kick off X", "trigger X now", "start X".

1. **List + match.** Call `aramb_workflows.list project_id=<from User Message>` → `{workflow_id,
   name, status, schedule}`. Fuzzy-match the user's phrase to a workflow name (the model does this —
   partial/typo/synonym is fine). 
2. **ALWAYS confirm before running.** State the matched workflow's exact `name` (+ note its `status`,
   and `application_id` if app-bound) and ask the user to confirm, e.g. *"About to run **Daily Digest**
   (id …). Confirm?"* 
   - If MULTIPLE plausible matches: list them and ask which one.
   - If NONE match: say so, offer to list what exists. Never invent a `workflow_id`.
   - If the matched workflow's `status` is not runnable (e.g. draft/review/paused), surface that in
     the confirmation so the user knows.
3. **Run only after explicit confirmation.** Call:
   ```
   npx mcporter call aramb_workflows.run \
     workflow_id="<id>" \
     [custom_instruction="<any extra per-run context the user gave>"]
   ```
   `custom_instruction` is optional free-form text passed into the workflow's first step
   (`<run_input>`) — include it only if the user supplied extra instructions for this run.
4. **Report.** Echo the returned `run_id` and that the run started; mention how to check status if
   relevant.

## Guardrails to state in the skill
- Never call `aramb_workflows.run` without an explicit user confirmation of the specific workflow.
- Never guess a `workflow_id` — always resolve via `aramb_workflows.list` first.
- One run per confirmation; don't batch-run multiple workflows off one "run X" unless asked.

## Optional (consistency)
If the repo carries `workspace-solo/AGENTS.md` / `workspace-master/AGENTS.md` tool inventories, add a
one-line bullet: "Run an existing workflow on request (confirm-first): `aramb_workflows.run` (via the
aramb-workflows run flow)."

No build step (markdown). Append a "## Run-flow addendum" note to
`claude/tasks/2026-06-21/IMPL-COMPLETE.md`. Do NOT push / PR.
