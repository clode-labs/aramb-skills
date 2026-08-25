# aramb-skills — Workflow Reliability Batch 2

**Workspace doc:** `/Users/siva/workspace/claude/tasks/2026-06-23/workflow-reliability-batch2.md` (read first)
**Branch:** `feat/workflow-reliability-batch1` (EXTEND it — has your Batch 1 skill edits)

Prompt/skill changes only. Two items: #9 (pre-build clarifying questions) and the #6 prompt half
(stop fabricating run status).

---

## #9 — Pre-build clarifying-questions checklist

**Why.** In the incident the agent built the whole workflow with zero questions: it assumed a Proceed
threshold (65; the user later corrected to 80), never checked that Google Sheets or GitHub were
connected (both later caused failures), and never warned that 382 candidates (222 backend) is a long,
costly job. It built first and leaked the gaps as contradictory status.

**Edit — the workflow-authoring skill(s)** (`create-workflow/SKILL.md` and/or `aramb-workflows/SKILL.md`,
wherever the "author a new workflow" flow lives). Add a short **pre-build checklist**: before
constructing nodes, the agent should confirm the few things that materially change the build, in **one
concise round of 2–4 questions** (do NOT over-ask or interrogate):
- **Scoring/decision params** that are not clearly specified (e.g. threshold, rubric weights).
- **Toolkit connectivity** for every external system the workflow will touch (Sheets, GitHub, etc.) —
  verify connected, and if not, tell the user what to connect rather than discovering it mid-run.
- **Scale/cost heads-up** — if the input set is large (e.g. hundreds of items), state the rough
  scale/time and offer a small pilot first.
- **Source accessibility** — confirm the links/sources are publicly reachable vs need auth.

Frame it as "confirm-then-build," not "build-then-apologize." Keep it consistent with the skill's
existing voice; this is guidance, not a rigid script.

---

## #6 (prompt half) — Stop fabricating run status

**Why.** The agent narrated optimistic fiction ("4/382 scored, nodes working through the rest in
parallel batches") while runs were actually failing, because it had no real view of run state.

**Context:** brahmi (Batch 2) now posts **real** run progress + success/failure notes to the
conversation automatically. So the agent does not need to — and must not — invent status.

**Edit — the workflow run/monitoring guidance** (the skill text that tells the agent what to say after
kicking off a run; likely in `aramb-workflows/SKILL.md` near the `run` flow, and/or
`create-workflow/SKILL.md` closing message):
- After triggering a run, the agent should **hand off to the run and let the system report** progress
  and the final result — it should NOT claim per-batch counts or "working through the rest" that it
  cannot verify.
- When the user asks "what's the status?", the agent should report only **verifiable** state (e.g. via
  `aramb_mcp.workflows_get` / `list`, or acknowledge the run is in progress and the system will post
  updates) — never fabricated progress numbers.
- Remove/repair any existing template lines that encourage made-up progress narration.

---

## Out of scope (do NOT do)
- Browser/curl policy (shipped in Batch 1). Any brahmi-side surfacing (that is brahmi's #6).

## Done =
Skill edits committed on `feat/workflow-reliability-batch1`. Write
`claude/tasks/2026-06-23/IMPL-COMPLETE-BATCH2.md` summarizing the edits, then stop.
