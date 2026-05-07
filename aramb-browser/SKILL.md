---
name: aramb-browser
description: >
  Control a Chrome browser to navigate pages, take screenshots, fill forms, scrape
  content, run scripts, inspect network requests, and manage multiple browser
  instances. Use when asked to visit a URL, test a web page, extract data from a
  site, automate web interactions, or use cloud browsers via Aramb.
argument-hint: "[task or URL]"
---

# Browser Automation via Aramb Browser

All tools: `mcporter call aramb-browser.<tool> [param=value ...]`

The underlying tools are a fork of chrome-devtools-mcp — standard CDP interactions (click, fill, navigate, snapshot, etc.) work as expected. This skill focuses on Aramb browser lifecycle and scenario rules only.

---

## WHEN TO USE THIS SKILL

Use aramb-browser any time the task involves:
- Visiting a URL or navigating a website
- Reading, scraping, or extracting content from a live web page
- Filling forms, clicking buttons, or interacting with a site
- Taking screenshots of web pages
- Checking live pricing, availability, or data on a website
- Automating any web workflow

**Decision rule:** If the task mentions a URL, a website name, "go to", "check", "scrape", "browse", "open", "visit", "search on", or any live web interaction — use aramb-browser. Do not attempt to fetch web content any other way.

---

## BROWSER & TARGET INJECTION (READ THIS FIRST)

Every browser-bound tool response ends with a footer:

```
---
browser: <app-slug> | target: <targetId> | url: <url>
```

- **`browser`** is the registered browser name (the `<app-slug>` you used at create time).
- **`target`** is the CDP tab UUID for the currently selected page in that browser.
- **`url`** is the URL of that selected tab.

**Rule:** every tool call against a page must pass both `browser=<app-slug>` and `target=<targetId>`. After any tool call, update your working `target` from the footer — it confirms which tab you're on.

**Why both:** parallel agents or sub-agents sharing the same browser must each work on their own tab. Without `target=`, the call defaults to whichever tab is currently selected, causing interference.

---

## BROWSER_* COMMANDS (full list)

These are the lifecycle / management tools. They operate on the registry or the ARAMB API, not on a page, so they do **not** take `target=`. Most accept an optional `application_id` that overrides the `ARAMB_APP_ID` env var for ARAMB session tracking.

| Tool | Purpose | Takes `browser=` | Takes `target=` | Takes `application_id=` |
|---|---|---|---|---|
| `browser_create` | Create a new browser (ARAMB session + registry entry) | no (uses `name=`) | no | yes |
| `browser_list` | List all registered browsers | no | no | no |
| `browser_switch` | Change the default browser | yes (required) | no | no |
| `browser_destroy` | Destroy a browser + auto-terminate its ARAMB session | yes (required) | no | yes |
| `browser_stats` | Registry statistics | no | no | no |
| `browser_clients_list` | List connected harbor (Louie) clients | no | no | yes |
| `browser_session_list` | List ARAMB sessions (status filter, pagination) | no | no | yes |
| `browser_session_info` | Detailed info for one ARAMB session | no | no | yes |
| `browser_session_extend` | Extend an ARAMB session TTL by N minutes | no | no | yes |

**`application_id` behavior:** if omitted, the server falls back to `ARAMB_APP_ID` from the environment. Pass `application_id=<id>` only when you need to override that env var for a specific call (e.g. operating against a different ARAMB application than the default).

---

## BROWSER REUSE FLOW

**Always check for an existing browser before creating one.** Browsers are named after the app slug (e.g. `my-app`).

### Step 1 — List existing browsers

```bash
mcporter call aramb-browser.browser_list
```

- **A browser named `<app-slug>` exists** → reuse it (go to Step 2a).
- **No match** → create a new one (go to the Provider Decision Flow, then Step 2b).

### Step 2a — Reuse an existing browser

Open a fresh empty tab in the existing browser and capture the `target` from the response footer:

```bash
mcporter call aramb-browser.new_page browser=<app-slug>
```

Read the `target` value from the footer — use it as `target=<targetId>` in every subsequent call.

```bash
# All subsequent calls must include both browser= and target=
mcporter call aramb-browser.navigate_page browser=<app-slug> target=<targetId> url=https://...
mcporter call aramb-browser.take_snapshot browser=<app-slug> target=<targetId>
mcporter call aramb-browser.click browser=<app-slug> target=<targetId> uid=<uid>
```

### Step 2b — Create a new browser (no match found)

Follow the Provider Decision Flow below to decide on provider and network. Always use the app slug as the name:

```bash
mcporter call aramb-browser.browser_create name=<app-slug> provider=aramb ttl_minutes=30
# Optional: application_id=<id> to override ARAMB_APP_ID for this call
```

After creation, open an initial page and get the `target` from the footer:

```bash
mcporter call aramb-browser.navigate_page browser=<app-slug> url=about:blank
# → footer gives you: target: <targetId>
# Use target=<targetId> for all subsequent calls
```

---

## PROVIDER DECISION FLOW

Before creating a browser, follow this flow every time:

### Step 1 — Is the site popular / likely to block datacenter IPs?

**Popular / restricted sites** (non-exhaustive — use judgement for similar ones):
- Social: LinkedIn, Reddit, Twitter/X, Facebook, Instagram, TikTok
- CRM / SaaS: Salesforce, HubSpot, Pipedrive, Zendesk
- Job boards: Indeed, Glassdoor, LinkedIn Jobs
- E-commerce: Amazon, eBay, Shopify stores
- News / media with paywalls or bot protection

**If the site is popular or likely bot-protected → go to Step 2.**
**If the site is a generic/public site with no known bot protection → go to Step 4 (use aramb directly).**

### Step 2 — Check for a connected harbor client

```bash
mcporter call aramb-browser.browser_clients_list
```

- **Clients found** → tell the user which client(s) are available, confirm which to use, then go to Step 3.
- **No clients found** → go to Step 3a.

### Step 3a — No client connected: prompt the user

Tell the user **exactly** this (copy verbatim):

> **Web surfing via your machine's network**
>
> The site you're targeting (`<site>`) is popular and may block datacenter IP addresses. To route the browser through your machine:
>
> 1. Install aramb (if not already installed):
>    ```
>    npm install -g aramb
>    ```
> 2. Log in:
>    ```
>    aramb login
>    ```
> 3. Connect your machine as a harbor client:
>    ```
>    aramb harbor
>    ```
> 4. Reply here once it's running and I'll continue.
>
> **Alternatively**, reply "proceed anyway" and I'll try with a datacenter IP (may be blocked or rate-limited).

Then **stop and wait**. Do not proceed until the user responds.

- User connects a client → re-run `browser_clients_list`, confirm client ID, go to Step 3.
- User says "proceed anyway" → go to Step 4, but warn in your response: "Proceeding without user-network — site may block or challenge the request."

### Step 3 — Create browser with user-network (for popular sites)

```bash
mcporter call aramb-browser.browser_create name=<app-slug> provider=aramb \
  use_user_network=true harbor_client_id=<id> ttl_minutes=30
```

If aramb creation fails → fallback to jumbo with user-network:
```bash
mcporter call aramb-browser.browser_create name=<app-slug> provider=jumbo \
  use_user_network=true harbor_client_id=<id> ttl_minutes=60
```

### Step 4 — Create browser without user-network (for generic/public sites)

```bash
# Default: aramb
mcporter call aramb-browser.browser_create name=<app-slug> provider=aramb ttl_minutes=30
```

If aramb creation fails → fallback to jumbo:
```bash
mcporter call aramb-browser.browser_create name=<app-slug> provider=jumbo ttl_minutes=60
```

---

## RULES — Non-Negotiable

### Always name the browser with the app slug
- **`name` is mandatory** on every `browser_create` call. Use the app slug (e.g. `my-app`).
- The name is used as the browser ID directly — `browser=my-app` works in all subsequent calls.

### Always pass `browser=` and `target=` together
- **Every page-level tool call must include both `browser=<app-slug>` and `target=<targetId>`** — `navigate_page`, `take_snapshot`, `take_screenshot`, `click`, `fill`, `new_page`, `select_page`, `close_page`, `list_pages`, `wait_for`, `evaluate_script`, `list_console_messages`, `list_network_requests`, etc.
- The `target` is the CDP tab UUID printed in every tool response footer. Read it once after creating a page and carry it forward.
- The `browser_*` lifecycle tools (see table above) do not take `target=` — they operate on the registry or ARAMB API, not on a page.

### `application_id` on browser_* tools
- `browser_create`, `browser_destroy`, `browser_clients_list`, `browser_session_list`, `browser_session_info`, and `browser_session_extend` all accept an optional `application_id=<id>`.
- It overrides the `ARAMB_APP_ID` environment variable for that single call.
- Omit it to use the configured environment default.

### Reading the footer
Every page-level tool response ends with:
```
---
browser: <app-slug> | target: <targetId> | url: <url>
```
After any tool call, update your working `target` from this footer — it confirms which tab you're on.

### Obstacle escalation
- If a bot check, CAPTCHA, login wall, challenge page, or unexpected redirect appears — **stop immediately**.
- Take a screenshot, describe the obstacle, and ask the user how to proceed.
- Never retry, reload, or attempt workarounds autonomously.

### Snapshot discipline
- Take a snapshot only when needed (before clicking, after navigation, or when stuck).
- Do not take repeated snapshots speculatively — each consumes significant context.

---

## Providers

| Provider | Ready time | When to use |
|----------|-----------|-------------|
| **aramb** | ~4s | **Default.** Pre-deployed pods in Aramb k8s cluster. Use for all tasks. |
| **jumbo** | ~40s | Fallback if aramb unavailable. Spun up on-demand. |
| **harbor** | instant | Real browser on user's machine via harbor client. |

**aramb and jumbo both support `use_user_network=true`** — routes all browser traffic through the user's machine via CloudConnect (SOCKS). Required for bot-sensitive sites (Reddit, etc.).

---

## Browser Lifecycle

### Create (always with app slug as name)
```bash
# Standard — aramb, no user network
mcporter call aramb-browser.browser_create name=<app-slug> provider=aramb ttl_minutes=30

# Bot-sensitive site — aramb with user network
mcporter call aramb-browser.browser_create name=<app-slug> provider=aramb \
  use_user_network=true harbor_client_id=<id> ttl_minutes=30

# Harbor — real browser on user's machine
mcporter call aramb-browser.browser_create name=<app-slug> provider=harbor harbor_client_id=<id>

# Override ARAMB_APP_ID for this call only
mcporter call aramb-browser.browser_create name=<app-slug> provider=aramb \
  application_id=<id> ttl_minutes=30
```

Before using `use_user_network=true` or `harbor`:
```bash
mcporter call aramb-browser.browser_clients_list
# → no clients: instruct user to run the command below, then wait and retry
# → clients found: present list, ask user which to use, then pass harbor_client_id=<id>
```

If no harbor client is connected, tell the user:
> "No harbor client connected. Please run the following command in your terminal to connect:
> ```
> aramb harbor
> ```
> Once connected, let me know and I'll continue."

Then **stop and wait** — do not proceed until the client appears in `browser_clients_list`.

### Destroy (auto-terminates ARAMB session)
```bash
mcporter call aramb-browser.browser_destroy browser=<app-slug>
# Optional: application_id=<id>
# Automatically destroys the associated ARAMB session — no need to pass session ID separately
```

### List / switch / inspect sessions
```bash
mcporter call aramb-browser.browser_list
mcporter call aramb-browser.browser_switch browser=<app-slug>
mcporter call aramb-browser.browser_stats
mcporter call aramb-browser.browser_session_list
mcporter call aramb-browser.browser_session_info session_id=<id>
mcporter call aramb-browser.browser_session_extend session_id=<id> minutes=<n>
```

---

## Scenarios

### Scrape a public site (generic, not bot-protected)
```bash
# 1. Check for an existing browser first
mcporter call aramb-browser.browser_list
# → no browser named <app-slug>: create one
mcporter call aramb-browser.browser_create name=<app-slug> provider=aramb ttl_minutes=30

# 2. Open initial page and capture targetId from footer
mcporter call aramb-browser.navigate_page browser=<app-slug> url=https://example.com
# footer → target: <targetId>

# 3. All subsequent calls use both browser= and target=
mcporter call aramb-browser.take_snapshot browser=<app-slug> target=<targetId>
# extract data from snapshot, click/fill as needed
mcporter call aramb-browser.browser_destroy browser=<app-slug>
```

### Reuse an existing browser (app slug already registered)
```bash
# 1. List browsers — find <app-slug>
mcporter call aramb-browser.browser_list
# → browser named <app-slug> found

# 2. Open a fresh empty tab
mcporter call aramb-browser.new_page browser=<app-slug>
# footer → target: <targetId>  ← capture this

# 3. Navigate and work on that tab
mcporter call aramb-browser.navigate_page browser=<app-slug> target=<targetId> url=https://example.com
mcporter call aramb-browser.take_snapshot browser=<app-slug> target=<targetId>
```

### Scrape a popular / bot-protected site (Reddit, LinkedIn, etc.)
```bash
# 1. Check for connected clients
mcporter call aramb-browser.browser_clients_list
# → no clients: run the Step 3a user prompt above, wait for user response
# → clients found: confirm client ID with user, then:

# 2. Check for existing browser, create if needed
mcporter call aramb-browser.browser_list
mcporter call aramb-browser.browser_create name=<app-slug> provider=aramb \
  use_user_network=true harbor_client_id=<id> ttl_minutes=30

# 3. Navigate and capture targetId
mcporter call aramb-browser.navigate_page browser=<app-slug> url=https://www.reddit.com/r/example/
# footer → target: <targetId>

mcporter call aramb-browser.take_snapshot browser=<app-slug> target=<targetId> filePath=/tmp/snap.txt
mcporter call aramb-browser.browser_destroy browser=<app-slug>
```

### Parallel sub-agents sharing one browser (multi-tab)
```bash
# Root agent creates the browser once
mcporter call aramb-browser.browser_list
# → no <app-slug> browser: create
mcporter call aramb-browser.browser_create name=<app-slug> provider=aramb ttl_minutes=30

# Each sub-agent opens its own tab and captures its own targetId
# Sub-agent A:
mcporter call aramb-browser.new_page browser=<app-slug>
# footer → target: <targetId-A>
mcporter call aramb-browser.navigate_page browser=<app-slug> target=<targetId-A> url=https://site-a.com

# Sub-agent B (parallel, independent):
mcporter call aramb-browser.new_page browser=<app-slug>
# footer → target: <targetId-B>
mcporter call aramb-browser.navigate_page browser=<app-slug> target=<targetId-B> url=https://site-b.com
```

### Use a real browser on user's machine (harbor)
```bash
mcporter call aramb-browser.browser_clients_list
# → no clients: tell user to run `aramb harbor`, wait for reconnect
# → clients found: confirm client ID with user, then:
mcporter call aramb-browser.browser_list
# → no <app-slug> browser: create
mcporter call aramb-browser.browser_create name=<app-slug> provider=harbor harbor_client_id=<id> ttl_minutes=30
mcporter call aramb-browser.navigate_page browser=<app-slug> url=https://example.com
# footer → target: <targetId>
mcporter call aramb-browser.browser_destroy browser=<app-slug>
```

---

## Task

$ARGUMENTS
