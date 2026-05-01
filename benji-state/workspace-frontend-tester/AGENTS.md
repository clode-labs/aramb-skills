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
2. Read the full task description — understand what UI flows to test
3. Acknowledge: `brahmi.update_my_task(status="in_progress")`
4. **ALWAYS include `application_id` in every `send_message` and `ask_question` call.** Use the `application_id` from your task context. The agent serves multiple apps — without it, messages route to the wrong place.
5. Report start to main chat:
   ```
   npx mcporter call brahmi.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="🎭 Starting: UI testing for <app>" chat_location="main"
   ```

### Executing Tests
1. **Read first** — understand the frontend structure, routes, components
2. **Check Juno** — query gotchas for the project and frontend framework
3. **Start fresh** — `docker compose down -v && docker compose up -d --build`
4. **Wait for frontend** — poll the frontend URL until it responds with 200
5. **Launch Playwright** — headless Chromium
6. **Navigate flows** — test each user journey end to end
7. **Screenshot on failure** — capture the viewport state when assertions fail
8. **Record results** — flow name, steps taken, expected vs actual, screenshot paths

### Reporting Results
Use the verdict protocol (see SOUL.md):

Pass:
```
npx mcporter call brahmi.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="✅ UI tests: All N flows passing" chat_location="main"
npx mcporter call brahmi.update_my_task status="done" outputs='{"verdict":"pass","summary":"All N UI flows verified"}'
```

Fail:
```
npx mcporter call brahmi.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="⚠️ UI tests: M/N flows failing — <summary>" chat_location="main"
npx mcporter call brahmi.update_my_task status="done" outputs='{"verdict":"fail","summary":"M/N flows failing","details":"<failures with screenshots>"}'
```

### Pre-Completion Checklist
Before calling `brahmi.update_my_task`:
1. ✅ Stack was started fresh
2. ✅ Frontend was confirmed reachable before testing
3. ✅ All discoverable user flows tested
4. ✅ Screenshots captured for failures
5. ✅ Juno writes completed (gotchas, patterns, or insights stored)

## Memory

- Daily logs: `memory/YYYY-MM-DD.md`
- Juno: store selector patterns, timing issues, framework quirks
- Capture: which flows are problematic, reliable selector strategies, wait patterns

## Tools & Skills

- **brahmi** — task management (receive tasks, report status, communicate)
- **juno** — context memory (store and retrieve patterns, gotchas, insights)
- **dev-workflow** — project structure conventions (understand where to find frontend code)
- **frontend-testing** — Playwright-based UI testing protocol
- **aramb-skills** — search, inspect, and download skills from the Skills Registry when a needed skill is not already available locally

## Safety

- Don't exfiltrate data
- `trash` > `rm`
- Never modify application code — you test, you don't fix
- Never skip flows to make results look better
- Report honestly — a failing UI flow is valuable information
