# AGENTS.md — Operating Instructions

## Session Startup

1. Read `IDENTITY.md` — who you are
2. Read `SOUL.md` — your core purpose and philosophy
3. Read `AGENTS.md` — this file — for operating instructions
4. Query Juno for session context: `npx mcporter call juno.get_session_context project_id="<PROJECT_ID>"`
5. Check for relevant gotchas via `juno.get_gotchas`
6. Check for pending tasks via `brahmi.list_tasks`

## Task Protocol

### Receiving Tasks
1. Task arrives with description, `project_id`, `application_id`, and `acceptance_criteria`
2. Read the full task description — understand what "done" looks like
3. Acknowledge: `brahmi.update_my_task(status="in_progress")`
4. **ALWAYS include `application_id` in every `send_message` and `ask_question` call.** Use the `application_id` from your task context. The agent serves multiple apps — without it, messages route to the wrong place.
5. Report start to main chat:
   ```
   npx mcporter call brahmi.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="🔨 Starting: <task summary>" chat_location="main"
   ```

### Executing Work
1. **Read first** — if working in an existing codebase, explore the structure before writing
2. **Check Juno** — query gotchas for the technologies involved
3. **Branch** — create a feature/fix branch per dev-workflow skill conventions
4. **Build** — write the code, tests, docker-compose if needed
5. **Validate** — run tests, verify docker compose up, check acceptance_criteria
6. **Commit** — atomic commits with conventional commit messages

### Reporting Results
On success:
```
npx mcporter call brahmi.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="✅ Done: <task name> — <summary of what was built>" chat_location="main"
npx mcporter call brahmi.update_my_task status="done" summary="<what was built and verified>"
```

On failure:
```
npx mcporter call brahmi.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="❌ Blocked: <task name> — <what went wrong>" chat_location="main"
npx mcporter call brahmi.update_my_task status="failed" summary="<what went wrong and what was tried>"
```

On blockers:
```
npx mcporter call brahmi.update_my_task status="blocked" summary="<what is needed to proceed>"
```

### Pre-Completion Checklist
Before calling `brahmi.update_my_task(status="done")`:
1. ✅ Code compiles / runs without errors
2. ✅ Tests pass (or failures are documented with reasons)
3. ✅ `docker compose up` brings up a working system (if applicable)
4. ✅ All acceptance_criteria from the task are met
5. ✅ Commits are clean and follow conventional commit format
6. ✅ Juno writes completed (gotchas, patterns, or insights stored)
7. ✅ Tunnel-ready: frontend reads API URL from env var, backend reads ALLOWED_ORIGINS from env var, both listed bare in docker-compose.yml environment sections

## Memory

- Daily logs: `memory/YYYY-MM-DD.md`
- Long-term: `MEMORY.md`
- Juno: store gotchas, patterns, and insights for cross-session persistence
- Capture: technology decisions, build issues encountered, dependency quirks, project structure choices

## Tools & Skills

- **brahmi** — task management (receive tasks, report status, communicate with orchestrator)
- **juno** — context memory (store and retrieve patterns, gotchas, insights across sessions)
- **dev-workflow** — development workflow protocol (branching, commits, project structure, docker-compose conventions)
- **aramb-skills** — search, inspect, and download skills from the Skills Registry when a needed skill is not already available locally

## Safety

- Don't exfiltrate data
- `trash` > `rm`
- Never store secrets in code — use `.env` files
- Never deploy to production
- Never modify infrastructure unless explicitly asked
- When in doubt about requirements, ask via brahmi before guessing
