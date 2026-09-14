---
name: delegation
description: >
  How to hand a piece of work to a worker and stay the owner of it. Use once you
  have decided a request is work rather than an answer: it covers the two routes
  out — INTERNAL (`aramb_mcp.tasks_create` with `assigned_agent="task-agent"`, the
  generic executor) and EXTERNAL (`aramb_mcp.a2a_send_message` to a named agent
  from your roster) — plus how to write the brief, how to verify what comes back,
  and how to close. NOT the place the routing decision is made (that is your
  playbook), NOT for asking the Architect to BUILD an agent (`build-an-agent`),
  and NOT for how you get woken while you wait (`wake-subscriptions`).
---

# Delegation — handing out the work, keeping the outcome

Delegating is not getting rid of something. The worker executes; **you still own the
outcome, verify the claim, and close it with the user.** A worker never talks to the
user — everything the user hears comes from you.

By the time you are here, the routing call is already made (your playbook makes it).
This skill is the *how*: two routes out, one brief grammar, one way to close.

## The two routes out

| Route | Target | Tool | Use when |
|---|---|---|---|
| **Internal** | `task-agent` — the generic executor that lives in your container | `aramb_mcp.tasks_create` | Nothing on your roster covers it. This is the default worker. |
| **External** | a named agent from your roster | `aramb_mcp.a2a_send_message` | A roster agent's purpose covers this, or one has handled this kind of thing before. |

**Your roster is injected into every turn.** Name, one-line purpose, `agent_id`, and
what it handled before are already in front of you — so **do not call `agents_list` to
go looking**. If the roster in front of you has no match, that is the answer: the work
goes to `task-agent`.

## The brief — raw intent, never a procedure

You hired a worker so that it chooses the steps. A brief that spells out the steps is
you doing the work through someone else's hands, badly.

A brief carries exactly four things:

1. **The outcome, in the user's own framing** — what should be true when this is done.
2. **The context the worker cannot get for itself** — ids, URLs, constraints, prior
   findings, which account/identity to use, anything the user said that shapes it.
3. **The exact evidence that closes it** — the observable end state you will accept.
4. **What is out of scope** — the adjacent thing it must not wander into.

Never: a numbered procedure, a choice of tool, a selector, a suggested library. If you
find yourself writing step 3 of 7, stop — you are executing, not delegating.

```
OUTCOME   Five data-engineer roles in Bangalore posted in the last week, with the
          company, the posting link, and the salary where it is stated.
CONTEXT   For the user's own job search. Bangalore only. Last 7 days only.
EVIDENCE  Five real posting URLs that resolve, each with its source named.
OUT OF    Do not apply to anything. Do not create an account anywhere.
SCOPE
```

Notice what is absent: which site, which tool, which order. That is the worker's call.

## Route A — internal, to `task-agent`

```
aramb_mcp.tasks_create(
  project_id      = "<PROJECT_ID>",
  application_id  = "<APPLICATION_ID>",     # without it the task lands on the wrong app
  tasks = [{
    "unique_id":           1,
    "name":                "Find data-engineer roles in Bangalore",
    "assigned_agent":      "task-agent",
    "description":         "<the brief — outcome, context, evidence, out of scope>",
    "acceptance_criteria": "Five posting URLs that resolve, each with company and source named.",
    "enable_checker":      false
  }]
)
```

Three fields decide whether this works:

- **`assigned_agent="task-agent"`** — the generic executor. Spell it exactly; a name
  that does not resolve does not dispatch.
- **`acceptance_criteria` — REQUIRED, every time.** It is not documentation. It is what
  a checker evaluates and what a watcher's trigger reads, and it is how you will know a
  claim is true rather than confident. Write it as an **observable state**, not an
  effort: *"five posting URLs that resolve"*, never *"searched thoroughly"*. A task
  created without it is a task nobody can close honestly.
- **`enable_checker` — OFF by default.** Set `true` **only** when the deliverable is
  load-bearing: an artifact the user will open, a spend, or anything the user will act
  on rather than just read. Everywhere else the gate costs a whole extra agent run for
  a verification you are going to do yourself anyway. **Either way you are still the
  gatekeeper** — the checker never replaces your own spot-check, it only adds one.

Then **end your turn**. Do not sit and poll. (How you come back: `wake-subscriptions`.)

> **Notation.** The blocks above name the tool and its arguments. Call the tool. Do not
> shell out to reach it — see *Hard lines*.

## Route B — external, to a roster agent

```
# Open the conversation with the agent_id from your roster — returns a chat_id.
aramb_mcp.a2a_send_message(agent_id="<AGENT_ID>", message="<the brief>")

# On wake, read what it actually said.
aramb_mcp.a2a_get_messages(chat_id="<CHAT_ID>")

# Continue the same conversation by chat_id, never by agent_id again.
aramb_mcp.a2a_send_message(chat_id="<CHAT_ID>", message="<your answer>")
```

- **`agent_id` starts a conversation; `chat_id` continues it.** Save the `chat_id` the
  moment you get it — it is the only handle to that worker.
- **End your turn after sending.** Delegated work wakes you automatically when the
  other agent responds, including when it stops to ask *you* a question. You do not arm
  a timer for this.
- **On wake you know nothing** — the wake carries no state. Go read the reply with
  `a2a_get_messages` before you form a view of what happened.
- **If it asks a question, you answer it.** Relay it to the user in plain words if only
  the user can answer, then feed the answer back on the same `chat_id`. Never leave a
  worker's question hanging — a blocked worker is a stalled outcome.

## Verify before you relay — you are the gate

A worker's report is a **claim**, not a fact. Between its report and your message to the
user sits exactly one thing: you.

- **Spot-check every load-bearing claim** — the one the user will act on, spend against,
  or repeat to someone else. Open one of the URLs. Read back the row. Look at the file.
- **Evidence is the observed end state**, named or quoted: a URL that resolves, a file
  path, a verbatim read-back, a row count, a timestamp. *"I ran the steps"* is not
  evidence, and neither is a confident summary.
- **A number you cannot reproduce is a flag, not a choice.** Report the discrepancy;
  never quietly pick whichever figure reads better.
- **Unobtainable is a real deliverable.** *"This isn't available, here is the nearest
  thing that is, and here is what would get it"* beats a plausible-looking estimate
  every single time. An invented fact that reaches the user is the worst outcome
  available to you — worse than blocked, worse than slow.
- If the claim does not survive the check, it goes **back to the worker** with what you
  observed. It does not go to the user as though it held.

## Closing the outcome

Close on evidence, in the worker's record and then with the user:

```
# Done — with the evidence attached, not described.
aramb_mcp.tasks_update(
  project_id = "<PROJECT_ID>", task_id = "<TASK_ID>",
  status     = "done",
  summary    = "<what is now true — markdown, shown to the user>",
  outputs    = {"summary": "<one paragraph, under 500 chars>", "files": ["<path>"]}
)

# Failed — the work was attempted and did not land.
aramb_mcp.tasks_update(
  project_id = "<PROJECT_ID>", task_id = "<TASK_ID>",
  status     = "failed", error = "<what actually stopped it>"
)
```

- **Attach deliverables, don't describe them.** A file the user should open goes as an
  artifact (`kind="blob"` for anything that must travel beyond the workspace tab), not
  as a paragraph about a file.
- **Say which ending it was.** Work that was dropped because the premise died is
  **abandoned**, and abandoned is not failed — recording it as failed loses the reason
  and invites someone to retry a thing that should not be retried.
- **Blocked is a state, not a defeat.** Record what is missing and whose move it is, in
  those words. If it is the user's move, the user hears it **now** — not when you next
  happen to be woken.
- **Never leave a unit open that you have stopped driving.** If you are handing it
  forward, hand it forward with everything the next runner needs: ids, what was tried,
  what failed and why.

## Hard lines

- **Never delegate through `Bash`.** `aramb_mcp.tasks_*` and `aramb_mcp.a2a_*` are the
  only sanctioned way to dispatch work. Never `curl` the MCP endpoint, never read
  `mcporter.json` or any bearer token, never script around the toolkit.
- **Never claim an outcome a tool did not return.** Not "the worker says it's done" —
  the observed end state, or nothing.
- **Never let a worker speak to the user.** Its report comes to you; what the user
  hears is written by you, in your own register, with the machinery left out.
- **Never widen a brief mid-flight.** New scope is a new brief, and the user's call.
