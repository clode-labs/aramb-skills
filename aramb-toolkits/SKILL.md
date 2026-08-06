---
name: aramb-toolkits
description: >
  The SINGLE surface for third-party toolkits (Composio integrations) —
  discover, inspect, and EXECUTE tools, manage connections, read the event-
  trigger catalog, and mint github credentials. All via `aramb_toolkits.*`.
  Discover a tool (search → get_schema) then run it (execute). Check/list/connect
  accounts. For GitHub: execute GITHUB_GET_GIT_CREDENTIAL for a token, then use
  native git/gh. This skill fully replaces the retired `composio-cli` — there is
  no `composio` CLI; everything is an `aramb_toolkits` MCP call.
---

# Aramb Toolkits — the single toolkit surface

`aramb_toolkits.*` is the one place you reach any third-party integration
(Gmail, Slack, Google Sheets/Drive, GitHub, …). It does **discovery**,
**execution**, **connection management**, and the **trigger catalog**. There is
no separate CLI — if you remember `composio execute ...`, that is gone; the
equivalent is `aramb_toolkits.execute`.

**Availability — not every persona gets every tool.** The agent-builder
(Architect) persona is advertised `list_toolkits` only: `connect`, `execute`
(and the connection-state reads) are deliberately withheld, because a connection
brokered during authoring is scoped to the builder's own project — which never
executes — so the user would authorize an account the agent can never see. There
the builder declares `required_toolkits` and the **user** connects each account
on the agent's Tools page in the console. Everything else here stays valid for
ordinary runtime agents. If a tool documented here is not in your tool list, that
is why — say so plainly and point the user at the Tools page rather than
improvising a link.

## How to call

Reach these tools with `mcporter`:

```bash
# structured args → use --json (reliable for nested `arguments`)
npx mcporter call aramb_toolkits.execute --json '{"tool":"GMAIL_SEND_EMAIL","arguments":{"recipient_email":"a@b.com","subject":"Hi","body":"..."}}'

# a single simple arg → key="value" is fine too
npx mcporter call aramb_toolkits.search query="send an email" toolkit="gmail"
```

Rules:
- **Prefer `--json '{...}'`** whenever a call has an `arguments` object or more
  than one field — it is unambiguous. `key="value"` is fine for a single simple
  string arg.
- Toolkit slugs are **UPPERCASE** as the catalog reports them (`GMAIL`,
  `GITHUB`, `GOOGLESHEETS`, `GOOGLEDRIVE`, `SLACK`, …). Ground every slug in
  `list_toolkits` / `search` — never invent one.
- **`execute` response envelope is `{tool, success, result}`** — the tool's
  own output is under **`result`** (NOT `data`). Read `result`.
- **`mcporter call` does not support `--output`** — don't pass it.

## The core loop: discover → inspect → execute

1. **`search`** — find a TOOL SLUG by task. *This searches the catalog of
   tools, NOT your account's data.* (To search data — e.g. find a spreadsheet —
   you `execute` a toolkit tool like `GOOGLESHEETS_SEARCH_SPREADSHEETS`.)
   ```bash
   npx mcporter call aramb_toolkits.search --json '{"query":"create a github issue","limit":6}'
   ```
   Returns `{slug,name,description,toolkit,is_deprecated}` rows. **Avoid
   `is_deprecated:true` slugs.**
2. **`get_schema`** — read one tool's input arguments before calling it:
   ```bash
   npx mcporter call aramb_toolkits.get_schema --json '{"tool":"GITHUB_CREATE_AN_ISSUE"}'
   ```
3. **`execute`** — run it:
   ```bash
   npx mcporter call aramb_toolkits.execute --json '{"tool":"GITHUB_CREATE_AN_ISSUE","arguments":{"owner":"acme","repo":"app","title":"Bug"}}'
   ```
   - **Account selection is optional.** Omit `connected_account_id` and the
     single in-scope account for the toolkit is auto-resolved. If several
     accounts of that toolkit are connected, the call is rejected as ambiguous —
     pass `connected_account_id` to pick one. The value may be an **account_ref**
     (`ca_…`) **or an alias** (e.g. `"work-gmail"`) from `list_connections`:
     ```bash
     npx mcporter call aramb_toolkits.execute --json '{"tool":"GMAIL_SEND_EMAIL","connected_account_id":"work-gmail","arguments":{...}}'
     ```

## Connections

- **`list_connections`** — the connected accounts in scope (each with
  `account_ref`, `alias`, `toolkit`, `status`). Optional `toolkit` filter. Use
  it to pick an `account_ref`/alias when a toolkit has several accounts.
  ```bash
  npx mcporter call aramb_toolkits.list_connections toolkit="GITHUB"
  ```
- **`check_connection`** — the cheap yes/no pre-flight for one toolkit; returns
  `{connected, connected_account_id, account_ref, status}`.
  ```bash
  npx mcporter call aramb_toolkits.check_connection toolkit="GMAIL"
  ```
- **`connect`** — start an OAuth connection; returns a `redirect_url` the user
  opens in a browser. Optional `alias` for a non-default/second account.
  ```bash
  npx mcporter call aramb_toolkits.connect toolkit="gmail"
  # → { redirect_url: "https://...", ... } — share it, then poll check_connection until ACTIVE
  ```

**The flow for "can I reach the user's <service>?":** `check_connection` → if
`connected:false`, `connect` and share the `redirect_url`; if connected,
`search`/`get_schema`/`execute` the action. Check before you decline — the
connection may already exist.

## Catalog & triggers

- **`list_toolkits`** — the available integrations (source of truth for toolkit
  slugs). Optional `search` text filter.
- **`list_triggers` / `get_trigger`** — the event-trigger catalog for a toolkit
  (used by `configure-trigger` / `create-workflow` to ground a trigger slug and
  read its `config_schema` / `payload_schema` before persisting a
  `toolkit_event` trigger via `aramb_triggers.*`).
  ```bash
  npx mcporter call aramb_toolkits.list_triggers toolkit="GITHUB"
  npx mcporter call aramb_toolkits.get_trigger --json '{"slug":"GITHUB_NEW_ISSUE"}'
  ```

## GitHub — token, then native git/gh

GitHub is **not executed as a normal tool**. `execute` the single synthetic
action `GITHUB_GET_GIT_CREDENTIAL` to mint a short-lived token, then use native
`git` / `gh` for everything (clone, pull, resolve conflicts, push, PRs, issues,
releases) — that is far more capable than REST tool calls. Other `GITHUB_*`
tools are not served here.

```bash
# 1. confirm connected
npx mcporter call aramb_toolkits.check_connection toolkit="GITHUB"
# 2. mint a token (result under `result`: {username:"x-access-token", token, account_ref, ...})
npx mcporter call aramb_toolkits.execute --json '{"tool":"GITHUB_GET_GIT_CREDENTIAL"}'
# 3. use native CLI
export GH_TOKEN="gho_…"
git clone https://x-access-token:$GH_TOKEN@github.com/acme/repo.git
gh pr create --title "..." --body "..."
```

- **Multiple github accounts:** pass `connected_account_id` (a `ca_…` ref or
  alias from `list_connections toolkit="GITHUB"`) inside the execute arguments,
  e.g. `{"tool":"GITHUB_GET_GIT_CREDENTIAL","arguments":{"account_ref":"ca_…"}}`.
- **Not connected:** `connect toolkit="github"` → share the `redirect_url`.
- On `401` from git/gh (~8h token life), re-run the mint — cheap.

## Rules

- **`aramb_toolkits` is the whole toolkit surface** — discovery, execution,
  connections, trigger catalog, github credential. There is no `composio` CLI.
- **`toolkit=` is the arg** (never `toolkit_slug`); `get_trigger` takes `slug=`.
- **Ground every slug** in `list_toolkits` / `search` — uppercase, verbatim.
- **`search` finds tools, not data.** Data lookups are toolkit tools you
  `execute` (e.g. `*_SEARCH_*`).
- **Read `result`** from the execute envelope `{tool, success, result}`.
- **GitHub** = `execute GITHUB_GET_GIT_CREDENTIAL` + native `git`/`gh`.
- **Persisting** an event trigger on a workflow is `aramb_triggers.*` (the
  `configure-trigger` skill) — this skill only reads the trigger catalog.
- **Check before you decline.** Run `check_connection` before saying you can't
  reach a service.
