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
- `aramb_mcp.workflows_publish`: documented param **`workflow_id`** (required); success
  return updated to **`{ workflow_id, status: "active", version, published_at }`**
  (was `{ published, version }`); noted idempotency and the structured
  missing-toolkit error contract; clarified the agent can publish directly.
- `aramb_mcp.workflows_run`: documented params **`workflow_id`** (required) +
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
| `aramb_mcp.workflows_publish` | `workflow_id` (required) | `{ workflow_id, status: "active", version, published_at }` | Idempotent if already active; structured error names missing toolkits |
| `aramb_mcp.workflows_run` | `workflow_id` (required), `custom_instruction` (optional) | `{ run_id, status }` | **Auto-publishes a draft first**, then triggers; confirm-first enforced by the skill |

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

---

## Fix pass (post-audit, commit `b06f2bd`)

A production audit of `main...HEAD` returned a **fix-then-ship** verdict. The #5
contract alignment was clean (no changes needed). Three #1 findings on
`aramb-browser/SKILL.md` were fixed; all stay in Batch 1 scope (prompt/skill only).

### H1 (HIGH) — frontmatter `description` still contradicted the new policy
- **Finding:** the body was scoped to the fetch hierarchy, but the YAML
  `description` (the most-read, selection-surfaced line) still said *"The ONLY way
  to touch the web… No WebSearch, WebFetch, curl, wget, or HTTP libraries"* — the
  literal opposite of the new policy 14 lines below.
- **Fix:** rewrote the `description` to lead with the browser's real scope
  (JS-rendered / authenticated / visually-inspected content), keep the
  datacenter-UA rationale scoped to *those* sites, and state the public/static →
  `curl`/`git clone`/`WebFetch` case explicitly, pointing at the Fetch hierarchy.

### M2 (MEDIUM — over-correction) — JS-rendered "public" pages on the curl side, no fallback
- **Finding:** public Notion / Google Docs / Drive pages are heavily JS-rendered
  and return a near-empty shell or 403 to a datacenter UA, yet were listed as curl
  targets — and there was no "if curl fails, escalate to browser" rule. Risk:
  agents curl a JS page, get garbage, and don't know they may fall back.
- **Fix:** (a) re-bucketed the curl bullet to "plain HTML pages, raw/exported docs,
  and real API/JSON endpoints whose content is in the response body," explicitly
  flagging public Notion/Docs/Drive as JS-rendered **browser** cases; (b) added an
  **"Escalation — curl first, browser on failure"** rule: SPA HTML / near-empty
  shell / login-redirect / 403 from a `curl` of a supposedly-static page → switch
  to the browser. Content already known to need JS/auth/visual inspection still
  skips straight to the browser, so genuinely-rendered pages are **not** pushed to
  curl.

### M3 (MEDIUM — ambiguity) — JSON bullet could be misread as "all JSON → curl"
- **Finding:** the curl-side "JSON / API responses" bullet (19 lines above the
  Reddit/X/LinkedIn `.json`-returns-HTML browser case) could be read as "all JSON →
  curl," re-colliding with the social-`.json` trap.
- **Fix:** tightened to "real API / JSON endpoints" and named the social-`.json`
  trap inline in the same bullet, pointing at the escalation rule.

### Post-fix verification (re-read of lines 1–52)
- Description now agrees with the body — **no residual contradiction.**
- JS-rendered and auth-gated content is routed to the browser in three places (the
  `description`, the "Use the browser ONLY for" list, and the escalation carve-out)
  — **no over-correction**; the escalation makes the curl/browser boundary a
  try-then-escalate default rather than an up-front guess.
- The #5 publish/run tool names/params/returns were unchanged by this pass and
  still match the cross-repo contract.

**Fix-pass commit:** `b06f2bd` — docs(aramb-browser): fix-pass — scope frontmatter
desc, qualify static traps, add curl-first escalation. Not pushed; no PR.
