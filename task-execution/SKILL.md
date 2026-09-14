---
name: task-execution
description: >
  How you RECEIVE a task and report on it honestly. The counterpart to
  `delegation`: that skill is how work is handed out, this is how the worker
  takes it, works it, and closes it. Covers your `task_id` and the
  `context_drift` rejection, progress without a status change, the quality gate
  (`validating` vs `done`) and couriering the audit verdict, the `artifacts`
  payload, blocking and escalating, and naming the ending honestly. Use whenever
  a task was dispatched to you. NOT for handing work to someone else
  (`delegation`), NOT for coming back to a job later (`wake-subscriptions`).
---

# Task execution — receiving the work, reporting what is true

Someone delegated this to you and **they still own the outcome**. Your job is to do the
work and put back a record they can verify: the evidence, or the honest blocker. What
the user eventually hears is written by the agent that dispatched you — not by you.

Your record is the task row. It survives your session, a compaction, and your death.
The transcript does not.

> **How you call these.** `aramb_mcp.*` is **not** in your tool list — it never is. You
> reach it by running `npx mcporter call` in **Bash**, exactly as shown. That IS the
> sanctioned client, not a workaround. Arguments are `key="value"`; an array or object
> argument is a JSON string (`outputs='{...}'`); `--output` is not supported.
> What stays forbidden is going *around* the client: never `curl` the MCP endpoint,
> never read `mcporter.json` or any bearer token, never script your own auth.

## Your task id — copy it, never guess it

Your dispatch prompt carries it: the **"## Current Context"** block, `Task ID:` line.
Save it the first time you see it and pass it on **every** `aramb_mcp.tasks_update`
call, together with `project_id`. There is no session-implicit variant.

**Passing any other id is rejected as `context_drift`** — loudly and finally. The
runtime resolves the run you were dispatched in and compares its `task_id` to the one
you sent; a mismatch writes nothing and your work goes unrecorded. It is not a
probe-and-correct contract, so do not experiment with ids: re-read your own dispatch
prompt. The same rejection fires if your session was never dispatched against a task at
all — in that case you are not the worker here, and `aramb_mcp.tasks_update` is not
yours to call.

## Not the same as the built-in `TaskCreate`

`aramb_mcp.tasks_*` and Claude's built-in `TaskCreate` / `TaskUpdate` / `TaskList` share
a word and nothing else.

- **`aramb_mcp.tasks_*`** is the platform. Each call writes a row that outlives the
  session, is visible to the delegator and the UI, and is how work is persisted and
  reported. This is the one that counts.
- **`TaskCreate`** is an in-session scratchpad — gone when the run ends, visible only to
  you, never reaching the platform.

Tracking your own steps → `TaskCreate`. Reporting the actual work → `aramb_mcp.tasks_*`.
Closing your scratchpad closes nothing real.

## Read the brief before you start

Your dispatch prompt carries the task's `goal` (**the user's own words**, not a
paraphrase) and its `acceptance_criteria`.

**The acceptance criteria are the definition of done — not the description.** They are
what a checker evaluates and what any watcher's trigger reads. Before you start, know
exactly what observable state closes this, and if the criteria and the description
disagree, the criteria win.

If the brief names a **working subfolder** (`in \`<subfolder>/\``, `from \`…\``,
`against \`…\``), `cd` into it first. The application working directory
(`/home/node/workspace/<app-slug>/`) is a **container** holding sibling subfolders —
writing at its root clobbers other work.

## While you work — progress without a status change

`status` is optional on `aramb_mcp.tasks_update`. Omit it to patch metadata on a
non-terminal task:

```
npx mcporter call aramb_mcp.tasks_update \
  project_id="<PROJECT_ID>" \
  task_id="<TASK_ID>" \
  description="<the full new description, including a ## Progress section>"
```

Patchable without a status: `description`, `task_name`, `acceptance_criteria`,
`assigned_agent`, `required_toolkits`. `description` is a **replace**, not an append —
send the whole text, with your progress section inside it.

- **Append a note at each real state change**, with concrete ids, paths and URLs. Never
  "made progress".
- Patches **silently no-op on a terminal task** — that is history, not something to
  rewrite.
- A call with **neither a status nor any patch field** is an error, not a no-op.
- `required_toolkits` takes Composio slugs, uppercase (`GMAIL`, `GOOGLESHEETS`,
  `SLACK`). Patch it when you discover the task needs one that was not declared; keep
  the list honest and to what *this* task actually calls.

## Closing — `validating` vs `done` depends on the gate

Your dispatch prompt tells you whether this task has a quality gate: look for
`enable_checker` (or the **## Quality gate** block). It is **OFF unless someone asked
for it**.

**Gate OFF → you are the terminal writer. Close `done`.**

```
npx mcporter call aramb_mcp.tasks_update \
  project_id="<PROJECT_ID>" \
  task_id="<TASK_ID>" \
  status="done" \
  summary="<what is now true — markdown, shown in chat>" \
  outputs='{"summary": "<one paragraph, under 500 chars, for whoever reads this next>", "files": ["<path relative to the workspace root>"]}' \
  artifacts='[{"kind": "blob", "path": "/home/node/workspace/<WD>/report.pdf", "name": "report.pdf", "mime_hint": "application/pdf"}]'
```

Writing `validating` with the gate off is **rejected**: nothing would ever audit it and
the task would strand. The corrective says so — read it and re-issue as `done`.

**Gate ON → close `validating`, never `done`.** Same `summary` / `outputs` / `artifacts`
shape. Writing `done` here is rejected, because it would silently skip the audit.

```
npx mcporter call aramb_mcp.tasks_update \
  project_id="<PROJECT_ID>" \
  task_id="<TASK_ID>" \
  status="validating" \
  summary="Frontend deployed." \
  artifacts='[{"kind": "url", "url": "https://abc.proxy.clode.space", "title": "Frontend", "environment": "deployed"}]'
```

**A corrective tool result is the contract talking. It is a teach signal, not a
failure** — read what it says and re-issue the call it names.

### After `validating`, you are the COURIER — not the judge

The platform follows your `validating` close with an audit turn: it hands you a verbatim
prompt to give a **fresh-context sub-agent**, and that sub-agent's verdict is what you
write back. You do not re-audit, soften, or argue with its findings.

The status IS the verdict, and the matrix recognises which one you mean by the payload
field you attach:

| Verdict | The call |
|---|---|
| **CLEAN** | `status="done"` with `outputs={"audit":"clean","notes":"<the sub-agent's summary>"}` |
| **DIRTY, rounds remain** | `status="inbox"` with `feedback={"round":N,"previous_gaps":[…],"new_gaps":[{"description":…,"severity":"critical"\|"minor"}]}` |
| **DIRTY, final round** | `status="failed"` with `error="<N> rounds; integrity gaps remain: <list>"` |
| **CAN'T AUDIT** | `status="needs_master_attention"` with `error="cannot audit: <reason>"` |

A `validating → done` write **without** `outputs.audit` is rejected — that rejection is
the whole reason the gate holds. After the verdict write, **stop**; the cycle is done.

## The `artifacts` payload

- **`kind` is required** on every entry: `"blob"`, `"file"`, `"url"`, or
  `"browser_session"`.
- **`kind="blob"` is the default for a file deliverable.** The bytes are staged so the
  user can open or download it from any surface — web, Slack, email, a share link.
  `name` and `mime_hint` are optional and worth setting.
- **`kind="file"`** is only an in-workspace pointer with **no download**. Use it solely
  when the live in-workspace file is specifically what is wanted.
- **File paths must be absolute**, under your own working directory
  (`/home/node/workspace/<YOUR_WD>/`). Relative paths and paths outside it are rejected.
- **`kind="url"` auto-registers the preview state** — there is no separate call for it.
- **`summary`** is markdown shown in chat on a `done` / `failed` close. 32KB cap.
- **Attach the deliverable, never describe it.** A paragraph about a file is not a file.
  (Building one that actually opens: `artifacts`.)

## When it does not land

Pick the ending that is **true**, not the one that reads best.

```
# Failed — it was attempted and did not work.
npx mcporter call aramb_mcp.tasks_update \
  project_id="<PROJECT_ID>" \
  task_id="<TASK_ID>" \
  status="failed" \
  error="<what actually stopped it>" \
  retryable="false"

# Stuck in a way another agent can unstick.
npx mcporter call aramb_mcp.tasks_update \
  project_id="<PROJECT_ID>" \
  task_id="<TASK_ID>" \
  status="needs_master_attention" \
  error="<the specific blocker>"

# Only a human can answer. ASK FIRST with aramb_mcp.chat_ask_question, then park.
npx mcporter call aramb_mcp.tasks_update \
  project_id="<PROJECT_ID>" \
  task_id="<TASK_ID>" \
  status="awaiting_user_input"
```

- **`retryable=false`** means *deterministic — re-running changes nothing* (quota gone,
  the API does not have this, the input is wrong). Leave it unset when a retry could
  genuinely succeed. Marking a transient failure permanent throws away a free recovery;
  marking a permanent one retryable burns the user's money on the same wall.
- **`awaiting_user_input` without having asked is a dead end.** Ask the question first,
  then park — otherwise nothing ever arrives to unpark you.
- **A negative finding is a SUCCESSFUL run.** Tests that found six bugs, a search that
  found nothing, a page that does not contain the data: that is `done`, with the finding
  in `summary` and `outputs.summary`. `failed` is for *you* breaking — the runner would
  not start, the environment is gone. Do not hide a real finding behind a failure, and
  do not dress a failure up as a finding.
- **Unobtainable is a real deliverable.** *"This isn't available, here is the nearest
  thing that is, and here is what would get it"* beats a plausible estimate every time.
- **Don't attach an `error` to a `done` close.** The runtime reads that as a
  contradiction and rewrites the status to `failed`. Say which one you mean.

## Name the ending honestly

Work dropped because its premise died is **abandoned**, and abandoned is not failed —
recording it as failed loses the reason and invites someone to retry a thing that should
not be retried. The status alone cannot carry that distinction, so **put the real reason
in the close text** (`summary` on `done`, `error` on `failed`) in plain words: what
ended, and why.

**Terminal is terminal.** Once a task is `done`, `failed` or `cancelled`, no further
transition is accepted — not by you, not by the agent that dispatched you. Get the close
right the first time rather than planning to fix it after.

## Hard lines

- **Never claim an outcome a tool did not return.** Evidence is the observed end state,
  named or quoted: a URL that resolves, a path, a verbatim read-back, a row count. "I
  ran the steps" is not evidence.
- **Never fabricate a result to fill a close.** An invented fact that reaches the user is
  the worst outcome available to you — worse than blocked, worse than slow.
- **Never leave a task open that you have stopped driving.** Close it, block it, or hand
  it forward with everything the next runner needs.
- **You do not address the user.** Your report goes on the task record; the agent that
  delegated to you is who speaks to them. Post to main chat only if your brief told you
  to, and never right after a close that already carried `summary` or `artifacts` — that
  close emits the chat row itself.
- **Never widen the brief.** Adjacent work you spot goes in your report as a finding, not
  into your task.
