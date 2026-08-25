# aramb-skills — dev slack-toolkit followups (Issues #2, #3, #4)

Workspace design doc (read first, contracts locked there):
`/Users/siva/workspace/claude/tasks/dev-slack-toolkit-followups.md`
Root-cause log: `/Users/siva/workspace/claude/tasks/dev-slack-toolkit-issues-2026-06-16.md`

Branch off **fresh `origin/main`**: `fix/dev-slack-toolkit-followups`.
All markdown/prompt changes — **no audit, no Go build**. Never push to main; PR only;
no Co-Authored-By trailer. Skills are flat dirs: `aramb-skills/<name>/SKILL.md`.

---

## Issue #2 — new `aramb-toolkits` skill

There is a first-class skill for every MCP surface EXCEPT toolkits, so the agent
guesses the `aramb_mcp.toolkits_*` call contract (`toolkit_slug=` vs `toolkit=`).

**Create `aramb-skills/aramb-toolkits/SKILL.md`** mirroring `aramb-workflows/SKILL.md`
structure and frontmatter:
- Document the `aramb_mcp.toolkits_*` MCP **catalog/check** contract with exact mcporter
  call syntax (`npx mcporter call aramb_mcp.toolkits_<tool> key="value"`):
  `list_toolkits`, `list_triggers`, `get_trigger`, `check_connection` — and the
  correct arg is **`toolkit=`** (not `toolkit_slug`). Pull the precise contract from
  `configure-trigger/SKILL.md` (which currently documents it incidentally) and
  promote it here as the canonical home.
- Make the **division of labour** explicit and cross-reference `composio-cli`:
  - `aramb-toolkits` = **catalog + check connection** (what's available / is it
    connected). It CANNOT fetch data.
  - `composio-cli` = **execution** (`composio execute <SLUG>`, e.g.
    `GMAIL_FETCH_EMAILS`).
  - The flow: *check connection (`aramb-toolkits`) → execute (`composio-cli`)*.
- After creating it, trim `configure-trigger/SKILL.md` to reference `aramb-toolkits`
  for the catalog/check contract instead of re-documenting it (single source).

---

## Issue #3 — durable persona: "check toolkits before declining"

Make "check connected toolkits before declining an external-data request" universal
agent behavior (so it holds even where the chil surface prompt isn't loaded).

- In the relevant persona/behavior skill(s) (e.g. `solo` and/or the shared behavior
  guidance — find where give-up / "I don't have access" behavior is shaped), add a
  rule: before saying "I don't have access to X", check connected toolkits
  (`aramb-toolkits` skill) and execute via `composio-cli` if connected.
- Keep it skill-named, consistent with the chil seed wording (Issue #3 there).

---

## Issue #4 — rewrite workflow skills to default project-scoped

brahmi adds `aramb_mcp.workflows_list project_id=…` (+ `project_id` on `get`). The
workflow skills still lead with `application_id` and the "one workflow per
application" invariant, which is now wrong (workflows are appless/project-scoped;
identity = `lineage_id`).

**Return shape the new `list` tool gives you (lock to this):**
`[{ workflow_id (lineage_id), name, application_id|null, status, schedule|null, updated_at }]`

**Rewrite these skills** (grep each for `application_id` and the per-app framing):
`aramb-workflows`, `create-workflow`, `update-workflow`, `import-workflow`,
`configure-trigger`, `schedule-workflow`.

- **Lead with project scope:** to find/enumerate workflows, use
  `npx mcporter call aramb_mcp.workflows_list project_id="<PROJECT_ID>"` (and note
  `aramb_mcp.workflows_get project_id="…"` also works). This is the answer to "what
  workflows exist?" — NOT `get application_id=…` (that finds only one legacy
  app-bound row and misses appless workflows).
- **Demote `application_id`** to optional/legacy throughout — it's no longer
  required to create a workflow; appless is the norm. Remove "single-workflow-per-
  application" invariant language.
- Keep create/update/trigger contracts accurate to the current MCP tool params
  (verify against the tool descriptions; don't invent params).

## Done =
New `aramb-toolkits` skill present + cross-referenced; persona rule added; workflow
skills lead with `list project_id=` and demote `application_id`; `configure-trigger`
de-duplicated. Commit on `fix/dev-slack-toolkit-followups`. Stop.
