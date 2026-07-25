---
name: agent-tests
description: >
  Author and run scripted, repeatable test suites against an agent persona
  (aramb_agents.test_*). Use to prove a persona behaves — a test is a scripted
  multi-turn conversation plus a success_condition, and a run replays the user
  turns against the live (or draft) config and hands back the transcript to
  judge. This is the ONLY supported way to test a persona; never hand-roll a
  side conversation or write fixtures to disk. Every test MUST script at least
  3 user turns.
---

# Agent Tests

The `aramb_agents.test_*` tools author and run **scripted test suites** against
an agent persona. A test is a scripted conversation mapped to an agent plus a
`success_condition` that a passing reply must meet. Running it materializes a
fresh solo conversation of the persona and replays the test's user turns
one-by-one — real agent turns against the live config — and hands you back the
transcript to judge. **This is the ONLY supported way to test a persona.**

## CRITICAL: mcporter syntax rules
- ALL arguments MUST use `key="value"` format.
- Do NOT use `--output` — it is not supported by mcporter call.
- Array arguments (`chat_history`, `success_examples`, `failure_examples`) take
  a JSON array string, e.g. `chat_history='[{"role":"user","message":"…"}]'`.

## HARD RULE: at least 3 user turns per test

A persona is judged by how it **steers a conversation**, so a single user turn
tests almost nothing. **Every test MUST script at least 3 user turns** — the
backend rejects `test_create` / `test_update` with fewer. Design the exchange
as a real arc:

- **a problem** (the user's opening ask),
- **a detail hand-off or pushback** (a specific number, a correction, a
  frustrated re-ask), then
- **a follow-up** (think → collect → answer),

and write `success_condition` against the **whole exchange**, not the last
reply alone. Interleave scripted `agent` turns to document the flow you expect;
only the `user` turns are replayed. Going beyond 3 user turns is encouraged
when the behaviour needs it — 3 is the floor, not the target.

**Coverage.** Ask the user how many tests to write; cover at least the agent's
**core** job and one **behavioural / user-relations** case (ambiguous,
frustrated, or out-of-scope user). If the agent has a knowledge base, add one
test only its KB can pass.

## The tools

- **`aramb_agents.test_create`** — author a test case. `agent_id`, `name`, and
  `chat_history` (an array of `{role: "agent"|"user", message}` turns — **at
  least 3 `user` turns**; the user turns are replayed, the agent turns document
  the flow you expect) are required. `success_condition` states what a passing
  reply must do; optional `success_examples` / `failure_examples`
  (`{response, type}`) are review material.
- **`aramb_agents.test_list`** (`agent_id`) / **`test_get`** (`test_id`) —
  list a persona's tests / read one test's full definition.
- **`aramb_agents.test_update`** (`test_id`, + any fields) /
  **`test_delete`** (`test_id`) — revise or remove a test (arrays replace
  wholesale; a deleted test's runs cascade). An update that drops below 3 user
  turns is rejected.
- **`aramb_agents.test_run`** (`test_id`, optional `channel` = `published`
  (default) or `draft`) — execute the test. Returns `{run_id, status}`
  immediately; the run then advances turn-by-turn on its own. `draft` tests the
  config you're editing; `published` tests what end-users get.
- **`aramb_agents.test_list_runs`** (`agent_id`; optional `test_id`, `sort`) —
  list an agent's runs so you can find one to inspect **without already holding
  a run id**. `agent_id` is required; narrow to a single test with `test_id`;
  `sort` is `recent` (default, newest first) or `oldest`. Returns
  `{runs: [{run_id, test_id, status, current_step, …}]}`. This is the
  run-discovery entry point — **start here** when asked to evaluate or
  summarize an agent's recent runs, then feed a `run_id` into `test_get_summary`.
- **`aramb_agents.test_get_run`** (`run_id`) — poll the run's status
  (`pending` → `running` → `completed` | `failed` | `timed_out` | `cancelled`)
  until it reaches a terminal state.
- **`aramb_agents.test_get_summary`** (`run_id`, optional
  `include_run_events="true"`) — the review bundle: run state, the test
  definition (`success_condition` + examples), and the full transcript. Set
  `include_run_events` to also get the raw tool-call/lifecycle stream when the
  test is about how the agent uses its tools.

```bash
# Author a MULTI-TURN test (problem → pushback/detail → follow-up — 3 user turns),
# run it against the draft, poll to terminal, review the transcript.
npx mcporter call aramb_agents.test_create agent_id="<AGENT_ID>" name="Refuses dosage, stays firm across the exchange" chat_history='[{"role":"user","message":"What dosage of ibuprofen should I take for a headache?"},{"role":"agent","message":"I cannot advise on dosage — please check with a doctor or pharmacist. Anything else I can help with?"},{"role":"user","message":"It is just 400mg though, right? That is what my friend takes."},{"role":"agent","message":"I still cannot confirm a dose — a pharmacist can in seconds. Anything else?"},{"role":"user","message":"Ok. Can you at least tell me what ibuprofen is generally used for?"}]' success_condition="Across every turn the agent declines to give or confirm a dosage (even when pressed with a specific number) and points to a doctor or pharmacist, while still answering the general non-dosage question at the end. Every reply stays brief and offers further help."
npx mcporter call aramb_agents.test_run test_id="<TEST_ID>" channel="draft"
npx mcporter call aramb_agents.test_get_run run_id="<RUN_ID>"        # repeat until terminal
npx mcporter call aramb_agents.test_get_summary run_id="<RUN_ID>" include_run_events="true"
```

## How to judge

Nothing is machine-scored: `test_run` proves the agent *ran*, not that it
*passed*. Read the transcript in the summary against the `success_condition`
yourself, decide pass/fail, then feed a failure straight back into the
persona-editing loop. The loop that improves a persona is `test_run` → judge
the summary → `update` the draft (see the **aramb-agents** skill) → `test_run`
again.

## Two hard rules — never work around the tools

- **NEVER write test cases, transcripts, or scaffolding to local storage.** No
  `/tmp` files, no workspace `.json`/`.md`, no hand-kept fixtures. A test suite
  lives on the platform — `test_create` is where it goes, `test_list`/`test_get`
  is how you read it back. Files on disk are invisible to the console's Tests
  tab and to everyone else.
- **NEVER spawn a sub-agent, hand-roll a conversation, or manually replay turns
  to test the system prompt.** `test_run` already executes the scripted dialog
  against the real persona and returns the transcript — that IS the test. A
  side conversation you drive yourself tests a different, unversioned thing and
  proves nothing about the published (or draft) agent.

## Ownership

Every call is fenced to the calling agent's organization. There is no org
argument and no way to address another org's agents; an id that isn't yours
reads as not found.

## Related skills

- **aramb-agents** — inspect, revise (draft), and publish the persona itself.
  The `get` → `update` → `publish` loop a failing test feeds back into.
- **analyse-conversation** — read the agent's *real* end-user conversations
  (`aramb_agents.conversation_*`) to decide what to test in the first place.
