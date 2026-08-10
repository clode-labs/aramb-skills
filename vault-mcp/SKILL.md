---
name: vault-mcp
description: >
  Your own secure secret vault via the vault MCP server. Store, fetch, list, and
  delete agent-scoped secrets (API tokens, keys, credentials) — kept in a real
  secrets manager, never in chat, files, or git. Use when you need to save or
  retrieve a credential for yourself (e.g. a token for an integration / MCP
  connection). NOT for GitHub repository secrets (that is `gh secret set`).
---

# Secret Vault

The vault is **your private, secure secret store**. Secrets you put here live in
a real secrets manager (AWS Secrets Manager), **scoped to you (this agent)** — no
other agent can read them. Use it to keep credentials out of chat, files, and
git while still being able to retrieve them later.

## When to use this

- The user gives you a credential to keep (an API token, key, password) and
  wants it stored **securely** — put it in the vault, do not write it to a file
  or echo it back.
- You need a credential you saved earlier for a later step or a later run —
  fetch it from the vault instead of asking again.
- You are wiring up an integration / MCP connection that needs a secret — store
  the secret here (the connection references it by name).

**Do NOT** reach for `gh secret set` / GitHub repository secrets, a `.env` file,
the OS keychain, or the plain "memory" tool for this. Those are the wrong tool:
the user asking you to "store a secret" for safekeeping means the **vault**.
Never claim you have no secrets tool — you do, it is the vault.

## Model

- **Agent-scoped.** Every secret is keyed to you automatically from your signed
  identity. You do not pass any org/agent/scope — the vault derives it. You only
  ever see and touch your own secrets.
- **A secret is a named bag of key/value pairs.** e.g. a secret named `github`
  holding `{ "token": "ghp_..." }`, or `openai` holding `{ "api_key": "sk-..." }`.
- **Values never come back into chat unless you fetch them on purpose.** Storing
  returns only `{ "ok": true }`. Listing returns names/keys, not values.

## Invocation

```bash
npx mcporter call vault.<tool> name="<secret-name>" data='<json object>'
```

- `name` is a plain string.
- `data` (store only) is a **JSON object of string key→string value**, passed as
  a single-quoted JSON string.
- All args are named `key="value"`; no positional args.

## Tools

- `store_secret` — create/overwrite a secret. Args: `name`, `data` (object).
- `get_secret` — fetch a secret's key/value data. Args: `name`.
- `list_keys` — list the keys (not values) inside one secret. Args: `name`.
- `list_secrets` — list the names of all your secrets. No args.
- `delete_secret` — delete a secret. Args: `name`.

## Examples

```bash
# Store a GitHub token securely (returns {"ok":true} — nothing else)
npx mcporter call vault.store_secret name="github" data='{"token":"ghp_xxx"}'

# Store a multi-field credential
npx mcporter call vault.store_secret name="stripe" data='{"secret_key":"sk_live_x","publishable_key":"pk_live_y"}'

# Retrieve it later
npx mcporter call vault.get_secret name="github"

# What do I have stored?
npx mcporter call vault.list_secrets

# Which keys are in one secret (without exposing values)?
npx mcporter call vault.list_keys name="stripe"

# Remove one
npx mcporter call vault.delete_secret name="github"
```

## Rules

- When asked to store a secret for safekeeping, use `vault.store_secret` — never
  a file, git, `gh secret set`, or the memory tool.
- Never print a stored secret's value back to the user unless they explicitly
  ask you to retrieve it; confirm with the name only ("Stored it as `github`.").
- You never pass org/agent/scope — the vault scopes to you from your token.
- `data` is always a JSON object of strings; a bare string is invalid.
- A successful `store_secret` returns `{"ok":true}` — report success from that,
  do not fabricate a value or a location.
