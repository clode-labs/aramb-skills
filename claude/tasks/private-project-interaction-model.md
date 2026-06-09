# aramb-skills — Private Project + Interaction Model

> Per-repo plan. Umbrella: `/Users/siva/workspace/claude/tasks/private-project-interaction-model/README.md`
> Branch: `feat/private-project-model`. Issue log: `claude/tasks/uat-issue-log-2026-06-09.md`.

aramb-skills carries the **agent-side behavior** (prompts/skills baked into the image): how the
agent behaves in a DM, how it decides to pitch into a thread, how it signals silence, and the
per-user system-workflow definitions.

## Scope (3 work items)

### S1 — In-thread "should I respond?" judgment + silence sentinel (D1) — pairs with chil C2
- Add guidance (master/solo prompt or a small skill) for the Slack thread surface: when chil
  forwards a plain thread reply, the agent decides if the message is **addressed to it**
  (continuing its conversation / a question for it) vs **two humans talking**.
- If NOT for it → emit the **silence sentinel** (umbrella fork 3 — exact token TBD with chil,
  e.g. respond with exactly `__STAY_SILENT__` / a typed no-op) so chil posts nothing.
- If for it → respond normally. Explicit @mention always responds (no judgment needed).
- Tune for **precision on silence** (don't barge into human side-chat) without missing
  messages clearly meant for it.
**Acceptance:** in a joined thread, side-chat between two humans → agent stays silent
(emits sentinel); a follow-up clearly aimed at the agent → it answers.

### S2 — DM-as-chat persona (Thread A, Issue #1) — pairs with chil C1
- Ensure the agent behaves as a **coworker in the DM** (matches the welcome-DM promise:
  research, drafts, analysis, automation), operating in the user's **private project**.
- The DM agent can read shared/public data (capability `{public:*, home:<DM>}`) but produces
  per-user output. Make sure the DM persona doesn't fall back to the old slash-command help.
**Acceptance:** DM conversation feels like talking to a teammate, not a command menu.

### S3 — System-workflow definitions (Thread A, registry) — pairs with brahmi W5
- Where the import-workflow / system-workflow prompts live, ensure the discovery (and future
  system) workflow guidance targets a **project-scoped appless** workflow in the **private**
  project and delivers output via **DM** (not a public channel-app).
- Keep the slim-block import contract (already aligned in the prior skill fix).
**Acceptance:** discovery system workflow builds appless in the private project, DM-delivered.

## Out of scope
- chil routing/store, brahmi workflow model, UI.

## Dependencies
S1 must agree with chil C2 on the **exact silence sentinel** token/format. S2 pairs with chil
C1. S3 pairs with brahmi W4/W5.

## Note on benji
If the silence sentinel needs runtime support (carrying a typed "no response" outcome through
the benji run pipeline rather than as plain agent text), add a small benji change to pass it
through to chil's ResponseHandler. Default: try to do it purely at prompt+chil level first;
only touch benji if the plain-text sentinel can't be reliably distinguished.

## Verify
Rebuild image via `cd local-testing && ./build-benji.sh` (bakes local aramb-skills); local-
testing: DM chat works; in-thread silence vs respond works.

## Implementation status (2026-06-09)

- **S1 — in-thread silence sentinel + judgment.** `workspace-master/AGENTS.md`:
  new "Slack surface interaction" section + a leading "Slack in-thread reply gate"
  step in Receiving Requests. On a `<slack-thread-reply>` marker the agent judges
  "is this for me?" and either answers normally or emits exactly `__STAY_SILENT__`
  (the agreed sentinel — chil C2 recognizes it and posts nothing; no in-thread ⏳).
  Tuned for precision on silence. Explicit @mentions never carry the marker.
- **S2 — DM-as-chat persona.** `workspace-master/AGENTS.md`: "Slack DM" subsection
  — a DM routes to the user's private project and is treated like web chat (coworker:
  research/drafts/analysis/automation). Never answer a free-text DM with a slash-command
  help card (slash commands are handled by chil before reaching the agent).
- **S3 — system-workflow definitions.** `import-workflow/SKILL.md`: new "System /
  appless imports" section — discovery and per-user system workflows are
  project-scoped & appless (`application_id` NULL), live in the private project,
  and deliver via DM (chil `chat.send_dm`), never a public channel-app; `get`/`update`
  by `workflow_id` are unchanged. Closing-summary step now handles a missing
  `application_id` (post with `project_id` only). `aramb-workflows/SKILL.md`:
  documents the appless project-scoped `create` path (omit `application_id`, pass
  `project_id`). Slim-block import contract unchanged (already aligned in #78).
- **benji:** not needed — the plain-text `__STAY_SILENT__` sentinel is reliably
  distinguishable at the chil level, so no runtime pass-through change (per "Note on benji").
- **Build/vet:** N/A — pure markdown skills repo (no compilable code/CI). Image bake
  (`build-benji.sh`) deferred per task instructions.
