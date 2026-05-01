---
name: juno
description: >
  Context memory — store and retrieve patterns, gotchas, and insights across sessions.
---

# Juno — Context Memory

You have access to Juno context memory tools via MCP. These let you store and retrieve knowledge that persists across sessions.

## When to READ from Juno

**At the start of any task**, check for relevant context:

```
npx mcporter call juno.get_session_context project_id="<project_id>"
```

Before working on a specific topic, query for known patterns and gotchas:

```
npx mcporter call juno.query_context query="<topic>" strategy="peek"
npx mcporter call juno.get_gotchas topic="<topic>"
```

## When to WRITE to Juno

**Store a gotcha** when you hit a non-obvious issue that wasted time:
```
npx mcporter call juno.store_gotcha \
  gotcha="<what happened>" \
  trigger="<what causes it>" \
  solution="<how to fix/avoid>" \
  severity="high"
```

**Store a pattern** when you establish an approach that should be followed:
```
npx mcporter call juno.store_pattern \
  pattern="<the pattern>" \
  applies_to="<where it applies>" \
  example="<code or example>"
```

**Store an insight** when you learn something important about the project:
```
npx mcporter call juno.store_insight \
  insight="<what you learned>" \
  context="<what you were doing>" \
  recommendation="<what to do about it>"
```

## What to Store vs Skip

**ALWAYS store:**
- Non-obvious errors that took investigation to resolve
- Task failures and what fixed them on retry
- User corrections to your approach
- Build/deploy/test workflows specific to this project
- Architecture decisions not obvious from code

**NEVER store:**
- Code you wrote that works (it's in git)
- Information derivable from reading the codebase
- Mid-debug state before you have a solution
- Generic knowledge (REST returns JSON, etc.)

## Promote Important Learnings

If a learning is valuable beyond this project (useful for all projects by this user):
```
npx mcporter call juno.promote_episode \
  episode_id="<id>" \
  target_scope="user" \
  target_id="<user_id>" \
  reason="<why it's broadly useful>"
```

## Available Tools

| Tool | Purpose |
|------|---------|
| `juno.query_context` | Search for relevant context (strategies: peek, summarize, explore) |
| `juno.get_session_context` | Get all context for current scope (patterns + gotchas + insights) |
| `juno.get_patterns` | Get patterns for a topic |
| `juno.get_gotchas` | Get gotchas for a topic |
| `juno.store_pattern` | Store a reusable pattern |
| `juno.store_gotcha` | Store a pitfall/gotcha with solution |
| `juno.store_insight` | Store a project insight |
| `juno.promote_episode` | Promote episode to broader scope (project → user) |
