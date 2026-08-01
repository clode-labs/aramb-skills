---
name: akela-mcp
description: >
  Store and retrieve your own secrets (API keys, tokens, credentials) via
  akela's MCP server. Secrets are automatically scoped to you — you can only
  ever see the secrets you saved, never another agent's.
---

# Akela Secret Vault

Use this when you need to **save a credential for later** (an API key, an OAuth token, a password)
and read it back in a future turn — without pasting it into a config file or leaving it in plain sight.
akela keeps the value in a real secret store (AWS Secrets Manager today) and hands it back only to you.

## Scoping — you never pass an owner

Every tool is scoped to **you** automatically, from the identity in your token. You do **not** pass an
`org_id`, `project_id`, or `agent_id` — akela derives your scope from the signed request and refuses
anything it can't attribute to you. Practical consequences:

- You only ever see secrets **you** stored. Another agent storing a secret named `slack` does not
  collide with yours and you cannot read theirs.
- A secret is a **named bag of key/value pairs** (e.g. name `slack` → `{ "bot_token": "xoxb-…" }`).
  The name is unique within your own scope.

## Invocation

```bash
npx mcporter call akela.<tool> key="value" key="value"
```

- All args are named: `key="value"` with quotes. No positional args, no `--output`.
- The `data` bag for `store_secret` is passed as a **JSON string**.

## Tools

- `store_secret name="<name>" data='{"k":"v",...}'` — create or overwrite (upsert) a secret. Returns `{ok:true}`.
- `get_secret name="<name>"` — return the full `{key:value}` bag. Errors if it doesn't exist.
- `list_keys name="<name>"` — return just the key names of a secret (not the values).
- `list_secrets` — list the names of all secrets in your scope (no values).
- `delete_secret name="<name>"` — remove a secret. Returns `{deleted:true}`.

Secret names must not be empty or contain `/`, `..`, or control characters.

## Examples

```bash
# Save an API token for later
npx mcporter call akela.store_secret name="stripe" data='{"api_key":"sk_live_abc123"}'

# Read it back in a later turn
npx mcporter call akela.get_secret name="stripe"
# → {"data":{"api_key":"sk_live_abc123"}}

# See what you've saved (names only)
npx mcporter call akela.list_secrets

# Rotate one key in a multi-key secret (store_secret is an upsert — pass the full bag)
npx mcporter call akela.store_secret name="stripe" data='{"api_key":"sk_live_NEW"}'

# Delete when done
npx mcporter call akela.delete_secret name="stripe"
```

## Security — read this before storing a credential

**Anything you store or fetch through this tool passes through your conversation.** The value you type
into `store_secret`, and the value `get_secret` returns, land in the transcript, the stored chat
history, and cost accounting — and are therefore reachable by prompt injection. A credential delivered
into your container is also readable by your own shell.

What akela **does** guarantee: the value is not stored in plaintext, it is scoped to you (no other
agent can read it), and it is centrally revocable. What it does **not** guarantee: that you (or an
attacker who has taken over your turn) cannot read it.

**For real, sensitive credentials, prefer the console's Integrations / MCP UI**, where the value goes
browser → backend → vault and never enters a prompt. Use this tool for secrets an agent legitimately
needs to mint and re-read itself, and never echo a fetched secret back into a message that doesn't need
it.

## Errors

Errors come back as `{isError: true, content: [{type:"text", text:"…"}]}`, or as a JSON-RPC error for
a malformed call (bad name, missing scope). The text is user-presentable — relay it and stop retrying.
A "secret not found" is definitive: you have not stored that name (retrying won't change it).
