---
name: planning
description: >
  Interactive planning for complex requests — QnA, plan file, structured approval.
---

# Planning Skill

Use this skill when the request is complex, ambiguous, multi-domain, or the user says "plan this". Skip planning for simple, well-defined tasks or when the user says "just do it".

## Protocol

### 1. Create the Plan File FIRST

You MUST create the plan file before calling start_planning. This is MANDATORY — VS Code opens immediately and needs the file to exist.

```bash
mkdir -p <APP_WORKING_DIR>/.planning
cat > <APP_WORKING_DIR>/.planning/<descriptive-name>.md << 'PLAN'
# Plan: [Title]

## What We're Building
[Initial understanding of the request]

## Open Questions
[What needs clarification]

## Decisions Made
[Updated after each answer]
PLAN
```

Never reuse filenames. Structure is freeform — let it emerge from the conversation.

### 2. Start Planning

Call `brahmi.start_planning` with `file_path=".planning/<descriptive-name>.md"` — this opens the plan file in VS Code for the user. Do NOT send any messages before this call.

### 3. Interactive Q&A

Ask ONE question at a time using `brahmi.ask_question`. Never inline numbered-list questions in your reply text — they store as plain text with no `options`, the frontend cannot render a picker, and the user reply comes back as unstructured free text.

Pass choices as the `options` array — do NOT inline them as a numbered list in the `question` body. Brahmi stores the array structurally so the UI renders a real choice picker and the answer comes back as `selected_option`.

```bash
npx mcporter call brahmi.ask_question \
  project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" \
  question="Question 1/5 — What authentication approach should we use?" \
  options='["JWT tokens — stateless, good for APIs", "Session-based — simpler, server-side state", "OAuth 2.0 — delegate to Google/GitHub"]'
```

Rules:
- ALWAYS `brahmi.ask_question`. Never inline-numbered-list questions in your reply text.
- Include the progress marker in the `question` string (Question 1/5, 2/5, …) — count can change dynamically.
- 2-4 options per question. Each option is a short label with a brief pro/con after an em-dash.
- After each answer: update the plan file, then ask the next question.
- The user is watching the plan file in VS Code — keep it current.

### 3b. Handling "Surprise me!" / defaults

If the user says "surprise me", "use defaults", "you decide", or similar at ANY point during Q&A:
- **STOP asking questions immediately** — do not ask any more questions
- For ALL remaining unanswered questions, choose the most common/sensible default
- Update the plan file with all decisions (note which were auto-decided)
- Proceed directly to Step 4 (Submit the Plan)

### 4. Submit the Plan

When all questions are answered, call `brahmi.submit_plan` with structured data:
- `summary`: one-line description
- `approach`: technical approach
- `agents`: `[{name, role}]`
- `tasks`: `[{unique_id, name, description, assigned_agent, dependencies}]`
  - `unique_id`: sequential integers starting at 1 (NEVER 0)
  - `dependencies`: array of unique_ids. Testing MUST depend on build. Deploy MUST depend on tests.
- `key_decisions`: `[{decision, rationale}]`

**CRITICAL: After calling `submit_plan`, STOP. Do not send any more messages. Wait for the user's response.**

### 5. Handle User Response

The user responds via chat message:

- **Approved** (e.g., "Plan approved, proceed further!", "looks good", "go ahead"):
  1. Call `brahmi.finish_planning`
  2. Call `brahmi.create_tasks` with the same tasks from your plan
  3. Proceed to execution

- **Modification requested** (user sends feedback like "change X to Y"):
  1. Update the plan file with revisions
  2. Call `brahmi.submit_plan` again with updated data
  3. STOP and wait again

- **Rejected** (user says "no", "scrap this", "start over"):
  1. Ask the user what they'd prefer instead
