---
name: aramb-toolkits
description: >
  MCP toolkit for the Composio toolkit CATALOG and CONNECTION checks
  (aramb_toolkits.*). Use these read-only tools to discover which toolkits exist
  (GMAIL, GITHUB, SLACK, GOOGLESHEETS…), list/inspect their event triggers, and
  check whether a toolkit has a connected account — BEFORE telling the user you
  can't reach an external service. This surface is catalog + check only: it
  CANNOT fetch data. To actually fetch/act (read emails, create an issue, append
  a row) use the `composio-cli` skill (`composio execute <SLUG>`). The flow is:
  check connection here → execute via composio-cli.
---

# Aramb Toolkits — catalog & connection checks

The `aramb_toolkits.*` tools are the **read-only catalog** over the user's
Composio integration: what toolkits exist, what event triggers each exposes, and
whether a toolkit is connected for this project/app. This is the canonical home
for the `aramb_toolkits.*` call contract — other skills (e.g. `configure-trigger`,
`create-workflow`, `update-workflow`) reference it rather than re-documenting it.

## Division of labour — read this first

There are two distinct surfaces. Pick the right one for the job:

| Need | Tool | Skill |
|---|---|---|
| What toolkits / triggers exist? Is GMAIL connected? | `aramb_toolkits.*` (read-only catalog + check) | **this skill** |
| Actually fetch data / perform an action (read emails, create an issue) | `composio execute <SLUG>` | **`composio-cli`** |
| Persist an event trigger on a workflow | `aramb_triggers.*` (write) | **`configure-trigger`** |

**`aramb_toolkits` CANNOT fetch data.** `check_connection` tells you a toolkit is
connected; it does NOT read emails or create issues. Execution is the
`composio-cli` skill (`composio execute GMAIL_FETCH_EMAILS`, etc.).

**The flow for "can I reach the user's <service>?":**

1. **Check** — `aramb_toolkits.check_connection toolkit="GMAIL"` (is it connected?).
2. **Execute** — if connected, hand to the `composio-cli` skill:
   `composio execute GMAIL_FETCH_EMAILS -d '{...}'` (it owns slug discovery via
   `composio search` and schema inspection via `--get-schema`).

Do this **before** declining an external-data request — the connection may
already exist. See the persona guidance ("check connected toolkits before
declining") in `workspace-solo` / your agent's SOUL.

## CRITICAL: mcporter syntax rules

- These tools are reached via `npx mcporter call aramb_toolkits.<tool> key="value"`
  (blind Bash invocation — the JSON arg schema is NOT surfaced to you, so use the
  exact arg names below; don't guess).
- ALL arguments MUST use `key="value"` format.
- The toolkit argument is **`toolkit=`** — NOT `toolkit_slug`, NOT `slug` (the
  trigger detail call uses `slug=` for the trigger, but the toolkit is always
  `toolkit=`). Guessing `toolkit_slug=` is the #1 mistake here.
- Toolkit slugs are **uppercase**, exactly as the catalog reports them (`GMAIL`,
  `GITHUB`, `SLACK`, `GOOGLESHEETS`, `GOOGLECALENDAR`, `GOOGLEDRIVE`…). Use the
  catalog value verbatim — never infer a slug from prose.
- Do NOT use `--output` — it is not supported by `mcporter call`.

## Tools

### `list_toolkits` — what toolkits exist

```bash
npx mcporter call aramb_toolkits.list_toolkits
```

No arguments. Returns the toolkits available in this workspace, each with its
uppercase `slug` and a human name. Match the user's service ("email", "GitHub")
to a real slug here before any further call. If the service has no toolkit, tell
the user it isn't available and stop.

### `list_triggers` — event triggers a toolkit exposes

```bash
npx mcporter call aramb_toolkits.list_triggers toolkit="GITHUB"
```

Returns the trigger types for the toolkit — each with a `slug` (e.g.
`GITHUB_NEW_ISSUE`), a human name, and a description. Read names + descriptions
to pick the candidate that matches the user's event. (Used by `configure-trigger`
when wiring an event trigger.)

### `get_trigger` — one trigger's config + payload shape

```bash
npx mcporter call aramb_toolkits.get_trigger toolkit="GITHUB" slug="GITHUB_NEW_ISSUE"
```

Note the **two** args: `toolkit=` (the toolkit slug) AND `slug=` (the trigger
slug). Returns the trigger's `config_schema` (the parameters it needs — e.g.
GitHub triggers require `owner` + `repo`) and the payload it delivers. Read this
before creating a trigger so you can assemble `trigger_config` correctly (see
`configure-trigger`).

### `check_connection` — is this toolkit connected?

```bash
npx mcporter call aramb_toolkits.check_connection toolkit="GMAIL"
```

Reports whether the toolkit has a connected account for this project/app, and
(when connected) the `connected_account_id`. Two uses:

- **Before executing** an external action — confirm the connection exists, then
  run the action via the `composio-cli` skill. If it reports no connected
  account, tell the user they need to connect <toolkit> first (the Connections
  UI), then stop.
- **Before binding a trigger** — `configure-trigger` calls this to get the
  `connected_account_id` the trigger row binds to.

### `get_github_credential` — mint a github token for native git/gh

```bash
npx mcporter call aramb_toolkits.get_github_credential
```

GitHub is **NOT a Composio toolkit** in this stack — it's served by gitana, a
separate broker. The agent does NOT use `composio execute GITHUB_*` (those
slugs are blocked on the /cli surface with `403`); instead it calls this MCP
tool to get a short-lived user OAuth token and then uses **native `git` and
`gh` CLI** for everything.

Response:

```json
{ "username": "x-access-token",
  "token":    "gho_<40-char token>",
  "account_ref": "ca_xxx",
  "expires_at":  "...",
  "scope":      "repo read:user user:email read:org workflow" }
```

The full workflow:

```bash
# 1. Confirm the user has connected github
npx mcporter call aramb_toolkits.check_connection toolkit="GITHUB"
# → { connected: true, ... }

# 2. Get a token (no args)
npx mcporter call aramb_toolkits.get_github_credential
# → { token: "gho_…", username: "x-access-token", ... }

# 3. Export and use native CLI for everything else
export GH_TOKEN="gho_…"
git clone https://x-access-token:$GH_TOKEN@github.com/acme/repo.git
cd repo && git checkout -b feat/x && git push -u origin feat/x
gh pr create --title "..." --body "..."
gh issue list --repo acme/repo
gh release create v1.0.0 --notes "..."
```

On 401 from `git` / `gh` (~8h token lifetime, can be shorter) call
`get_github_credential` again for a fresh token — cheap, no rate concerns.

If `check_connection toolkit="GITHUB"` returns `connected: false`, tell the
user to connect github in the Connections UI; do NOT proceed.

## Rules

- **`toolkit=` is the arg** (never `toolkit_slug`). `get_trigger` additionally
  takes `slug=` for the trigger.
- **Read-only catalog + check + github credential.** `aramb_toolkits.*` looks
  things up and mints github tokens; it never fetches data or mutates state.
  Execute non-github actions via `composio-cli`; persist triggers via
  `aramb_triggers.*`.
- **Github is special.** `composio execute GITHUB_*` is blocked
  (`403`). GitHub work goes through `get_github_credential` + native `git`/`gh`.
- **Ground every slug in the catalog.** Toolkit slugs come from `list_toolkits`,
  trigger slugs from `list_triggers` — uppercase, verbatim. Never invent a slug.
- **Check before you decline.** When a request needs an external service, run
  `check_connection` (and execute via `composio-cli` if connected) before saying
  you don't have access — the connection may already exist.
