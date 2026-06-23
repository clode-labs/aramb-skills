# IMPL-COMPLETE — Workflow Reliability Batch 1 (aramb-skills)

**Branch:** `feat/workflow-reliability-batch1`
**Scope:** prompt/skill edits only — #1 (browser-vs-curl tool policy) and the #5
doc-alignment. No code. Batch 2 items (clarifying-questions checklist, progress/
failure surfacing) intentionally NOT touched.

Refs: `claude/tasks/2026-06-23/workflow-reliability-batch1.md` and the workspace
design doc `/Users/siva/workspace/claude/tasks/2026-06-23/workflow-reliability-batch1.md`.

---

## Edits

### #1 — `aramb-browser/SKILL.md` (commit `e4750d3`)
- **Added an early, prominent `## Fetch hierarchy — reach for the browser LAST`
  section** (first `##` after the tool-call header). Establishes:
  - Default to non-browser fetch for public/static content — **public GitHub repos
    & raw files** (`git clone --depth 1` / `curl -sL raw.githubusercontent.com/…`),
    public Notion/Docs/Drive, plain HTML, JSON/API responses → `curl` / `git clone`
    / `WebFetch` from Bash.
  - Browser is **ONLY** for JS-rendered, authenticated, or visually-inspected
    content: Figma, Rive, interactive web apps, canvas, dashboards behind auth.
  - **Public repos need NO auth, NO GitHub toolkit, NO OAuth.**
  - **Toolkit-unconnected fallback is the unauthenticated curl path, never the
    browser.**
  - **Never drive the browser to fetch a file you could `curl`** (incl. the
    discovered-unmetered-raw-URL anti-pattern).
- **Scoped the two pre-existing absolutist rules** so they no longer contradict the
  hierarchy (and without deleting legitimate browser docs):
  - `## Use this for every web touch — no exceptions` → `## Use this for every
    (rendered / restricted) web touch — no exceptions`; the "Forbidden curl" wording
    now applies to restricted/JS-rendered/gated sites, with a cross-reference to the
    Fetch hierarchy for the public/static case. Reddit/X/LinkedIn `.json` and
    search-engine browser examples retained.
  - `## Rules (no exceptions)` first bullet now distinguishes
    rendered/restricted/auth/visual (→ this skill) from public/static (→ curl/clone/
    WebFetch).

### #1 — `aramb-workflows/SKILL.md` (commit `8589eb1`)
- **Added `### Bake the fetch tool into each evaluator node prompt`** under Workflow
  CRUD. When authoring per-role evaluator node prompts, name the fetch tool in the
  prompt itself:
  - **Code-evaluation roles** (Backend / Frontend / GitHub submissions) → clone/curl
    the repo; do NOT use the browser for GitHub (public repos need no auth/toolkit).
  - **Visual roles** (Product / UI/UX, Figma / Rive) → use the browser to open and
    visually inspect the rendered artifact.
  - **One-line general principle** mirroring the aramb-browser fetch hierarchy.

### #5 — publish/run doc alignment — `aramb-workflows/SKILL.md` (commit `8589eb1`)
- `aramb_workflows.publish`: documented param **`workflow_id`** (required); success
  return updated to **`{ workflow_id, status: "active", version, published_at }`**
  (was `{ published, version }`); noted idempotency and the structured
  missing-toolkit error contract; clarified the agent can publish directly.
- `aramb_workflows.run`: documented params **`workflow_id`** (required) +
  **`custom_instruction`** (optional); success return **`{ run_id, status }`**; added
  the **auto-publish-a-draft-first** behavior (with the toolkit gate applying on that
  first publish). **Confirm-first guidance retained** unchanged.
- Removed/repaired "Workflows tab only" hedging:
  - `aramb-workflows/SKILL.md` publish note now says publishing is this tool *and the
    agent can call it directly* (the existing "never tell the user to publish from the
    Workflows tab" line was already correct and kept).
  - `create-workflow/SKILL.md` closing-message template line for manual-run workflows
    changed from "run it from the Workflows tab" → "just ask me to run it, or run it
    from the Workflows tab."

### Addendum folded in & resolved (commit `8589eb1`)
- `claude/tasks/2026-06-21/run-workflow-mcp-addendum.md` existed. Its run-flow
  guidance was already documented in the 2026-06-21 batch (run section + AGENTS.md
  inventories + that dir's `IMPL-COMPLETE.md` "Run-flow addendum"). Batch 1 completed
  it by aligning the tool shapes/auto-publish with the registered contract. Added a
  **RESOLVED** banner to the addendum marking it folded into this batch.

---

## Contract verification (matches brahmi's registered tools)

| Tool | Params | Returns | Notes |
|------|--------|---------|-------|
| `aramb_workflows.publish` | `workflow_id` (required) | `{ workflow_id, status: "active", version, published_at }` | Idempotent if already active; structured error names missing toolkits |
| `aramb_workflows.run` | `workflow_id` (required), `custom_instruction` (optional) | `{ run_id, status }` | **Auto-publishes a draft first**, then triggers; confirm-first enforced by the skill |

Both **exactly match** the cross-repo contract in the workspace design doc
(§ "Cross-repo contract (the only shared surface: #5)").

---

## Out of scope (Batch 2) — deliberately untouched
- Pre-build clarifying-questions checklist (#9).
- Progress / failure surfacing prompts (#6).

## Commits on `feat/workflow-reliability-batch1`
- `e4750d3` — docs(aramb-browser): add fetch hierarchy — browser last, curl public/static
- `8589eb1` — docs(aramb-workflows): bake per-role fetch tool into node prompts; align publish/run with registered MCP contract

Not pushed; no PR (per instructions).
