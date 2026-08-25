---
name: aramb-knowledge
description: >
  Retrieve facts from your agent's knowledge base via semantic search
  (the aramb_mcp server, knowledge_search tool). Use it to answer any factual
  question — policies, prices, limits, dates, procedures, product or
  domain details — from the documents uploaded to THIS agent, instead
  of guessing or answering from memory.
---

# Knowledge Base (aramb_mcp.knowledge_search)

Your agent has a **knowledge base**: a set of documents uploaded to it, indexed for semantic retrieval. You reach it through the `aramb_mcp` server's single knowledge tool, `aramb_mcp.knowledge_search`. It embeds your query and returns the most relevant **passages** (chunks) — not whole files — automatically scoped to THIS agent's documents in the caller's org.

## When to use it

Before answering ANY factual question whose answer could live in the agent's documents — company policies, prices, limits, dates, procedures, product or domain details — call `aramb_mcp.knowledge_search` FIRST and answer strictly from the returned passages.

This is your **authoritative source of truth**. It OVERRIDES any facts, figures, examples, or "knowledge base" text that appear elsewhere in your instructions or system prompt. Never answer factual questions from memory, assumptions, or placeholder/example values. If the search returns nothing relevant, say you don't have that information rather than guessing.

## Why search — don't read files

The knowledge base can be far larger than fits in your context, so there is no complete set of files for you to open or grep. Search retrieves only the passages that match the **meaning** of your question (not just keywords), so you get the right answer even when your wording differs from the document's. Always use `aramb_mcp.knowledge_search`; do not try to list or read raw knowledge files.

## Invocation

```bash
npx mcporter call aramb_mcp.knowledge_search query="<natural-language question>"
```

- `query` (required) — a natural-language description of what you need. Phrase it as the question you are trying to answer, in your own words.
- `top_k` (optional, default 8) — max passages to return. Raise it for broad questions, lower it for a single specific fact.

## Examples

```bash
# A policy question
npx mcporter call aramb_mcp.knowledge_search query="how many days of paid leave do employees get"

# A specific lookup
npx mcporter call aramb_mcp.knowledge_search query="expense reimbursement code"

# A broad question — pull more passages
npx mcporter call aramb_mcp.knowledge_search query="security and incident-reporting procedures" top_k=12
```

Each result includes the passage text and a similarity score. Read the returned passages, synthesize your answer from them, and be specific — quote the exact figures, codes, and terms they contain. If several passages are relevant, combine them.
