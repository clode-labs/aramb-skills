# Workflow Reliability Batch 2 — aramb-skills IMPL-COMPLETE

**Branch:** `feat/workflow-reliability-batch1` (extended — Batch 1 + 2 ship together)
**Scope:** prompt/skill edits only. Two items: #9 (pre-build clarifying questions)
and the #6 prompt half (stop fabricating run status). Browser/curl policy
(Batch 1) and all brahmi-side work were left untouched.

---

## #9 — Pre-build clarifying-questions checklist

**File:** `create-workflow/SKILL.md`
**Commit:** `73ef2ca`

Added a new section **"## 1.5 Pre-build checklist — confirm-then-build (one
concise round)"**, placed after the spec-gathering step (§1) and before the
progress-reporting/analyze/design steps — i.e. it runs *before* nodes are
constructed.

It directs the agent to confirm, in **one concise round of 2–4 questions**
(confirm-then-build, not interrogation; skip items that are already clear), the
few things that materially change the build:

- **Scoring / decision params** not clearly specified (threshold, rubric weights,
  pass mark, ranking cutoff) — confirm, don't guess. (The incident's Proceed
  threshold: built at 65, user wanted 80.)
- **Toolkit connectivity** — self-verify **every** external system via
  `aramb_mcp.toolkits_check_connection`; if any is unconnected, tell the user what to
  connect *before* the build rather than discovering it mid-run. (Sheets + GitHub
  were both disconnected in the incident.)
- **Scale / cost heads-up** — for large input sets, state rough scale/time/cost and
  offer a small pilot first. (382 candidates / 222 backend was a long, costly job
  kicked off with no warning.)
- **Source accessibility** — confirm sources are reachable the way the run will
  reach them (public vs needs auth: toolkit connection / repo link / browser login).

Framed as "confirm-then-build, not build-then-apologize," consistent with the
skill's existing voice (guidance, not a rigid script). The pre-existing
chat-dispatch `aramb_mcp.chat_ask_question` clarifier (§1) is complementary and left
in place.

---

## #6 (prompt half) — Stop fabricating run status

**Files:** `aramb-workflows/SKILL.md`, `create-workflow/SKILL.md`
**Commit:** `c776c1f`

Context: brahmi (Batch 2) now posts **real** run progress + success/failure notes
to the originating conversation automatically, so the agent must not invent
status.

- `aramb-workflows/SKILL.md` — reworked the run-section **"### 4. Report"** so a
  successful kick-off **hands off to the run** (system reports; don't promise to
  babysit), and added a new **"### 5. After the run starts — let the system report;
  never fabricate progress"** subsection:
  - Do NOT invent progress — no per-batch/per-item counts (uses the incident's own
    "4/382 scored, working through the rest…" as the anti-example); the system's
    messages are the source of truth.
  - On a "what's the status?" query, report **only verifiable** state read from
    `aramb_mcp.workflows_get` / `list`, or acknowledge the run is in progress and the
    system will post updates — never a fabricated number.
  - If a lookup shows failure/stuck, say so plainly.
- `create-workflow/SKILL.md` — extended **non-negotiable #3** ("Never claim a
  workflow ran unless the run tool said so") with the same hand-off + no-fabricated-
  progress rule and a pointer to read real status via `get` / `list`, cross-
  referencing the `aramb-workflows` run section.

No existing template lines encouraged made-up progress narration (the only
progress-narration guidance is create-time, which is legitimate), so nothing
needed removal.

---

## Verification

- `git diff` reviewed against `claude/tasks/2026-06-23/workflow-reliability-batch2.md`
  and the workspace design doc — both items fully covered.
- Edits are additive and match each skill's existing voice/structure.
- Out-of-scope areas (browser/curl policy, brahmi-side #6 surfacing) untouched.

## Fix pass (post-audit)

A production audit (production-audit.md rubric, scoped to commits `73ef2ca` +
`c776c1f`) raised one HIGH finding and one nit. Both fixed:

- **HIGH — `get`/`list` don't return run/step status.** The #6 edit told the agent,
  on a status question, to read "run status, step states" via `aramb_mcp.workflows_get`
  / `list`. But those tools return the workflow's **definition/lifecycle** state
  (`status` = `draft`/`active`/paused, plus schedule/nodes/edges), not per-step run
  progress — there is no documented run-status read tool; the system's automatic
  conversation posts are the real run-state surface. As written, the agent would
  have relayed workflow-level `active` as if it were run health — a fresh, subtler
  fabrication, the exact failure #6 set out to kill.
  - **Fix.** Reworked `aramb-workflows/SKILL.md` §5 status bullet: the conversation
    thread is the source of truth for run/step progress; `get`/`list` are explicitly
    documented as definition/lifecycle only, to be used solely for *workflow*-level
    questions ("is it published / scheduled?") and labeled as such — never dressed up
    as run progress. Also retied the "first bullet" anti-fabrication wording and the
    failed/stuck bullet to the system's posted updates (not "the tools" / "a lookup"),
    and mirrored the correction in the `create-workflow/SKILL.md` non-negotiable #3
    cross-reference.
- **NIT — overstated parity of `check_connection` with the publish gate.** The #9
  toolkit-connectivity bullet said the up-front check is "the same gate `create`
  enforces at publish; checking up front saves a failed run." `check_connection`
  only verifies a connection *exists*; the publish/run eval gate is authoritative and
  can still reject on scopes/expiry.
  - **Fix.** Softened the parenthetical in `create-workflow/SKILL.md` §1.5 to name the
    publish/run eval gate as authoritative and frame the up-front check as catching
    the common "not connected at all" case early.

**Re-verified after the fix pass:** no new contradiction with the Batch 1 browser
policy (the §1.5 "browser login" reference is still the sanctioned manual-auth path,
not a runtime-fetch steer) or the run/publish flow (the §5 wording operates only
after a `run_id` returns and correctly describes `get`/`list`, consistent with the
auto-publish/toolkit-gate text above it). Audit focus questions #1 (#9 doesn't
over-ask), #2 (`check_connection` is a real tool), and #4 (no policy/gating
contradiction) were confirmed clean by the audit and unchanged by this pass.

## Commits (local only — not pushed)

| Commit | Item | Files |
|--------|------|-------|
| `73ef2ca` | #9 pre-build checklist | `create-workflow/SKILL.md` |
| `c776c1f` | #6 stop fabricating run status | `aramb-workflows/SKILL.md`, `create-workflow/SKILL.md` |
| (fix pass) | HIGH (get/list ≠ run status) + nit (check_connection parity) | `aramb-workflows/SKILL.md`, `create-workflow/SKILL.md` |
