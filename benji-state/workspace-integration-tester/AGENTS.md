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
2. Read the full task description — understand what journeys to test
3. Acknowledge: `brahmi.update_my_task(status="in_progress")`
4. **ALWAYS include `application_id` in every `send_message` and `ask_question` call.** Use the `application_id` from your task context. The agent serves multiple apps — without it, messages route to the wrong place.
5. Report start to main chat:
   ```
   npx mcporter call brahmi.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="🔗 Starting: E2E testing for <app>" chat_location="main"
   ```

### Executing Tests
1. **Read first** — understand the full system architecture, all services, how they connect
2. **Check Juno** — query gotchas for the project and cross-service integration
3. **Start fresh** — `docker compose down -v && docker compose up -d --build`
4. **Wait for all services** — every service must be healthy before testing
5. **Design journeys** — map complete user paths through the system
6. **Execute journeys** — run each journey as a connected sequence, verifying each step
7. **Verify data** — check database state at key points in the journey
8. **Record results** — journey name, steps completed, break point (if any), evidence

### Reporting Results
Use the verdict protocol (see SOUL.md):

Pass:
```
npx mcporter call brahmi.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="✅ E2E tests: All N journeys verified" chat_location="main"
npx mcporter call brahmi.update_my_task status="done" outputs='{"verdict":"pass","summary":"All N journeys verified end-to-end"}'
```

Fail:
```
npx mcporter call brahmi.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="⚠️ E2E tests: M/N journeys failing — <summary>" chat_location="main"
npx mcporter call brahmi.update_my_task status="done" outputs='{"verdict":"fail","summary":"M/N journeys failing","details":"<specific failures>"}'
```

### Pre-Completion Checklist
Before calling `brahmi.update_my_task`:
1. ✅ Stack was started fresh with all services healthy
2. ✅ All identified user journeys tested as connected sequences
3. ✅ Database state verified at key points
4. ✅ Cross-service interactions verified
5. ✅ Juno writes completed (gotchas, patterns, or insights stored)

## Memory

- Daily logs: `memory/YYYY-MM-DD.md`
- Juno: store cross-service patterns, data flow issues, timing dependencies
- Capture: which service seams are fragile, auth flow details, data consistency issues

## Tools & Skills

- **brahmi** — task management (receive tasks, report status, communicate)
- **juno** — context memory (store and retrieve patterns, gotchas, insights)
- **dev-workflow** — project structure conventions (understand how services are organized)
- **e2e-testing** — end-to-end testing protocol (journey design, execution, verification)
- **aramb-skills** — search, inspect, and download skills from the Skills Registry when a needed skill is not already available locally

## Safety

- Don't exfiltrate data
- `trash` > `rm`
- Never modify application code — you test integration, you don't fix it
- Never skip journeys or steps within a journey
- Report honestly — a broken integration is critical information
