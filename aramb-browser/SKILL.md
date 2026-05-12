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

A fork of chrome-devtools-mcp — standard CDP actions (click, fill, navigate, snapshot, …) work as expected. This skill covers Aramb lifecycle and the rules unique to it.

## When to use
Any task involving a URL, scraping, form interaction, screenshots, or live web data. If the user mentions a site or "go to / check / browse / open / scrape" — use this skill.

---

## `browser=` and `target=` — required on every page-level call

Every page-level tool response ends with:
```
---
browser: <app-slug> | target: <targetId> | url: <url>
```

- `browser` = the registered name (your app slug).
- `target` = the CDP tab UUID for the selected page.

**Rule:** every page-level call (`navigate_page`, `new_page`, `take_snapshot`, `take_screenshot`, `click`, `fill`, `select_page`, `close_page`, `list_pages`, `wait_for`, `evaluate_script`, `list_console_messages`, `list_network_requests`, etc.) must pass **both** `browser=<app-slug>` and `target=<targetId>`. Read the footer after each call and carry `target` forward.

Lifecycle tools (`browser_create`, `browser_list`, `browser_switch`, `browser_destroy`, `browser_stats`, `browser_clients_list`, `browser_session_*`) do **not** take `target=`. They accept an optional `application_id=<id>` to override `ARAMB_APP_ID` for that call.

---

## Provider flow — two tries, then stop

1. **aramb** (default, ~4s)
   ```bash
   mcporter call aramb-browser.browser_create name=<app-slug> provider=aramb ttl_minutes=30
   ```
2. **jumbo** (~40s) — only if aramb failed
   ```bash
   mcporter call aramb-browser.browser_create name=<app-slug> provider=jumbo ttl_minutes=60
   ```

If both fail, **stop and report**. Do not try harbor, browserbase, or docker automatically. Do not preemptively check `browser_clients_list`. Do not preemptively prompt about user-network.

### Reactive escalation — only after observing IP-driven blockage

If, **while using the site**, you hit repeated CAPTCHAs, 403s, rate-limit walls, geo-blocks, or login walls that look IP-triggered, stop and ask the user:

> Looks like `<site>` is blocking the datacenter IP (`<describe: CAPTCHA / 403 / rate-limit>`). Routing through your machine's network usually fixes it. To enable:
>
> ```
> npm install -g aramb
> aramb login
> aramb harbor
> ```
>
> Reply when it's running and I'll recreate the browser with user-network. Or reply "skip" to stop.

Then wait. On confirmation:
```bash
mcporter call aramb-browser.browser_clients_list          # get harbor_client_id
mcporter call aramb-browser.browser_destroy browser=<app-slug>
mcporter call aramb-browser.browser_create name=<app-slug> provider=aramb \
  use_user_network=true harbor_client_id=<id> ttl_minutes=30
# same two-try rule: fall back to provider=jumbo with use_user_network=true if aramb fails
```

---

## Reuse before create

```bash
mcporter call aramb-browser.browser_list
```
- App-slug match → `new_page browser=<app-slug>`, capture `target` from footer, proceed.
- No match → run the provider flow above.

---

## Rules

- **Name = app slug.** `name=<app-slug>` is mandatory on every `browser_create`.
- **Pass `browser=` and `target=` together** on every page-level call. Update `target` from each footer.
- **No autonomous retries on obstacles.** On CAPTCHA / bot check / login wall / unexpected redirect, screenshot, describe, ask. Surface the user-network prompt above only when the blockage looks IP-driven.
- **Snapshot only when needed** (before clicking, after navigation, when stuck). Each snapshot is heavy.

---

## Lifecycle reference

```bash
mcporter call aramb-browser.browser_list
mcporter call aramb-browser.browser_switch browser=<app-slug>
mcporter call aramb-browser.browser_destroy browser=<app-slug>          # auto-terminates ARAMB session
mcporter call aramb-browser.browser_stats
mcporter call aramb-browser.browser_session_list
mcporter call aramb-browser.browser_session_info session_id=<id>
mcporter call aramb-browser.browser_session_extend session_id=<id> minutes=<n>
```

---

## Scenarios

### Generic / public site
```bash
mcporter call aramb-browser.browser_list
mcporter call aramb-browser.browser_create name=<app-slug> provider=aramb ttl_minutes=30
mcporter call aramb-browser.navigate_page browser=<app-slug> url=https://example.com
# footer → target: <targetId>
mcporter call aramb-browser.take_snapshot browser=<app-slug> target=<targetId>
mcporter call aramb-browser.browser_destroy browser=<app-slug>
```

### Reuse existing browser
```bash
mcporter call aramb-browser.browser_list                                # finds <app-slug>
mcporter call aramb-browser.new_page browser=<app-slug>                 # footer → target: <targetId>
mcporter call aramb-browser.navigate_page browser=<app-slug> target=<targetId> url=https://example.com
```

### Parallel sub-agents, one browser, multiple tabs
```bash
mcporter call aramb-browser.browser_create name=<app-slug> provider=aramb ttl_minutes=30

# Sub-agent A
mcporter call aramb-browser.new_page browser=<app-slug>                 # footer → target: <targetId-A>
mcporter call aramb-browser.navigate_page browser=<app-slug> target=<targetId-A> url=https://site-a.com

# Sub-agent B (independent tab)
mcporter call aramb-browser.new_page browser=<app-slug>                 # footer → target: <targetId-B>
mcporter call aramb-browser.navigate_page browser=<app-slug> target=<targetId-B> url=https://site-b.com
```

### After IP blockage — recreate with user-network
See the reactive escalation block in the Provider flow.

---

## Task

$ARGUMENTS
