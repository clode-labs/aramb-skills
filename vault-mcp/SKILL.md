---
name: vault-mcp
description: >
  Your own secure secret vault via the aramb_mcp server (vault_* tools). Store, fetch, list, and
  delete your secrets (API tokens, keys, credentials) at two scopes — private to
  your project, or shared across your family of agents in the workspace — kept in
  a real secrets manager, never in chat, files, or git. Also create write-only
  placeholder secrets for the USER to fill with a credential you must not see.
  Also list the user's saved browser credentials (logins, addresses, cards) to
  fill into web forms with the browser skill. Use when you need to save or
  retrieve a credential for yourself, to share one across your agents, to prompt
  the user for one, or to discover a saved login to sign in with. NOT for GitHub
  repository secrets (that is `gh secret set`).
---

# Secret Vault

The vault is **your secure secret store**. Secrets you put here live in a real
secrets manager, scoped automatically from your signed identity — you never pass
an org, workspace, or project. Use it to keep credentials out of chat, files, and
git while still being able to retrieve them later.

Your secrets live at one of **two scopes** (you pick with the `scope` arg on a
write; the default is unchanged from before):

- **`agent` (default)** — private to **your project**. No other agent sees it.
  This is exactly the old behavior; omit `scope` and nothing changes.
- **`workspace`** — **shared across your family of agents** in the same workspace.
  Use it for a credential your sibling agents should all reach (a shared API key).
  Other agents in **your** workspace can read it; agents in other workspaces or
  orgs never can.

**Reads resolve most-specific-first:** `get_secret` returns your project secret if
one exists, otherwise falls back to the workspace secret. So a project secret
**shadows** a same-named workspace one for you, without affecting other agents.

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

- **Two scopes within your own identity.** `agent` (default) is private to your
  project; `workspace` is shared across your agents in the workspace. You pass only
  the tier name on a write (`scope="agent"|"workspace"`) — the org/workspace/project
  ids are always derived from your signed identity, never passed.
- **Reads fall back project → workspace.** `get_secret`/`list_secrets` resolve your
  project scope first, then the workspace scope. A project secret shadows a
  same-named workspace secret on read; `list_secrets` shows the union of both.
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
- `scope` (store/delete only) is `agent` (default) or `workspace`; omit it for the
  old project-private behavior.
- All args are named `key="value"`; no positional args.

## Tools

- `store_secret` — create/overwrite one of your secrets. Args: `name`, `value`,
  optional `scope` (`agent` default | `workspace`). `scope="workspace"` shares it
  across your agents; omit for project-private.
- `get_secret` — fetch a secret's string value. Args: `name`. Resolves your project
  scope first, then falls back to the workspace scope.
- `list_secrets` — list the names you can resolve (the union of your project and
  workspace scopes). No args.
- `delete_secret` — delete a secret. Args: `name`, optional `scope` (`agent`
  default | `workspace`). Deletes only the targeted scope — deleting your project
  copy never removes the workspace secret, and vice versa.
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

## Browser credentials — the user's saved logins, addresses and cards

Separate from your own secrets above. The user can save **browser credentials**
in their console — logins, addresses and cards — for their agents to use when
filling forms on live web pages. They are **scoped to the user** (shared across
all the user's agents), **read-only to you**, and their values are **never**
returned to you. You can only _discover_ them here; the browser skill fills a
value straight into a page without it ever passing through you.

`vault_list_browser_creds` — list the user's saved browser credentials. No args.
Each entry has:

- `alias` — the name to reference it by (e.g. `LINKEDIN_ACC1`).
- `kind` — what it is: `site_creds` (a site login), `address`, or `card`.
- `fields` — the field names inside it (e.g. `["username","password"]`), never
  the values.

Use `kind` to pick the right credential for the task — a `site_creds` to sign
in, an `address` or `card` to complete a checkout — then reference a single field
as `"ALIAS.field"` (e.g. `LINKEDIN_ACC1.username`) to fill it with the browser
skill. The value goes from the vault into the page; it never reaches you.

```bash
# What browser credentials has the user saved?
npx mcporter call aramb_mcp.vault_list_browser_creds
```

There is no store / get / delete for browser credentials here — the user manages
them in their console (an "Add credential" flow). If the user has none for a form
you hit, ask them to add it there; never ask for these values in chat.

## Examples

```bash
# Store a GitHub token securely, private to this project (returns {"ok":true})
npx mcporter call aramb_mcp.vault_store_secret name="github" value="ghp_xxx"

# Share one key across all your agents in this workspace
npx mcporter call aramb_mcp.vault_store_secret name="shared_api_key" value="sk_live_xxx" scope="workspace"

# Retrieve it later (resolves your project scope, then the workspace scope)
npx mcporter call aramb_mcp.vault_get_secret name="github"

# What do I have stored?
npx mcporter call aramb_mcp.vault_list_secrets

# Ask the user to provide a credential you must not see
npx mcporter call aramb_mcp.vault_create_platform_secret name="SSH_PASSWORD" description="Enter your SSH password"

# Remove one
npx mcporter call aramb_mcp.vault_delete_secret name="github"

# What browser credentials (logins / addresses / cards) has the user saved?
npx mcporter call aramb_mcp.vault_list_browser_creds
```

## Rules

- When asked to store a secret for safekeeping, use `aramb_mcp.vault_store_secret` — never
  a file, git, `gh secret set`, or the memory tool.
- Never print a stored secret's value back to the user unless they explicitly
  ask you to retrieve it; confirm with the name only ("Stored it as `github`.").
- You never pass org/workspace/project ids — the vault derives them from your
  token. The only scope you choose is the `scope` tier on a write: `agent`
  (default, project-private) or `workspace` (shared across your agents).
- Use `workspace` scope only for a secret your sibling agents genuinely should
  share; keep per-agent credentials at the default `agent` scope.
- When a credential is one you must not see (a user's password / personal token),
  use `create_platform_secret` to have the USER fill it — do not ask for the raw
  value in chat.
- A successful `store_secret` / `create_platform_secret` returns `{"ok":true}` —
  report success from that, do not fabricate a value or a location.
- `vault_list_browser_creds` only _lists_ the user's browser credentials (alias,
  kind, field names) — never their values. Pick by `kind`, reference a field as
  `"ALIAS.field"`, and let the browser fill it; never ask for these values in chat.
