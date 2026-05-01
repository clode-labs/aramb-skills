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
mcporter call aramb-browser.browser_create name=<label> provider=aramb \
  use_user_network=true harbor_client_id=<id> ttl_minutes=30
```

If aramb creation fails → fallback to jumbo with user-network:
```bash
mcporter call aramb-browser.browser_create name=<label> provider=jumbo \
  use_user_network=true harbor_client_id=<id> ttl_minutes=60
```

### Step 4 — Create browser without user-network (for generic/public sites)

```bash
# Default: aramb
mcporter call aramb-browser.browser_create name=<label> provider=aramb ttl_minutes=30
```

If aramb creation fails → fallback to jumbo:
```bash
mcporter call aramb-browser.browser_create name=<label> provider=jumbo ttl_minutes=60
```

---

## RULES — Non-Negotiable

### Always name the browser and always pass `browser=`
- **`name` is mandatory** on every `browser_create` call. Choose a short descriptive label (e.g. `name=scraper`, `name=task1`).
- **Every tool call that accepts a `browser` param must include it** — `navigate_page`, `take_snapshot`, `take_screenshot`, `click`, `fill`, `new_page`, `select_page`, `close_page`, `list_pages`, `wait_for`, `evaluate_script`, `list_console_messages`, `list_network_requests`, etc.
- **Why:** `registry.json` persists browsers across sessions. Omitting `browser=` defaults to whatever is currently set as default — two agents can accidentally operate on the same page, causing interference.

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

### Create (always with a name)
```bash
# Standard — aramb, no user network
mcporter call aramb-browser.browser_create name=<label> provider=aramb ttl_minutes=30

# Bot-sensitive site — aramb with user network
mcporter call aramb-browser.browser_create name=<label> provider=aramb \
  use_user_network=true harbor_client_id=<id> ttl_minutes=30

# Harbor — real browser on user's machine
mcporter call aramb-browser.browser_create name=<label> provider=harbor harbor_client_id=<id>
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

### Destroy (auto-terminates Aramb session)
```bash
mcporter call aramb-browser.browser_destroy browser=<name>
# Automatically destroys the associated Aramb session — no need to pass session ID separately
```

### List / switch
```bash
mcporter call aramb-browser.browser_list
mcporter call aramb-browser.browser_switch browser=<name>
mcporter call aramb-browser.browser_session_list
mcporter call aramb-browser.browser_session_extend session_id=<id> minutes=<n>
```

---

## Scenarios

### Scrape a public site (generic, not bot-protected)
```bash
mcporter call aramb-browser.browser_create name=scraper provider=aramb ttl_minutes=30
mcporter call aramb-browser.navigate_page browser=scraper url=https://example.com
mcporter call aramb-browser.take_snapshot browser=scraper
# extract data from snapshot, click/fill as needed
mcporter call aramb-browser.browser_destroy browser=scraper
```

### Scrape a popular / bot-protected site (Reddit, LinkedIn, etc.)
```bash
# 1. Check for connected clients
mcporter call aramb-browser.browser_clients_list
# → no clients: run the Step 3a user prompt above, wait for user response
# → clients found: confirm client ID with user, then:

# 2. Create browser with user-network
mcporter call aramb-browser.browser_create name=scraper provider=aramb \
  use_user_network=true harbor_client_id=<id> ttl_minutes=30

# 3. Navigate and extract
mcporter call aramb-browser.navigate_page browser=scraper url=https://www.reddit.com/r/example/
mcporter call aramb-browser.take_snapshot browser=scraper filePath=/tmp/snap.txt
mcporter call aramb-browser.browser_destroy browser=scraper
```

### Open multiple tabs in one browser
```bash
mcporter call aramb-browser.browser_create name=multi provider=aramb ttl_minutes=30
mcporter call aramb-browser.navigate_page browser=multi url=https://site-a.com
mcporter call aramb-browser.new_page browser=multi url=https://site-b.com
mcporter call aramb-browser.list_pages browser=multi
mcporter call aramb-browser.select_page browser=multi pageId=2
mcporter call aramb-browser.take_snapshot browser=multi
mcporter call aramb-browser.browser_destroy browser=multi
```

### Use a real browser on user's machine (harbor)
```bash
mcporter call aramb-browser.browser_clients_list
# → no clients: tell user to run `aramb harbor`, wait for reconnect
# → clients found: confirm client ID with user, then:
mcporter call aramb-browser.browser_create name=local provider=harbor harbor_client_id=<id> ttl_minutes=30
mcporter call aramb-browser.navigate_page browser=local url=https://example.com
mcporter call aramb-browser.browser_destroy browser=local
```

---

## Task

$ARGUMENTS
