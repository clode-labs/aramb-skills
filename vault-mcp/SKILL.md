---
name: vault-mcp
description: >
  Your own secure secret vault via the aramb_mcp server (vault_* tools). Store, fetch, list, and
  delete your project-scoped secrets (API tokens, keys, credentials) — kept in a
  real secrets manager, never in chat, files, or git. Also create write-only
  placeholder secrets for the USER to fill with a credential you must not see.
  Use when you need to save or retrieve a credential for yourself, or to prompt
  the user for one. NOT for GitHub repository secrets (that is `gh secret set`).
---

# Secret Vault

The vault is **your private, secure secret store**. Secrets you put here live in
a real secrets manager, **scoped to you automatically** — no other agent can read
them. Use it to keep credentials out of chat, files, and git while still being
able to retrieve them later.

## When to use this

- The user gives you a credential to keep (an API token, key, password) and
  wants it stored **securely** — put it in the vault, do not write it to a file
  or echo it back.
- You need a credential you saved earlier for a later step or a later run —
  fetch it from the vault instead of asking again.
- You are wiring up an integration / MCP connection that needs a secret — store
  the secret here (the connection references it by name).
- You need a credential you must **not** see yourself (a user's SSH password, a
  personal token) — create a **platform placeholder** for the user to fill in
  (see below), instead of asking for the raw value in chat.

**Do NOT** reach for `gh secret set` / GitHub repository secrets, a `.env` file,
the OS keychain, or the plain "memory" tool for this. Those are the wrong tool:
the user asking you to "store a secret" for safekeeping means the **vault**.
Never claim you have no secrets tool — you do, it is the vault.

## Model

- **Scoped to you automatically.** Every secret is keyed to you from your signed
  identity and session — you do not pass any org/project/scope. You only ever see
  and touch your own secrets.
- **A secret is a single named string value.** e.g. a secret named `github`
  holding `ghp_...`, or `openai` holding `sk-...`. One name → one string (not a
  multi-key object).
- **Values never come back into chat unless you fetch them on purpose.** Storing
  returns only `{ "ok": true }`. `list_secrets` returns names, not values.

## Invocation

```bash
npx mcporter call aramb_mcp.vault_<tool> name="<secret-name>" value="<secret string>"
```

- `name` is a plain string (the key).
- `value` (store only) is the secret string stored under that name.
- All args are named `key="value"`; no positional args.

## Tools

- `store_secret` — create/overwrite one of your secrets. Args: `name`, `value`.
- `get_secret` — fetch a secret's string value. Args: `name`.
- `list_secrets` — list the names of all your secrets. No args.
- `delete_secret` — delete a secret. Args: `name`.
- `create_platform_secret` — create a **write-only placeholder** for the **user**
  to fill with the real value. Args: `name`, `description` (guidance shown to the
  user), `value` (optional placeholder). Create-only: it fails if the secret
  already exists, so a value the user already provided is never overwritten. You
  **cannot** read, list, update, or delete platform secrets — use it only to ask
  the user for a credential you must not see.

## Asking the user for a secret you must not see

Some credentials you should never handle yourself — an SSH password, a personal
token the user must paste. Don't ask for the value in chat. Instead create a
**platform placeholder**: a named, empty slot the user fills in the console, whose
value you can never read back.

```bash
npx mcporter call aramb_mcp.vault_create_platform_secret \
  name="SSH_PASSWORD" description="Enter your SSH password"
```

This creates `SSH_PASSWORD` in the platform scope with a placeholder value and
your guidance, then tell the user it is waiting for them to fill it in. It is
create-only (it never clobbers a value the user already supplied), and you cannot
read it back — the platform uses it on your behalf.

## Examples

```bash
# Store a GitHub token securely (returns {"ok":true} — nothing else)
npx mcporter call aramb_mcp.vault_store_secret name="github" value="ghp_xxx"

# Retrieve it later
npx mcporter call aramb_mcp.vault_get_secret name="github"

# What do I have stored?
npx mcporter call aramb_mcp.vault_list_secrets

# Ask the user to provide a credential you must not see
npx mcporter call aramb_mcp.vault_create_platform_secret name="SSH_PASSWORD" description="Enter your SSH password"

# Remove one
npx mcporter call aramb_mcp.vault_delete_secret name="github"
```

## Rules

- When asked to store a secret for safekeeping, use `aramb_mcp.vault_store_secret` — never
  a file, git, `gh secret set`, or the memory tool.
- Never print a stored secret's value back to the user unless they explicitly
  ask you to retrieve it; confirm with the name only ("Stored it as `github`.").
- You never pass org/agent/scope — the vault scopes to you from your token.
- When a credential is one you must not see (a user's password / personal token),
  use `create_platform_secret` to have the USER fill it — do not ask for the raw
  value in chat.
- A successful `store_secret` / `create_platform_secret` returns `{"ok":true}` —
  report success from that, do not fabricate a value or a location.
