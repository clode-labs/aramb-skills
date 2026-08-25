# aramb-skills — Workflow Reliability Batch 1

**Workspace design doc:** `/Users/siva/workspace/claude/tasks/2026-06-23/workflow-reliability-batch1.md` (read it first)
**Branch:** `feat/workflow-reliability-batch1` (off fresh `main`)

You own **prompt/skill changes only** (#1, and the #5 doc-alignment). No code. The goal: stop
agents from using the slow/flaky browser to fetch **public** content (the single biggest cause of
big-node failures), and make the publish/run skill docs truthful now that brahmi is registering the
tools.

---

## #1 — Browser-vs-curl tool policy (the big lever)

### Evidence (why this matters)
For a recruitment workflow scoring **public GitHub repos**, the backend evaluator made 75 browser
calls vs 46 GitHub-API calls; frontend 82 vs 32. The agent's own reasoning:
- "GitHub toolkit isn't connected in the run session."
- "GitHub needs interactive OAuth — unavailable headless. I'll use the browser to hit the API."
- "raw.githubusercontent works unmetered **via the browser**. I'll fetch package.json + README."
- "Browser hiccupped mid-run (batches 3-5 failed). I got 86/131."

It even discovered the unmetered raw endpoint but still routed it through the browser. Public repos
need **no auth and no toolkit** — a plain `curl` / `git clone` is ~50× faster and reliable.

### Edit A — `aramb-browser/SKILL.md` (add a fetch hierarchy near the top)
Add a prominent, early section establishing **when NOT to use the browser**:

- **Default to non-browser fetch for public/static content.** GitHub repos & raw files, public
  Notion/Docs/Drive pages, plain HTML, JSON/API responses → use `curl`, `git clone --depth 1`, or
  `WebFetch` from Bash. These are faster, cheaper, and don't "hiccup."
- **Use the browser ONLY for** content that genuinely requires a rendered DOM / JS execution / login /
  visual inspection: Figma, Rive, interactive web apps, canvas, dashboards behind auth, anything where
  the meaningful content is rendered client-side or gated.
- **Public repos rule:** public GitHub repos need NO auth, NO GitHub toolkit, NO OAuth.
  `git clone --depth 1 https://github.com/<owner>/<repo>` or
  `curl -sL https://raw.githubusercontent.com/<owner>/<repo>/<branch>/<path>`.
- **Toolkit-unconnected fallback:** if a toolkit (GitHub, Sheets) isn't connected, fall back to the
  **unauthenticated** path (curl/clone/public API) — **never** fall back to the browser to scrape
  what curl can fetch.
- **Never** drive the browser to fetch a file you could `curl`. If you find an unmetered raw URL,
  `curl` it directly.

Keep the change additive and consistent with the skill's existing voice; don't delete legitimate
browser usage docs.

### Edit B — `aramb-workflows/SKILL.md` (bake role-appropriate tools into node prompts)
When the authoring agent generates per-role evaluator node prompts, instruct it to specify the
fetch tool in the node prompt itself, so the evaluator doesn't rediscover tooling at runtime:
- Code-evaluation roles (Backend/Frontend/any GitHub submissions) → "clone/curl the repo; do NOT use
  the browser for GitHub."
- Visual roles (Product UI/UX, design, Figma/Rive) → "use the browser to open and inspect the
  rendered artifact."
- Add a one-line general principle to the workflow-authoring guidance mirroring the fetch hierarchy
  above.

---

## #5 — Align publish/run skill docs with the now-registered tools

brahmi is registering `aramb_mcp.workflows_publish` and `aramb_mcp.workflows_run` this batch (see workspace
doc cross-repo contract). The skill already documents them — verify and tighten:

- Confirm the documented **tool names and params exactly match** the contract:
  - `aramb_mcp.workflows_publish` — `workflow_id` (required). Returns `{workflow_id, status, version, published_at}`.
  - `aramb_mcp.workflows_run` — `workflow_id` (required), `custom_instruction` (optional). Returns `{run_id, status}`. Auto-publishes a draft first.
- Keep the **confirm-first** guidance for `run` (the agent should confirm with the user before
  triggering a real run, especially at scale).
- Remove/repair any text implying the agent CANNOT publish/run (e.g. "those controls live in the
  Workflows tab, not available to me") — that is now false.
- If `aramb-skills/claude/tasks/2026-06-21/run-workflow-mcp-addendum.md` exists, fold its guidance in
  and mark it resolved.

---

## Test plan
After brahmi + this land on a test image, re-run a public-repo scoring workflow and verify via
`agent_run_events`:
1. Code-role evaluators use `curl`/`git clone`; browser calls for those roles ≈ 0.
2. Browser usage concentrated in the visual (UI/UX) node only.
3. Agent can publish + run from chat without referring the user to the Workflows tab.

## Out of scope (Batch 2)
Pre-build clarifying-questions checklist (#9), progress/failure surfacing prompts (#6). Don't add
those here.

## Done =
SKILL.md edits committed on `feat/workflow-reliability-batch1`, tool names verified against brahmi's
registration, then await the audit pass before PR.
