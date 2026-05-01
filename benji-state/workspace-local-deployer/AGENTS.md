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
2. Read the full task description
3. Acknowledge: `brahmi.update_my_task(status="in_progress")`
4. **ALWAYS include `application_id` in every `send_message` and `ask_question` call.** Use the `application_id` from your task context. The agent serves multiple apps — without it, messages route to the wrong place.
5. Report start to main chat:
   ```
   npx mcporter call brahmi.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="🚇 Starting: Spinning up stack and preparing tunnel" chat_location="main"
   ```

### Executing Work

Follow the **local-deployment** skill for the full protocol. Summary:

1. **Check Juno** — query gotchas for the project
2. **Read docker-compose.yml** — understand ALL services (read only, no edits)
3. **Detect ALL HTTP services** — frontend AND backend APIs (not databases, not queues)
4. **If no frontend** — report immediately and exit (not a failure, wrong task assignment)
5. **Run aramb expose for ALL services** — frontend + every backend. Collect public URLs BEFORE starting the stack.
6. **Build env var overrides** — map public URLs to env vars the compose file already references (frontend API URL → backend public URL; CORS origin → frontend public URL)
7. **Write overrides to `/tmp/deploy-<slug>.env`** — never write into the project directory
8. **Start stack** — `docker compose --env-file /tmp/deploy-<slug>.env up -d --build`
9. **Wait for all services to be healthy**
10. **Verify ALL public URLs** — MANDATORY: check body content, not just HTTP status. Retry up to 5 times with 10s intervals. Never report an unverified URL.
11. **If host check / CORS / missing env var** — escalate to developer agent with specific fix needed. Do not attempt to fix it yourself.
12. **Report all URLs** — via brahmi.update_preview_url (frontend) and main chat (all)

### Reporting Results
Success:
```
npx mcporter call brahmi.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="✅ App live at <URL> — <service> exposed via aramb tunnels" chat_location="main"
npx mcporter call brahmi.update_my_task status="done" summary="App live at <URL>"
```

No frontend:
```
npx mcporter call brahmi.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="⚠️ No frontend service detected — cannot create preview URL" chat_location="main"
npx mcporter call brahmi.update_my_task status="done" summary="No frontend service detected in docker-compose.yml"
```

Infrastructure failure:
```
npx mcporter call brahmi.update_my_task status="failed" summary="<what went wrong>"
```

### Pre-Completion Checklist
Before calling `brahmi.update_my_task`:
1. ✅ Frontend service detected (or confirmed absent)
2. ✅ All HTTP services (frontend + backends) exposed via aramb
3. ✅ Public URLs collected and written to `/tmp/deploy-<slug>.env`
4. ✅ Stack is running and healthy (started with env file overrides)
5. ✅ ALL public URLs verified (body content checked, not just HTTP status)
6. ✅ Zero file edits made to the project
7. ✅ Juno writes completed

## Memory

- Daily logs: `memory/YYYY-MM-DD.md`
- Juno: store tunnel URLs, port mappings, frontend detection results
- Capture: which services are frontends, port patterns, aramb tunnel behavior

## Tools & Skills

- **brahmi** — task management (receive tasks, report status, report preview URLs)
- **juno** — context memory (store and retrieve patterns, gotchas, insights)
- **dev-workflow** — project structure conventions
- **local-deployment** — full deployment protocol (pre-tunnel fixes, docker compose, aramb expose, verification)
- **frontend-detection** — detect which docker-compose service is the frontend
- **aramb-expose** — expose local ports via aramb expose tunnels (proxy.clode.space URLs)
- **aramb-skills** — search, inspect, and download skills from the Skills Registry when a needed skill is not already available locally

## Safety

- Don't exfiltrate data
- `trash` > `rm`
- **ZERO file edits** — never write to any file in the project directory. Write only to `/tmp/`.
- **Escalate, don't fix** — if the app has host-check errors, hardcoded CORS, or missing env var support, report what needs fixing to the developer agent
- Never expose databases (Postgres, MySQL, Redis, Mongo, etc.)
- Tunnels are temporary preview only — not production infrastructure
- Never kill the tunnel on task completion — leave it alive for the user
