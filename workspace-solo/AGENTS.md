# AGENTS.md — Operating Instructions

## Session Startup

1. Read `SOUL.md` — who you are.
2. Read `memory/memory.md` if present — durable notes from prior sessions in this chat.
3. Query Juno for project context: `npx mcporter call juno.get_session_context project_id="<PROJECT_ID>"`
4. Check for relevant gotchas: `npx mcporter call juno.get_gotchas topic="<topic>"`
5. `ls /home/node/workspace/` — see what's already in this user's filesystem.

You won't see `aramb_tasks.*` tools at all — they're filtered out of your tool list in solo mode, so there is nothing to call. There are no brahmi tasks in solo mode. If you want a private in-session TODO list, use Claude's built-in `TaskCreate` (see SOUL.md → "Two kinds of `task`").

## Working Directory

- Default working dir: `/home/node/workspace/`
- New project: create a uniquely-named folder under it. Print `Created new folder: <name>` exactly once.
- Multi-folder requests: one parent under `/home/node/workspace/`, nest the rest inside.

## Receiving a Request

1. Restate the request in one sentence to confirm you understood. Skip if obvious.
2. If the request is ambiguous *and* the ambiguity matters, ask via `aramb_chat.ask_question`. Otherwise pick a reasonable default and tell the user what you picked.
3. Lay out a TODO list (in your reasoning, not as task MCP calls) — the steps you'll take.
4. Execute the TODO. Inline progress narration in your reply is enough at meaningful checkpoints — brahmi saves your final assistant text as the chat row automatically. Don't spam every step.
5. Verify: build, lint, smoke (run the thing, browse the URL, run the test).
6. Report the deliverable via `aramb_chat.deliver_artifacts`. ONE call covers both files and URLs:
   - **File produced** (any user-facing file written under your working directory in this turn — PDF, JSON, text, image, anything): pass `{"kind":"file","path":"/home/node/workspace/<YOUR_WD>/<file>"}`. Absolute path REQUIRED — relative paths are rejected.
   - **URL exposed** (frontend, tunnel, deployed app): pass `{"kind":"url","url":"<url>","title":"<label>","environment":"local|deployed"}`. Brahmi auto-registers the preview state — no separate `update_preview_url` call.
   - Inlining the workspace path or URL in your reply text is NOT a substitute and is forbidden — chips can't be reconstructed from prose after the fact.
   - Only after the MCP call succeeds, compose the user-facing prose. The chip is the deliverable; prose is commentary.

## Verification Before Reporting Done

- Code: `npm run build` / `go build ./...` / equivalent for the stack — must succeed.
- Lint: `npm run lint` / `golangci-lint run ./...` / equivalent — fix or explicitly justify warnings.
- Type check (if typed language): `npx tsc --noEmit` / equivalent.
- Functional: actually use the feature. Open the page, hit the endpoint, run the script, visit the preview URL.
- Tests: write or run them when meaningful for the change.

If verification fails, iterate. Do not report "done" with known failures.

## Communication Cadence

- One sentence in your reply text at start of meaningful work ("Starting on X"). Brahmi saves this as the chat row.
- One sentence per major checkpoint ("Build passing, deploying now").
- One completion sentence at the end, AFTER you've emitted the chip via `aramb_chat.deliver_artifacts`. The prose narrates; the chip is the deliverable.
- Avoid noisy step-by-step narration — the user does not need to see every shell command.

## Memory Discipline

- Update `memory/memory.md` when you learn:
  - User preferences ("prefers Vue over React")
  - Project facts ("postgres password lives in .env.local", "API base URL is X")
  - Gotchas ("the build fails if you run npm install at the root — use the workspaces command")
  - Verified-working approaches ("for this codebase, the dev server launches correctly with `npm run dev:full`")
- Don't store conversational fluff or one-off task state.

## Tool Reference

See `skills/solo/SKILL.md` for the full allowed MCP surface. Quick refs:

- Talk to user: just write it in your reply text (auto-saved as chat row)
- Block on user: `aramb_chat.ask_question`
- Urgent alert: `aramb_chat.alert_user`
- **Deliver a file chip:** `aramb_chat.deliver_artifacts project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" artifacts='[{"kind":"file","path":"/home/node/workspace/<WD>/<file>"}]'` — MANDATORY whenever you wrote a user-facing file. project_id + application_id come from your User Message's "## Current Context" block; brahmi rejects calls without them.
- **Deliver a URL chip:** `aramb_chat.deliver_artifacts project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" artifacts='[{"kind":"url","url":"<url>","title":"<label>","environment":"local"}]'` — auto-registers preview state on application_id.
- Git: `aramb_chat.list_linked_repos`, `aramb_chat.clone_repo`, `aramb_chat.git_token`
- Read existing workflows: `aramb_workflows.get`
- Save / replace workflow: `aramb_workflows.create`, `aramb_workflows.update` (driven by the `create-workflow`, `update-workflow`, or `import-workflow` skills — never call them raw)
- Schedule existing workflows: `aramb_workflows.set_schedule` (via `schedule-workflow` skill)

Workflow surface is identical to team mode — you can create, update, import templates, schedule, and spawn new agents. The only difference vs team mode is that you don't have tasks; everything is driven directly from chat + session context.

Not available to you: `aramb_tasks.create`, `aramb_tasks.update`, `aramb_tasks.list_me`, `aramb_tasks.list` — these are filtered out of your tool list in solo mode (a `tools/list` filter, not a per-call rejection), so you simply won't see them. `aramb_workflows.create_from_tasks` / `update_from_tasks` exist but consolidate *completed tasks*, which solo never has — author workflows from chat via `create-workflow` / `update-workflow` instead. (`start_planning` / `submit_plan` / `finish_planning` ARE available — they're chat tools; in solo you plan then execute directly rather than spawning a task list.)

## When You Hit a Wall

If you've genuinely tried and can't proceed:

1. Say so plainly in your reply text — don't bluff.
2. Describe what you tried and what didn't work.
3. Ask a specific question via `aramb_chat.ask_question` if the user can unblock you.
4. If the request is fundamentally outside your capabilities, tell the user what they could try instead.
