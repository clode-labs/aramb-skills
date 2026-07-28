---
name: aramb-toolkits
description: >
  MCP surface for the Composio toolkit CATALOG, CONNECTION lifecycle, and the
  github credential broker (aramb_toolkits.*). Discover which toolkits exist
  (GMAIL, GITHUB, SLACK, GOOGLESHEETS…), list/inspect their event triggers,
  check / list / connect accounts, and mint github user-OAuth tokens for native
  git/gh CLI use. To actually fetch / act on non-github toolkits (read emails,
  create an issue, append a row) use the `composio-cli` skill
  (`composio execute <SLUG>`). For github: this skill is the ONLY surface —
  composio github tools are blocked. Standard flow: check here → execute via
  composio-cli (or native git/gh for github) → connect from chat when missing.
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
| What toolkits / triggers exist? Is GMAIL connected? | `aramb_toolkits.*` (catalog + check) | **this skill** |
| Connect a toolkit from chat (OAuth) | `aramb_toolkits.connect_toolkit` | **this skill** |
| Actually fetch data / perform an action (read emails, create an issue) | `composio execute <SLUG>` | **`composio-cli`** |
| Anything github — clone, push, PRs, issues | `aramb_toolkits.get_github_credential` + native `git`/`gh` | **this skill** |
| Persist an event trigger on a workflow | `aramb_triggers.*` (write) | **`configure-trigger`** |

**`aramb_toolkits` CANNOT fetch data for non-github toolkits.** `check_connection`
tells you a toolkit is connected; it does NOT read emails or create issues.
Execution for non-github is the `composio-cli` skill (`composio execute
GMAIL_FETCH_EMAILS`, etc.). Github execution is `get_github_credential` + native
CLI — `composio execute GITHUB_*` is blocked here.

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

Reports whether the toolkit has a connected account for this project, and
(when connected) the `connected_account_id` + `account_ref`. Three uses:

- **Before executing** an external action — confirm the connection exists, then
  run the action via the `composio-cli` skill (or, for github, the
  `get_github_credential` flow below).
- **Before binding a trigger** — `configure-trigger` calls this to get the
  `connected_account_id` the trigger row binds to.
- **Decide if you need to connect** — if `connected: false`, hand off to
  `connect_toolkit` (below) so the user can authorize from chat.

### `list_connections` — enumerate connections for a toolkit

```bash
npx mcporter call aramb_toolkits.list_connections toolkit="GITHUB"
```

`check_connection` collapses to one row (yes/no). `list_connections` returns
the full set, with `account_ref` + `alias` on each — use it when the user has
or might have **multiple** accounts of the same toolkit (personal + work
github, two gmail accounts) and you need to pick one. Then pass the chosen
`account_ref` to `get_github_credential`.

Omit `toolkit=` to list every connection in the project.

**Agent variant — `list_connections agent_id="…"`.** Pass `agent_id=`
instead of `toolkit=` to enumerate the connections in scope for an agent: the
agent's own agent-scoped connections plus the private/org connections in scope.
Each row carries a `connection_id`, `toolkit_slug`, an account label and an
`origin` (`agent` / `pool` / `org`). Use it to see which accounts are available
to an agent while authoring. Agent-scoped connections belonging to *other* agents
are not returned.

```bash
npx mcporter call aramb_toolkits.list_connections agent_id="<AGENT_ID>"
```

### `request_connection` — get a connect URL a human completes (the ONLY way to create a connection)

```bash
npx mcporter call aramb_toolkits.request_connection toolkit_slug="GMAIL" agent_id="<AGENT_ID>"
```

Returns `{connect_url}` — a URL a **human** opens to complete OAuth. This is the
**only** way a connection is ever created: no verb creates a connection headlessly,
so an agent can never conjure one on its own. Share the `connect_url` in chat and
wait for the user to finish before treating the connection as real.

- **`agent_id` present** ⇒ the new connection is tagged to that agent (agent-scoped).
- **`agent_id` omitted** ⇒ the connection is created as a private pool connection.

`request_connection` is the author-side counterpart to `connect_toolkit`: reach for
it while authoring an agent whose required toolkit isn't connected yet.

### `connect_toolkit` — start a new connection (OAuth) from chat

```bash
npx mcporter call aramb_toolkits.connect_toolkit toolkit="github"
```

Initiates the OAuth flow for a toolkit and returns a `redirect_url` the user
must complete in a browser. Share the URL in chat (plain text or via
`aramb_chat.alert_user`), then poll `check_connection` until status flips to
`ACTIVE`.

Args: `toolkit=` (required, e.g. `"github"`, `"gmail"`). Optional `alias=`
for naming a non-default account (e.g. `"work"`), `share="all_projects"` to
make the connection org-wide instead of project-only.

When to call: `check_connection` returns `connected: false` AND the user is
asking you to do something that needs the toolkit. Don't pre-emptively
connect things the user didn't ask for.

### `get_github_credential` — mint a github token for native git/gh

```bash
npx mcporter call aramb_toolkits.get_github_credential
```

### `get_github_credential` — mint a github token for native git/gh

```bash
npx mcporter call aramb_toolkits.get_github_credential
```

GitHub is **NOT a Composio toolkit** in this stack — it's served by gitana, a
separate broker. The agent does NOT use `composio execute GITHUB_*` (those
slugs are blocked on the `/cli` surface with `403`); instead it calls this
MCP tool to get a short-lived user OAuth token and then uses **native `git`
and `gh` CLI** for everything.

Optional `account_ref="ca_..."` disambiguates when the org has multiple
github connections in scope (`check_connection` / `list_connections` reports
this). Without it, the broker auto-resolves the single in-scope account and
returns `409 ambiguous_connection` if there are several.

Response:

```json
{ "username": "x-access-token",
  "token":    "gho_<token>",
  "account_ref": "ca_xxx",
  "expires_at":  "...",
  "scope":      "repo read:user user:email read:org workflow" }
```

The full workflow — happy path:

```bash
# 1. Confirm github is connected
npx mcporter call aramb_toolkits.check_connection toolkit="GITHUB"
# → { connected: true, account_ref: "ca_…", ... }

# 2. Get a token
npx mcporter call aramb_toolkits.get_github_credential
# → { token: "gho_…", username: "x-access-token", ... }

# 3. Export and use native CLI
export GH_TOKEN="gho_…"
git clone https://x-access-token:$GH_TOKEN@github.com/acme/repo.git
cd repo && git checkout -b feat/x && git push -u origin feat/x
gh pr create --title "..." --body "..."
gh issue list --repo acme/repo
gh release create v1.0.0 --notes "..."
```

On `401` from `git` / `gh` (~8h token lifetime), call `get_github_credential`
again for a fresh token — cheap, no rate concerns.

**Multiple github accounts in scope** (`ambiguous_connection` from
`get_github_credential`): call `list_connections toolkit="GITHUB"`, pick the
right `account_ref`, then re-call `get_github_credential
account_ref="ca_..."`.

**No github connection** (`check_connection` returns `connected: false`):
mint one from chat — do NOT just tell the user to "go to the Connections UI":

```bash
npx mcporter call aramb_toolkits.connect_toolkit toolkit="github"
# → { redirect_url: "https://github.com/login/oauth/authorize?...",
#     connected_account_id: "...",
#     status: "INITIATED" }
```

Share the `redirect_url` in chat ("Open this in your browser to connect
GitHub: …"). Once the user completes the flow, `check_connection` flips to
`ACTIVE` and `get_github_credential` works.

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
