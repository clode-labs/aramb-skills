# IMPL-COMPLETE — Batch 2 Redesign #4c (skill half, aramb-skills)

**Date:** 2026-06-24
**Branch:** `feat/workflow-reliability-batch1`
**Scope:** #4c **skill half only**. #4a (brahmi trigger) NOT touched — it is
DEFERRED in the design doc and out of scope for this session. #4b (benji),
#4d (brahmi sql), #4e (web-app-v2) are other repos, untouched here.
**Design doc:** `/Users/siva/workspace/claude/tasks/2026-06-23/workflow-reliability-batch2-redesign.md`

## What changed

### create-workflow/SKILL.md — new section "Durable-output nodes — foreground + append-only"

The workflow-authoring skill is where node prompts are composed; it already bakes
verbatim boilerplate into prompts at authoring time (the git-ops routing block is
the model). Added a parallel section, in the same voice and structure
(*When to emit / Why it matters / Append this block verbatim / when NOT to emit*),
that authors append to any node that builds a durable output file/sheet over a
long, potentially-resumed run (scoring submissions into `results.csv`, walking a
candidate sheet, batch-evaluating repos).

The baked-in block instructs the executing agent to:

1. **Foreground only** — run the core loop inline, turn by turn; never background
   it (`script &`, `nohup`, any `&`, detached `run.sh`). A backgrounded loop
   survives session close and a later session spawns a second loop that races it.
2. **Append-only** — treat the output file as a strictly append-only ledger;
   append each row as produced; never truncate, recreate, overwrite, reorder, or
   in-place dedup/rewrite; write the header once only if the file doesn't exist.
3. **On resume, re-read then append** — if the file already exists, read it first,
   treat existing rows as DONE, append only the missing rows, skip done ones, and
   never re-run prior work or relaunch any script/background process a previous
   attempt started.

The "when NOT to emit" guard keeps the block off single-pass small-output nodes
(send a message, one summary file) so it doesn't add noise where output doesn't
accumulate.

## Why this skill (and not aramb-workflows)

The task scoped to "the scoring/workflow-authoring skill guidance." `create-workflow`
**is** the workflow-authoring skill, and its node-prompt boilerplate is the actual
mechanism by which the executing agent's runtime behavior is set — mirroring the
brahmi #4c `workflow_step_executor` system-prompt hardening. Editing here changes
what every future durable-output node prompt tells the runtime agent to do.
Kept additive and consistent with the skill's existing voice; no other skill files
modified.

## Commits (local only — NOT pushed)

- `f2526b4` docs(create-workflow): #4c bake foreground + append-only block into durable-output node prompts

## Mapping to design doc #4c bullets

| #4c bullet | Covered by |
|---|---|
| works in the **foreground** — never backgrounds the core task (`run2.sh &`) | block item 1 |
| durable output **strictly append-only** — no truncate/recreate/in-place dedup-rewrite | block item 2 |
| on resume, never re-run/restart prior scripts/background processes — only append new work | block item 3 |

## Not done (out of scope / other repos)

- #4a trigger rethink (brahmi) — DEFERRED per design doc.
- #4c brahmi half (`system_prompts` migration) — brahmi repo.
- #4b reaping (benji), #4d `started_at` (brahmi sql), #4e timeline (web-app-v2).
