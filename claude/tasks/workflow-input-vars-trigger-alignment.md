# Workflow run inputs and trigger-shape alignment — aramb-skills slice

> Canonical design doc: `/Users/siva/workspace/claude/tasks/workflow-input-vars-trigger-alignment.md`
>
> This file holds the aramb-skills-scoped slice. Read the canonical doc for issue framing, decisions, and the full architectural picture.

## Summary

aramb-skills owns the prompt rewrites that make workflows trigger-aware from authoring time: rewriting create/update/import-workflow skills to drop placeholders and ground slugs via the new `aramb_toolkits.*` MCP, plus authoring a new `configure-trigger` skill that wraps the new `aramb_triggers.*` MCP write tools.

## Cross-repo coordination

- **Phase 4 ships together with brahmi Phases 1 + 4 (schema) + 8.** Skills emitting placeholders against a brahmi that no longer substitutes = workflows dispatch literal `{{env.KEY}}` strings to the agent. Skills declaring `env_variables` get rejected at the MCP layer (brahmi Phase 4 validator).
- **Phase 4.5 depends on brahmi's `aramb_toolkits.*` (Phase 3, read tools), `aramb_triggers.*` (Phase 4.5, write tools), AND the authorization seam on `WorkflowTriggerService`.** Skill cannot call tools that don't exist; will produce trigger rows that bypass authorization if the seam isn't in.

## Phases

### Phase 4 — Authoring skills sweep

Rewrite `create-workflow/SKILL.md`, `update-workflow/SKILL.md`, `import-workflow/SKILL.md` to:

1. **Ban placeholder syntax in node prompts.** No `{{env.KEY}}`, no `{{input.KEY}}`, no template substitution of any kind. The brahmi MCP schemas reject prompts matching `\{\{\s*env\.[A-Za-z_]` (brahmi-side Phase 4 validator) — skills must pass by construction, not rely on the validator as a safety net.
2. **Call `aramb_toolkits.list_triggers` before drafting** to ground toolkit + trigger slugs in real catalog values. Today the skills tell the agent "slugs are uppercase, exactly as Composio reports them" (`create-workflow/SKILL.md:161`) but provide no tool to look them up — the agent hallucinates slugs from prose.
3. **Emit per-step singular `toolkit`** alongside the existing `required_toolkits[]` array. Invariant: `toolkit ∈ required_toolkits`. The brahmi MCP schemas reject violations.
4. **Omit `env_variables` from emitted workflows entirely.** The column has no runtime path in v2 (Decision 1); declaring no-op entries misleads users ("I added your API_KEY to env_variables — but nothing reads it"). The brahmi MCP schemas reject submissions with non-empty `env_variables`.
5. **Write node prompts that describe what to do with the context that arrives in `<run_input>`** — e.g., "the user's instruction or the trigger payload will describe the work; extract the issue URL, repo, etc. from it". Trust the agent to parse JSON or free text.
6. **Step 1's prompt explicitly tells the agent to distill input intent into its output.** Downstream steps consume the parent step's `outputs.summary` (brahmi Phase 1: `<run_input>` is first-step-only). Step 1 is responsible for propagating relevant context — if step 1 fails to summarize, step N loses visibility.
7. **Tolerate empty `<run_input>` by failing gracefully at the agent layer** with a clear "I don't have anything to work on" message — not pre-flight rejection.

Files:

- `/Users/siva/workspace/aramb-skills/create-workflow/SKILL.md`
- `/Users/siva/workspace/aramb-skills/update-workflow/SKILL.md`
- `/Users/siva/workspace/aramb-skills/import-workflow/SKILL.md`

Success: end-to-end "create a github auto-fix workflow" through the master agent produces a workflow where every step has `toolkit = "GITHUB"`, zero placeholders in prompts, zero `env_variables` entries; importing a JSON with `{{env.KEY}}` returns 4xx; step 1's prompt explicitly mentions distilling input into output.

### Phase 4.5 — New `configure-trigger` skill

Author `/Users/siva/workspace/aramb-skills/configure-trigger/SKILL.md` to handle all non-cron trigger creation/update/deletion from natural-language intent. Cron stays on `schedule-workflow` (different persistence: flat columns on `workflows` vs a `workflow_triggers` row).

Skill flow:

1. Parse user intent ("I want this to fire when a github issue is created").
2. Call `aramb_toolkits.list_toolkits` — narrow to the relevant toolkit.
3. Call `aramb_toolkits.list_triggers(<toolkit>)` — read names + descriptions.
4. Pick a candidate; ask a clarifying question via `aramb_chat.ask_question` if ambiguous ("issue created" vs "issue assigned to you").
5. Call `aramb_triggers.create` to persist (write tools live in `aramb_triggers.*`, not `aramb_toolkits.*` — read/write split for security and discoverability).
6. Poll `aramb_triggers.status` until `active`; only then report success to the user.

**Composio lifecycle awareness** — the skill prompt must include:

- Creating a `composio_event` trigger is asynchronous upstream. Row enters `pending_create`, then becomes `active` after `toolkitProxy.CreateTriggerInstance` succeeds. The skill must NOT report success on `pending_create`.
- Failure paths: brahmi rolls back on Composio create failure or activation failure (deletes placeholder + upstream). The skill must surface these as "trigger setup failed: <reason>" rather than declare success.
- Authorization failure: the brahmi authorization seam (brahmi Phase 4.5) rejects calls for workflows whose application the agent doesn't own. The skill must surface this as a clear "you don't have permission to configure triggers on this workflow" rather than retrying.

**Disambiguation from `schedule-workflow`**: when the user's intent is ambiguous between scheduled vs event-driven ("run this every day" → cron; "run this every push" → composio_event), the skill must either route or hand off — do not silently configure both. Recommended router rule: if intent mentions a wall-clock schedule (weekly/daily/hourly/cron expression), defer to `schedule-workflow`; if intent mentions an event (issue created, push, message received), handle here.

Success: end-to-end "fire this when a github issue is created" through the master agent produces a `workflow_triggers` row (`kind=composio_event`, `slug=GITHUB_NEW_ISSUE`) and reports `active` status to the user, without the user touching the FE picker.

## Skill burden — the load-bearing assumption

This v2 design rests on the skills understanding the new contract end-to-end. brahmi Phase 8 deletes the runtime gates that used to protect against skill bugs — if skills emit placeholders, declare env_variables, or pick wrong toolkits, the failures surface at the agent layer with no rescue.

The brahmi MCP author-time validators (placeholder regex + empty env_variables + toolkit invariant) are the only remaining backstop. Skills should be authored to pass them by construction, not to rely on them as a safety net.

## Branch naming

- `feat/run-input-phase-4-skills` — rewrites of create/update/import-workflow
- `feat/run-input-phase-4.5-configure-trigger` — new skill

Phases 4 + 4.5 ride a single integration branch `feat/run-input-cutover-skills` since they share the cutover window.

## Lint

Markdown lint via existing aramb-skills CI (if configured). Otherwise manual review with the `local-testing` MCP harness — running each skill against a fresh workflow and inspecting the resulting brahmi MCP tool calls.

## Test plan

- **Phase 4 (create-workflow)**: Run the skill against the local-testing harness with prompt: *"Build me a workflow that auto-fixes GitHub issues by opening a PR."* Verify: every node has `toolkit = "GITHUB"`, no `{{env.KEY}}` anywhere, `env_variables` is empty, prompts reference `<run_input>` as the source of issue details, step 1's prompt instructs distillation for downstream.
- **Phase 4 (import-workflow)**: Submit a workflow JSON with `{{env.KEY}}` in a node prompt. Verify the import returns a clean 4xx error to the user.
- **Phase 4 (update-workflow)**: Update an existing workflow's node prompt to include `{{env.KEY}}`. Verify rejection.
- **Phase 4.5**: Run the configure-trigger skill with prompt: *"Make it fire whenever a new GitHub issue is created."* Verify: `aramb_toolkits.list_triggers("GITHUB")` is called, `aramb_triggers.create` is called with `slug=GITHUB_NEW_ISSUE`, `aramb_triggers.status` is polled until `active`, success is reported only after activation. Verify disambiguation by prompting *"run this workflow daily"* — skill defers to `schedule-workflow`.

## Risks specific to aramb-skills

- **Skill prompts are the contract.** Misspelled tool names, missing instructions, or ambiguous guidance produce workflows that fail at the agent layer post-cutover with no recovery.
- **Authorization seam on the brahmi side is invisible to the skill** but enforced at the MCP boundary. The skill must surface "you don't have permission" cleanly when brahmi rejects the call rather than retrying or fabricating success.
- **Async lifecycle in `configure-trigger`** — the skill must NOT report success on `pending_create`. Skills that rush past the activation poll will produce stale claims.
- **Two-skill split for triggers** is sustainable if the disambiguation rule is clear in both `configure-trigger` and `schedule-workflow` prompts. Drift between the two routing rules will produce ambiguous user experiences ("Sometimes the cron skill takes over, sometimes the trigger skill does").
