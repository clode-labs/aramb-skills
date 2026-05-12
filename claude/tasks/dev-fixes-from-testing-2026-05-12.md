# aramb-skills — fixes from dev testing pass

Tracker: `/Users/siva/workspace/claude/tasks/dev-testing-issues-2026-05-11.md`
Coordination doc: `/Users/siva/workspace/claude/tasks/dev-fixes-coordination-2026-05-12.md`

Three issues land in this repo. All are skill-prompt edits — no runtime code,
no schema, no MCP plumbing changes. Skills are baked into the kairo image at
build time, so a change here ships when the next kairo image cuts.

| # | Title | Files |
|---|-------|-------|
| 1 | Preview URL not called after expose | `aramb-expose/SKILL.md`, `solo/SKILL.md`, `local-deployment/SKILL.md` |
| 4 | File output inlined as text instead of `deliver_artifacts` chip | `solo/SKILL.md` |
| 7 | Solo-create-workflow stamps team-mode personas on every node | `solo-create-workflow/SKILL.md` |

---

## Convention being applied

The repo has no top-level "mandatory rules" convention; individual skills use
ad-hoc patterns. The strongest existing precedents — and the patterns these
fixes match:

- `solo-create-workflow/SKILL.md` lines 22–28: `## MUST rules — read before anything else` (numbered list of hard constraints + failure modes).
- `solo/SKILL.md` lines 48–55: `Rules for artifacts:` (rules subsection inside a procedural section).
- `solo/SKILL.md` lines 101–115: `## Forbidden in solo mode` (explicit prohibition section).
- `local-deployment/SKILL.md` line 444: imperative bold prohibition (`**Do NOT kill the tunnel...**`).

**Rule when adding a hard step:** put it in a `Rules for X:` subsection inside
the section that documents the action, AND mirror it as a one-line entry in the
skill's top-of-file `MUST rules` block if the skill has one. Don't invent a new
section style — match an existing precedent. Avoid burying the rule inside
prose; the agent should see imperative language and explicit forbidden cases.

---

## Issue #1 — Preview URL not auto-updated after expose

**Tracker ref:** `dev-testing-issues-2026-05-11.md:37-63`

### Confirmed RCA

The chip + URL persistence backend (`brahmi.update_preview_url`) works
end-to-end. The agent simply did not call it. Three skill surfaces document
the call today, and none of them frame it as mandatory:

- `aramb-expose/SKILL.md` lines 155–169 — "Step 6: Report all URLs" describes
  calling `update_preview_url` in prose alongside `send_message`. Framed as
  reporting flow, not as a hard step.
- `solo/SKILL.md` lines 65–68 — a `## Deployment` section with two unannotated
  bullet examples of the call (`environment="local"` and `environment="deployed"`).
  No surrounding rules. No mention of when it applies.
- `local-deployment/SKILL.md` lines 396–399 — Step 8 reporting checklist;
  one of three bullets after "ALL URLs verified".

The agent that exposed a tunnel via `aramb-expose` followed Step 6's prose
reporting and decided "putting the URL in the chat reply" satisfied the
"report" instruction. The `update_preview_url` MCP call was skipped.

This is a prompt-compliance gap, not a backend defect.

### Fix design

Per user direction (2026-05-12), `update_preview_url` and
`deliver_artifacts` are two distinct backend entry points serving
different purposes:

- `update_preview_url` — registers which app/chat owns which
  preview URL. Powers the in-app iframe, app header preview surface,
  etc. **Backend state update, no chat chip.**
- `deliver_artifacts` — emits a clickable tile on the chat row.
  **Chip rendering, no backend state.**

A URL deliverable needs **both**. The agent must call:
1. `update_preview_url` first (set the state)
2. `deliver_artifacts` second with `kind: "url"` (emit the chip)

Brahmi PR C extends `handleDeliverArtifacts` to accept URL-kind
artifact entries (see brahmi plan #2). This skill plan teaches the
agent the two-call pattern across all expose/deploy skills.

Convention used: `Rules for preview URLs:` subsection in each skill
surface (matches `solo/SKILL.md`'s `Rules for artifacts:` precedent).
Hoist the same rule into each skill's top-of-file `MUST rules`
block when one exists. The rule has three parts:

1. **When it applies** — whenever a deploy/expose step produced any
   URL the user can reach (frontend, API, tunnel, public proxy).
2. **What's mandatory** — calling BOTH `brahmi.update_preview_url`
   AND `brahmi.deliver_artifacts` (with `kind: "url"`) for the
   primary frontend URL. Order: state update first, chip emit
   second.
3. **What's forbidden** — substituting either call by mentioning the
   URL in chat prose. Both calls are required even if the URL also
   appears in the reply text.

Why this works: clean addition (no removal of existing guidance),
matches existing convention (rules subsection + MUST block hoist),
and explicit "two calls, two purposes" framing makes the
distinction clear to the agent.

### Touch list

**`aramb-expose/SKILL.md`** — three changes:

1. **New top-of-file `MUST rules` section** (mirror solo-create-workflow's
   convention). Insert after the frontmatter, before any existing prose.
   Single rule: "If this skill exposes a URL the user can reach, call
   BOTH `brahmi.update_preview_url` (state update) AND
   `brahmi.deliver_artifacts` (chip emit) before composing the
   user-facing reply. Both calls are mandatory; mentioning the URL
   in prose is not a substitute for either."
2. **In existing Step 6 (lines 155–169):** convert the descriptive
   prose to imperative phrasing for the two MCP calls. Show both:
   ```bash
   # 1. State update — register the preview URL with brahmi
   npx mcporter call brahmi.update_preview_url \
     project_id="<PROJECT_ID>" url="$FRONTEND_URL" environment="deployed"

   # 2. Chip emit — surface the URL as a clickable tile in chat
   npx mcporter call brahmi.deliver_artifacts \
     artifacts='[{"kind":"url","url":"'"$FRONTEND_URL"'","title":"Preview URL","environment":"deployed"}]'
   ```
   Add a `Rules for preview URLs:` subsection after the examples,
   restating the dual-call requirement and the forbidden
   substitution.
3. **Verify Step 6 cannot be skipped by an early return.** Scan the
   skill for any "if X, stop here" branches between the expose step
   and Step 6; confirm Step 6 lands after every successful expose
   path. If a branch bypasses Step 6, route it through.

**`solo/SKILL.md`** — two changes:

1. **Replace the `## Deployment` section (lines 65–68)** with a
   structured subsection matching the `Delivering files` pattern
   (lines 23–58). Lead with prose describing when the call applies,
   show BOTH MCP call examples inline (same pair as in
   `aramb-expose`), follow with an explicit `Rules for preview URLs:`
   block. Keep the existing `environment="local"` /
   `environment="deployed"` variants as examples inside the
   section.
2. **Extend `## Forbidden in solo mode`** (lines 101–115) with one
   line: "Reporting an exposed URL only in chat prose, OR calling
   only one of `update_preview_url`/`deliver_artifacts` (instead of
   both), is forbidden. State update and chip emit are independent
   responsibilities; the URL needs both."

**`local-deployment/SKILL.md`** — one change:

1. **In Step 8** (around line 396): convert the bullet to imperative
   pair: "**Call `update_preview_url`** for the primary frontend URL
   AND **call `deliver_artifacts`** with the URL kind." Add a
   `Rules for preview URLs:` subsection mirroring `aramb-expose`.
   Keep wording aligned across the three skills so the agent sees
   the same rule regardless of which deploy path it hit.

### Test plan

This is prompt content — no unit tests apply. Verification is behavioural.

**Manual repro (must pass before closing):**

1. Solo-mode app. Send: "build a calculator and expose it".
2. Wait for agent to finish.
3. Two assertions:
   - **State update:** `applications.preview_urls` for the app
     contains the exposed URL with `environment` either `local` or
     `deployed`.
   - **Chip emit:** the chat shows a clickable URL chip titled
     "Preview URL" (FE renders from the chat row's
     `metadata.artifacts`).
4. Repeat with a non-solo (team) app using a build flow that hits
   `aramb-expose` — confirm both calls fire there too.

**DB queries to confirm:**

```sql
-- State update happened
SELECT id, name, preview_urls
FROM clode.applications
WHERE id = '<test_app_id>';

-- Chip emit happened (chat row with URL artifact)
SELECT id, content, metadata
FROM clode.chat_messages
WHERE application_id = '<test_app_id>'
  AND metadata @? '$.artifacts[*] ? (@.kind == "url")'
ORDER BY created_at DESC
LIMIT 1;
```

Expected: `applications.preview_urls` is a non-empty JSONB array
AND the chat_messages row exists with a URL artifact. If either is
missing, one of the two calls didn't fire — re-check skill content
or re-pull the kairo image.

**Negative control:** in a third app, send a chat that does NOT
produce a URL (e.g. "list the files in the workspace"). Confirm the
agent does NOT call either MCP spuriously. The rule is conditional
on having produced a URL.

### Migration / rollout

- Skill changes ship via the kairo image. After merge, rebuild the kairo
  image and bump `.image-tag` in `local-testing/` for the next dev cut.
- No DB migration. No env var. No coordination with brahmi or web-app-v2.
- Behaviour applies to all runs that start after the new image is
  deployed; pre-existing pool agents on the old image won't pick up the
  new rule until they're cycled.

---

## Issue #4 — Solo agent inlined file path instead of calling `deliver_artifacts`

**Tracker ref:** `dev-testing-issues-2026-05-11.md:127-173`

### Confirmed RCA

This was reported as the same class as #1 (prompt compliance), but the
state of the prompt is meaningfully different. The grounding read shows
`solo/SKILL.md` lines 23–58 already has:

- A `### Delivering files` section with prose lead-in.
- Numbered steps including "**Call `deliver_artifacts`**".
- An explicit `Rules for artifacts:` subsection.
- The line "`artifacts` is required and non-empty. For chat-only updates
  with no file output, use `send_message` instead."

So the rule already exists with mandatory framing. The agent still
inlined `/home/node/workspace/hello-there-de68cd7/india_top_news_2026-05-11.json`
as a code-fence in its reply. Two plausible failure modes:

1. **Loophole reading.** The agent interpreted "When you produce a file
   the user should be able to open from chat" (line 25) as conditional:
   "this user can read the contents from my reply text, so they don't
   need to open it from chat". The rule's predicate is ambiguous.
2. **No "do this before ending the turn" framing.** The rule says
   `artifacts` is required when calling `deliver_artifacts`, but doesn't
   say "do not end the turn without calling `deliver_artifacts` when you
   produced a file". A subtle gap: required *args* vs required *call*.

### Fix design

Two narrow edits to close both loopholes:

1. **Tighten the predicate.** Replace "the user should be able to open
   from chat (PDF, JSON, text file, image, anything)" with "any
   user-facing file you produced under your working directory in this
   turn (PDF, JSON, text file, image, anything)". This removes the
   "should-be-able-to" judgment call. Any file the agent wrote =
   `deliver_artifacts` required.
2. **Add a `Forbidden` line** in the existing `## Forbidden in solo mode`
   section (lines 101–115): "Mentioning a workspace file path in your
   reply text without first calling `deliver_artifacts` is forbidden.
   Inline paths are dead text — the chip pipeline cannot turn them into
   clickable chips after the fact."

Why this works: doesn't restructure or duplicate the existing
well-written `Delivering files` section. Closes the predicate ambiguity
that the agent walked through. The `Forbidden` entry tells the agent
explicitly what *not* to do — closing the "I described it in prose,
isn't that fine?" loophole.

### Touch list

**`solo/SKILL.md`** — two minimal edits:

1. **Line 24–25 (predicate sentence):** rewrite as described above.
   Keep the rest of the section intact.
2. **Inside `## Forbidden in solo mode` (lines 101–115):** append one
   line as described above.

No other surface needs changes. `deliver_artifacts` is solo-only; team
mode uses different mechanisms.

### Test plan

**Manual repro (must pass before closing):**

1. Solo-mode app. Send: "Give me the top 5 AI papers from last week in a
   JSON file."
2. Agent runs to completion.
3. Inspect the agent's final chat message in the FE: must contain a
   chip block (not inline `<code>` with the file path).

**DB query:**

```sql
SELECT id, sender_type, content, metadata
FROM clode.chat_messages
WHERE application_id = '<test_app_id>'
  AND sender_type = 'agent'
ORDER BY created_at DESC
LIMIT 1;
```

Expected: `metadata->'artifacts'` is a non-empty JSON array with at least
one `{path: "..."}` entry. If the array is missing or empty, the rule did
not fire.

**Negative control:** ask a chat-only question ("what's the date today?").
Confirm the agent calls `send_message` (or just replies) without invoking
`deliver_artifacts` with a synthetic artifact entry.

### Migration / rollout

Same as #1 — ships with the next kairo image build. No coordination.

---

## Issue #7 — Solo-create-workflow stamps team-mode personas on every node

**Tracker ref:** `dev-testing-issues-2026-05-11.md:349-411`

### Confirmed RCA

`solo-create-workflow/SKILL.md` is structurally close to a copy of
`create-workflow/SKILL.md`. The agent-assignment guidance and the
canonical `save_workflow` example both name team-mode personas:

- Line 95: "Which agent identity should run it (`developer`,
  `aramb-deployer`, etc.)"
- Line 110: "Pick agent assignments that match the work — `developer`
  for code/data work, `aramb-deployer` for deploys, `local-deployer`
  for tunnels, etc."
- Lines 245–249: canonical example shows every node with
  `"assigned_agent": "developer"`.

So the agent reads "in solo mode, decompose into ordered steps; for each
step pick a persona — see examples", follows the examples, and stamps
`developer` on every node. The skill never tells the agent that personas
don't exist in solo mode.

The skill DOES already have a precedent for solo-mode field treatment:
lines 208–214 explain that `source_task_id` should be omitted or `null`
in solo mode because solo doesn't have source tasks. The same pattern
applies cleanly to `assigned_agent` — solo has one agent, so per-node
assignment isn't a concept.

**Decided schema shape (cross-cut with brahmi plan):** solo-mode nodes
carry `assigned_agent: "solo"`. This is a real agent identity in the
kairo image (the solo persona is baked in at boot); it dispatches
correctly through the existing `RunAgent` path. The string `"solo"` is
the sentinel — not NULL, not empty. The brahmi plan adds `"solo"` to
the `ProvisionAgents` no-op set so no provisioning round-trip happens,
and short-circuits `ProvisionAgents` entirely for solo applications
(belt-and-suspenders).

The reason `"solo"` beats empty-string: the value remains dispatchable
without runtime indirection. The FE's existing canvas renderer
surfaces `SOLO` under each node, identical to how it surfaces
`DEVELOPER` in team mode — no FE change required.

### Fix design

Three coordinated edits to `solo-create-workflow/SKILL.md`. They
collectively shift the skill from "team-mode-with-solo-flavour" to
"solo-is-fundamentally-different".

1. **Remove team-mode persona-picking guidance.** Lines 95 and 110
   become unnecessary — there's nothing to pick. Replace with one
   sentence explicitly stating the rule.
2. **Update the canonical `save_workflow` example.** Every node's
   `"assigned_agent"` value becomes `"solo"`. Don't omit the field —
   omitting it makes the agent unsure whether it can omit; an explicit
   `"solo"` is unambiguous.
3. **Add a MUST rule at the top of the file** mirroring the existing
   `## MUST rules — read before anything else` section. Single rule:
   "Every node's `assigned_agent` must be `"solo"`. Do not pick
   `developer`, `aramb-deployer`, `local-deployer`, or any other
   persona — those exist only in team mode. The solo agent itself
   executes every step."
4. **Extend the pre-flight checklist** at lines 208–214 (the existing
   `source_task_id` solo-specific entry) with a parallel entry for
   `assigned_agent`: "`assigned_agent` — solo has only one agent. Stamp
   `"solo"` on every node. Brahmi rejects any other value for
   solo-mode workflows (see brahmi plan)."

### Touch list

**`solo-create-workflow/SKILL.md`** — four changes:

1. **`## MUST rules` block (after the existing entries, lines ~22–28):**
   insert the new mandatory rule for `assigned_agent`.
2. **Line ~95** ("Which agent identity should run it..."): delete the
   bullet entirely. Replace with a clarifying sentence at the start of
   the decomposition section: "Solo mode has one agent. Decomposition
   is about ordering work, not about picking a persona."
3. **Line ~110:** delete the persona-picking bullet entirely. If the
   surrounding paragraph reads oddly after removal, rewrite the
   paragraph to lead with toolkit-and-acceptance-criteria framing
   (which is what matters in solo mode).
4. **Lines ~245–249 (canonical example):** change every
   `"assigned_agent": "developer"` → `"assigned_agent": "solo"`.
   No other field changes; `required_toolkits`, `prompt`, etc.
   stay as written.
5. **Pre-flight checklist (lines ~208–214):** add an `assigned_agent`
   entry between or after the existing `source_task_id` entry. Same
   bullet style.

**`create-workflow/SKILL.md`** — verify no inadvertent edits.
Team-mode workflow creation legitimately uses
`developer`/`aramb-deployer`/`local-deployer`. Leave entirely alone.

### Test plan

**Manual repro (must pass before closing):**

1. Solo-mode app. Ask agent: "create a workflow that pulls top 5 AI news
   each day and emails a summary".
2. Agent calls `save_workflow`.
3. Open workflow canvas in FE. Confirm:
   - Every node renders with a `SOLO` badge under the title — the
     solo agent is a real agent identity, and the FE surfaces it the
     same way it would surface `DEVELOPER` in team mode.
4. DB check:
   ```sql
   SET search_path = clode;
   SELECT wn.id, wn.name, wn.assigned_agent
   FROM workflow_nodes wn
   JOIN workflows w ON w.id = wn.workflow_id
   WHERE w.application_id = '<test_app_id>'
   ORDER BY wn.unique_id;
   ```
   Expected: every row has `assigned_agent = 'solo'`. Zero rows with
   `developer`, `aramb-deployer`, `local-deployer`, or NULL.

**Negative control:** in a *team-mode* app, ask the agent to create a
workflow. Confirm `create-workflow/SKILL.md` still produces nodes with
team personas (`developer` etc.) — this fix must not bleed across.

### Migration / rollout

- Ships with kairo image rebuild.
- No data backfill, no dispatch-time rescue per user direction.
  Existing solo workflows with team-persona `assigned_agent` values
  fail at dispatch until re-saved (re-save triggers brahmi's
  save-time override). Per user: test workflows only, acceptable.
- **Pairs with brahmi plan issues #7 and #8.** Skill change alone is
  necessary but not sufficient: brahmi must accept `"solo"` cleanly,
  short-circuit master pre-flight for solo apps, and stamp the value
  defensively on save. Ship in the order: brahmi changes → skill
  change → kairo image rebuild → smoke test. See coordination doc.

---

## Repo-internal ship order

1. **Skill edits land first.** They're self-contained text; they don't
   wait on backend changes.
2. **Hold the kairo image rebuild** until brahmi-side issue #7 (workflow
   save defensive override + `"solo"` no-op) and issue #8 (solo
   short-circuit in `ProvisionAgents`) are merged. The skill change
   produces `"solo"` strings in workflows, and brahmi must accept them
   without trying to provision a "solo" agent via master. See
   coordination doc for the gated rebuild step.
3. After brahmi is in dev, rebuild kairo image, bump `.image-tag`,
   re-test all three issues.

## Status convention

Add to the tracker as each issue lands:

```
open → triaged → fix-drafted → fixed → verified
```

This doc represents `triaged` for all three; landing the touch list
moves to `fix-drafted`; PR merge moves to `fixed`; passing the manual
repro on dev moves to `verified`.
