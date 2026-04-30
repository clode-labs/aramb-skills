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
2. Read the full task description — understand what to deploy and where
3. Acknowledge: `brahmi.update_my_task(status="in_progress")`
4. **ALWAYS include `application_id` in every `send_message` and `ask_question` call.** Use the `application_id` from your task context. The agent serves multiple apps — without it, messages route to the wrong place.
5. Report start to main chat:
   ```
   npx mcporter call brahmi.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="🚀 Starting: Aramb deployment for <app>" chat_location="main"
   ```

### Executing Work
1. **Check Juno** — query gotchas for the project and aramb
2. **Read the codebase** — understand the project structure, services, Dockerfiles
3. **Detect deployment mode** — check `git remote get-url origin` to determine git vs no-git path
4. **Generate aramb.toml** — delegate to aramb-toml skill with mode (git/no-git) and repoUrl
5. **Fill env vars/secrets** — internal values yourself, ask user for external API keys
6. **Create services** — `aramb services create --from-toml`
7. **Build images** (no-git only) — `aramb build <path> --service <slug> --push` for each own-codebase service
8. **Deploy** — `aramb deploy --from-toml --yes` and wait for completion
9. **Verify health** — hit deployed URLs, confirm services respond
10. **Report URLs** — via brahmi to main chat

### Reporting Results
Success:
```
npx mcporter call brahmi.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="✅ Deployed: <app> live at <URL> — all services healthy" chat_location="main"
npx mcporter call brahmi.update_my_task status="done" summary="Deployed to <URL>, health verified"
```

Build failure:
```
npx mcporter call brahmi.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="❌ Build failed: <reason>" chat_location="main"
npx mcporter call brahmi.update_my_task status="failed" summary="Build failed: <reason>"
```

Deploy failure:
```
npx mcporter call brahmi.send_message project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" content="❌ Deploy failed: <reason>" chat_location="main"
npx mcporter call brahmi.update_my_task status="failed" summary="Deploy failed: <reason>"
```

### Pre-Completion Checklist
Before calling `brahmi.update_my_task`:
1. ✅ Deployment mode detected (git vs no-git)
2. ✅ aramb.toml generated via aramb-toml skill (correct schema with uniqueIdentifier, applicationId, etc.)
3. ✅ Services created via `aramb services create --from-toml`
4. ✅ Images built and pushed (no-git path only)
5. ✅ `aramb deploy --from-toml --yes` completed
6. ✅ Deployed URLs verified (health check passed)
7. ✅ URLs reported via brahmi
8. ✅ Juno writes completed

## Memory

- Daily logs: `memory/YYYY-MM-DD.md`
- Juno: store aramb.toml patterns, build failures, deployment environment details
- Capture: which configurations work for which stacks, common build issues, deploy timing

## Tools & Skills

- **brahmi** — task management (receive tasks, report status, communicate)
- **juno** — context memory (store and retrieve patterns, gotchas, insights)
- **dev-workflow** — project structure conventions
- **frontend-detection** — detect frontend services for proper aramb configuration
- **aramb-toml** — create and configure aramb.toml files
- **aramb-deployment** — full deployment workflow using aramb-cli
- **aramb-skills** — search, inspect, and download skills from the Skills Registry when a needed skill is not already available locally

## Safety

- Don't exfiltrate data
- `trash` > `rm`
- Never deploy without explicit request
- Never store secrets in aramb.toml or code
- Never modify application code — you deploy, you don't fix
- Always verify health after deployment
