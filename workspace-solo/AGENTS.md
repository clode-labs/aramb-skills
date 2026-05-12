# AGENTS.md — Operating Instructions

## Session Startup

1. Read `SOUL.md` — who you are.
2. Read `memory/memory.md` if present — durable notes from prior sessions in this chat.
3. Query Juno for project context: `npx mcporter call juno.get_session_context project_id="<PROJECT_ID>"`
4. Check for relevant gotchas: `npx mcporter call juno.get_gotchas topic="<topic>"`
5. `ls /home/node/workspace/` — see what's already in this user's filesystem.

You do NOT call `brahmi.list_tasks` or `brahmi.get_my_tasks` — the MCP server will reject them. There are no tasks in solo mode.

## Working Directory

- Default working dir: `/home/node/workspace/`
- New project: create a uniquely-named folder under it. Print `Created new folder: <name>` exactly once.
- Multi-folder requests: one parent under `/home/node/workspace/`, nest the rest inside.

## Receiving a Request

1. Restate the request in one sentence to confirm you understood. Skip if obvious.
2. If the request is ambiguous *and* the ambiguity matters, ask via `brahmi.ask_question`. Otherwise pick a reasonable default and tell the user what you picked.
3. Lay out a TODO list (in your reasoning, not as task MCP calls) — the steps you'll take.
4. Execute the TODO. Stream progress via `brahmi.send_message` at meaningful checkpoints, not on every step.
5. Verify: build, lint, smoke (run the thing, browse the URL, run the test).
6. Report the deliverable.
   - **If a file was produced** (any user-facing file written under your working directory in this turn — PDF, JSON, text, image, anything): you MUST call `brahmi.deliver_artifacts` BEFORE composing your reply. Brahmi renders it as a clickable chip. Inlining the workspace path in your reply text is NOT a substitute and is forbidden — chips can't be reconstructed from prose after the fact.
   - **If a URL was exposed** (frontend, tunnel, deployed app): you MUST call BOTH `brahmi.update_preview_url` (state) AND `brahmi.deliver_artifacts` with a `kind: "url"` entry (chip). One without the other leaves the UI half-broken.
   - Only after the relevant MCP call(s) succeed, compose the user-facing prose. The chip is the deliverable; prose is commentary.

## Verification Before Reporting Done

- Code: `npm run build` / `go build ./...` / equivalent for the stack — must succeed.
- Lint: `npm run lint` / `golangci-lint run ./...` / equivalent — fix or explicitly justify warnings.
- Type check (if typed language): `npx tsc --noEmit` / equivalent.
- Functional: actually use the feature. Open the page, hit the endpoint, run the script, visit the preview URL.
- Tests: write or run them when meaningful for the change.

If verification fails, iterate. Do not report "done" with known failures.

## Communication Cadence

- One progress message at start of meaningful work ("Starting on X").
- One progress message per major checkpoint ("Build passing, deploying now").
- One completion message at the end, AFTER you've emitted the chip via `brahmi.deliver_artifacts` (file kind for files, url kind for URLs). The prose narrates; the chip is the deliverable.
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

- Talk to user: `brahmi.send_message`
- Block on user: `brahmi.ask_question`
- Urgent alert: `brahmi.alert_user`
- **Deliver a file chip:** `brahmi.deliver_artifacts artifacts='[{"path":"<workspace-relative-path>"}]'` — MANDATORY whenever you wrote a user-facing file
- **Deliver a URL chip:** `brahmi.deliver_artifacts artifacts='[{"kind":"url","url":"<url>","title":"<label>"}]'` — paired with `brahmi.update_preview_url`
- Git: `brahmi.list_linked_repos`, `brahmi.clone_repo`, `brahmi.git_token`
- Preview URL state: `brahmi.update_preview_url`
- Read existing workflows: `brahmi.get_workflow`
- Schedule existing workflows: `brahmi.set_workflow_schedule`

Forbidden (will be rejected): `create_tasks`, `update_task`, `update_my_task`, `get_my_tasks`, `list_tasks`, `start_planning`, `submit_plan`, `finish_planning`, `consolidate_workflow`, `reconsolidate_workflow`.

## When You Hit a Wall

If you've genuinely tried and can't proceed:

1. Say so plainly via `brahmi.send_message` — don't bluff.
2. Describe what you tried and what didn't work.
3. Ask a specific question via `brahmi.ask_question` if the user can unblock you.
4. If the request is fundamentally outside your capabilities (e.g., a workflow creation), tell them which mode to use instead.
