# aramb-skills — UAT issues (maker-checker testing, 2026-05-27)

Per-repo slice of the workspace catalog `/Users/siva/workspace/claude/tasks/uat-issues-2026-05-27.md`.
Skills-side issues only. Branch: `feat/maker-checker`. Severity: P2 = wrong but bounded.

---

### #7 — Skills reference non-existent `brahmi.*` MCP tools (skills side)  [P2, OPEN]
**Issue:** the MCP namespace is `aramb_tasks` / `aramb_workflows` / `aramb_chat`. Some skill text still
instructs agents to call `brahmi.*` (e.g. `brahmi.update_my_task`), which doesn't exist — the agent gets a
"server doesn't exist" error, sometimes then falsely claims success.
**RCA:** prompt/skill drift left over from the brahmi→aramb MCP rename.
**Fix:** grep skill files in this repo for `brahmi.` and replace any MCP-tool reference with the `aramb_*`
namespace. Command: `grep -rn "brahmi\." .` (review each — keep prose mentions of "Brahmi" the service,
fix only tool-call references like `brahmi.update_my_task`, `brahmi.send_message`, etc.).
**Files:** skill `SKILL.md` files referencing MCP tool calls.
**Verify:** grep returns no `brahmi.<tool>` MCP references; an agent following the skill closes a task via
`aramb_tasks.update_me`.

### Checker-prompt skill — align with the simplified gatekeeper  [P2, follow-up to brahmi #16]
**Context:** the sidecar revision kept the `checker-prompt` SKILL (it deleted only the dedicated
`workspace-checker` persona). The gatekeeper behavior now lives in brahmi's `checker_executor`
system_prompts row (migration 0099), which is being simplified to a 2-part form (universal failure-mode
audit + artifact-vs-action routing) — see brahmi doc #16.
**Action:** ensure the `checker-prompt` skill is consistent with the simplified `checker_executor` and the
**explicit-id verdict report** (the checker reports via `aramb_tasks.update task_id="…"` /
`aramb_workflows.update_step step_id="…"`, NOT `update_me`). Remove any stale guidance that contradicts the
new gatekeeper prompt or tells the checker to use session-scoped `update_me`.
**Files:** the `checker-prompt` skill `SKILL.md`.

---

## Cross-repo context
- persona-side of the same `brahmi.*` drift + deployer/maker behavior:
  `benji-state/claude/tasks/uat-issues-benji-state.md` (#7, #8, #12).
- gatekeeper prompt + simplification: `brahmi/claude/tasks/uat-issues-brahmi.md` (#16) and
  `brahmi/claude/tasks/maker-checker-sidecar-revision.md`.
