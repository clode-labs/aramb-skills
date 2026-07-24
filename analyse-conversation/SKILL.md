---
name: analyse-conversation
description: >
  Read and analyse an agent's real end-user conversations (aramb_agents.
  conversation_search / conversation_get) to judge how the persona actually
  behaves and turn that evidence into a concrete improvement. Use when asked to
  review, evaluate, diagnose, or "analyse the conversation" for an agent — the
  console's Analyze button lands here with a transcript pre-filled. Grounds any
  persona change in what users said and how the agent replied, then feeds it
  back into the get → update → publish loop.
---

# Analyse Conversation

Read an agent's **real conversations** — the chats end-users actually had with
it — and turn what you find into a concrete improvement. This is how you judge a
persona from evidence instead of guessing, and it is the surface the console's
**Analyze** button on a conversation opens: it hands you the transcript with an
"Analyse the Conversation:" message pre-filled so you can review how the agent
handled that chat and say what to change.

## CRITICAL: mcporter syntax rules
- ALL arguments MUST use `key="value"` format.
- Do NOT use `--output` — it is not supported by mcporter call.

## The two read tools

- **`aramb_agents.conversation_search`** — list an agent's conversations,
  most-recent-activity first. Optional `from`/`to` (RFC3339) window the
  activity, `order` is `recent` (default) or `oldest`, `limit` defaults to 50
  (max 200). Returns `{conversations: [{conversation_id, title, created_at,
  last_message_at}], has_more}`. This is the entry point when you were **not**
  handed a specific conversation — start here to find one.
- **`aramb_agents.conversation_get`** — one conversation's messages, oldest
  first. Optional `from`/`to` (RFC3339) window the messages (`to` is also the
  backwards-paging cursor — pass the returned `next_before` to page older),
  `order` is `asc` (default) or `desc`, `limit` defaults to 50 (max 200). Set
  `include_run_events=true` to also get the agent's run/tool-event stream
  (tool_call / tool_result / lifecycle) when you need to review how it used its
  tools. Returns `{messages: [{role, message_type, content, created_at}],
  has_more, next_before, run_events?}`.

```bash
# Handed a conversation (Analyze button): read that transcript directly.
npx mcporter call aramb_agents.conversation_get agent_id="<AGENT_ID>" conversation_id="<CONVERSATION_ID>"

# Not handed one: find recent conversations first, then read one.
npx mcporter call aramb_agents.conversation_search agent_id="<AGENT_ID>" order="recent" limit="20"
npx mcporter call aramb_agents.conversation_get agent_id="<AGENT_ID>" conversation_id="<CONVERSATION_ID>"

# Diagnosing a tool problem — pull the tool-call/lifecycle stream alongside the transcript.
npx mcporter call aramb_agents.conversation_get agent_id="<AGENT_ID>" conversation_id="<CONVERSATION_ID>" include_run_events="true"

# Narrow to a time window when triaging a reported incident.
npx mcporter call aramb_agents.conversation_get agent_id="<AGENT_ID>" conversation_id="<CONVERSATION_ID>" from="2026-07-01T00:00:00Z" to="2026-07-08T00:00:00Z"
```

These reads are **transcript-only**: they surface `role` (user / assistant),
message text, and time — never the end-user's identity or tenancy. Every call
is fenced to the calling agent's organization; an id that isn't yours reads as
not found.

## How to analyse — read for the failure, then fix it

Don't summarize the chat back at the user — analyse it. Read the transcript
(pull `include_run_events` when the question is about tool use) and look for
where the agent actually went wrong:

- **Misunderstood** the user's intent, or answered a different question.
- **Over-refused** — declined something in scope, or hedged a straightforward
  answer into uselessness.
- **Missed context** the earlier turns established, or contradicted itself.
- **Tone / user-relations** — curt, robotic, or unhelpful when the user was
  confused or frustrated.
- **Tool misuse** (with `run_events`) — called the wrong tool, skipped a tool
  it should have used, or mishandled a tool result.
- **Went out of scope** — did work the persona shouldn't, or leaked how it
  works.

Then say, concretely, **what in the system prompt (or greeting, skills, or
tools) caused it and what to change** — quote the offending turn, name the
fix. Vague praise ("looks good") is not an analysis.

## Close the loop — evidence → change

An analysis is only worth something if it lands as a change. Feed what you
found straight into the persona-editing loop:

1. **`aramb_agents.get`** — read the current DRAFT (the source of truth, not
   this conversation; someone may have edited it since).
2. **`aramb_agents.update`** — patch the draft with the fix, grounded in the
   turn you quoted (partial merge — pass only the keys that change).
3. Let the user confirm, then **`aramb_agents.publish`** to make it live.

For anything beyond a single read-and-diagnose — inspecting/revising/publishing
the persona itself — see the **aramb-agents** skill. To prove the fix with a
scripted, repeatable multi-turn test rather than one anecdote, see the
**agent-tests** skill (`aramb_agents.test_*`).
