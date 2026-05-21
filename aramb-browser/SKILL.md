---
name: aramb-browser
description: >
  The ONLY way to touch the web. Every URL visit, scrape, search engine
  query, form fill, screenshot, JS evaluation, or live data fetch goes
  through this skill. No WebSearch, WebFetch, curl, wget, or HTTP
  libraries — they use the datacenter UA, can't execute JS, and return
  SPA HTML or 403 from any half-restricted site. Fork of
  chrome-devtools-mcp; standard CDP actions all work.
argument-hint: "[task or URL]"
---

# Aramb Browser

All tools: `npx mcporter call aramb-browser.<tool> [param=value ...]`

## Use this for every web touch — no exceptions

URL visits, search-engine queries, scraping, form interaction, JSON endpoints behind public sites (Reddit/X/LinkedIn `.json` returns HTML), JS evaluation, network inspection, live pricing/status — all of it.

**Forbidden:** built-in `WebSearch` / `WebFetch` / `Fetch`, `curl`, `wget`, `httpie`, Node `fetch`, Python `requests`, or any script that makes HTTP calls. There is no "this site is simple, let me just curl it" exception.

## Browser name = app slug. Always reuse.

`name=<app-slug>` is mandatory on every `browser_create`. The app slug is in your workspace path (e.g. `/home/node/workspace/reddit-gather-a-9920b7f` → slug `reddit-gather-a-9920b7f`), in `$APPLICATION_SLUG`, and in the dispatch prompt. Never use generic names (`default`, `scraper`, `researcher`) — they collide across apps.

**Start every web task by listing.** Always:

```bash
npx mcporter call aramb-browser.browser_list
```

- Slug matches an existing browser → **reuse it**. `new_page browser=<app-slug>`, capture `target` from the footer, navigate.
- No match → run the provider flow below.

**Never call `browser_destroy`.** The browser persists across tasks and sibling sub-agents on the same app; destroying it forces every other task to recreate. TTL handles cleanup. When your work is done, leave it.

## `target=` on every page-level call

Page-level tool responses end with a footer:

```
--- browser: <app-slug> | target: <targetId> | url: <url>
```

Pass **both** `browser=<app-slug>` AND `target=<targetId>` on every page-level call (`navigate_page`, `take_snapshot`, `take_screenshot`, `click`, `fill`, `select_page`, `close_page`, `list_pages`, `wait_for`, `evaluate_script`, `list_console_messages`, `list_network_requests`). Read the footer and carry `target` forward.

Without `target=`, the call lands on whichever tab is "selected" — which is whatever tab a sibling sub-agent navigated last. Always pin the tab.

Lifecycle tools (`browser_create`, `browser_list`, `browser_switch`, `browser_stats`, `browser_clients_list`, `browser_session_*`, `browser_context_*`, `browser_save_context`, `browser_load_context`, `new_page`) do NOT take `target=`.

## Provider flow — one try, then stop

Only if `browser_list` had no match for your slug:

1. **aramb** (~4s, default)
   ```bash
   npx mcporter call aramb-browser.browser_create name=<app-slug> provider=aramb ttl_minutes=30
   ```

Fails → stop and report. Don't autonomously try other providers; don't preemptively prompt about user-network.

Chain create + first navigate in one Bash call (shell `cwd` resets between mcporter calls; `&&` avoids drift):

```bash
npx mcporter call aramb-browser.browser_create name=<app-slug> provider=aramb ttl_minutes=30 \
  && npx mcporter call aramb-browser.navigate_page browser=<app-slug> url=https://example.com
```

### Captcha-protected page — wait, then ask

The browser clears most captchas (reCAPTCHA, Cloudflare Turnstile, hCaptcha, etc.) in the background. If you hit a challenge, **wait 30-60s** and re-check — `navigate_page` to refresh, or `evaluate_script` to read `location.href` / `document.title` / page content. Most pages clear on their own in that window.

If after ~60s the page is still blocked, **stop and ask the user**. Don't retry, don't loop, don't recreate the browser.

> `<site>` is still blocked after waiting. Looks like a `<captcha challenge | login wall | rate limit | empty body / generic block>`. How would you like to proceed?
>
> - **Open the browser viewer in the app and clear the challenge yourself** — fastest and most reliable. Tell me when you're past the gate and I'll continue from the same session.
> - Route through your machine's network (requires a connected local Aramb client)
> - Wait and retry later
> - Try a different URL on the same site
> - Skip this site

Let the user pick. When they take the viewer route, **don't refresh, navigate, or recreate the browser** while they're working — same session = same cookies + challenge progress. After they confirm they're through, re-run your last `evaluate_script` to extract from the now-cleared page.

**Do not autonomously set up the local Aramb client.** If the user picks the user-network route and a client is already connected:

```bash
npx mcporter call aramb-browser.browser_clients_list   # get client_id
npx mcporter call aramb-browser.browser_create name=<app-slug> provider=aramb \
  use_user_network=true client_id=<id> ttl_minutes=30
```

If no client is connected yet, ask the user to start their local Aramb client and confirm before recreating the browser.

## Named contexts — save & reuse logged-in state

A **context** is a tarball of cookies + per-origin storage saved against your user, identified by name. Use it to log in once, then replay that state on future Aramb sessions without re-authenticating — a session-survival mechanism on top of TTL.

Save / load only work against **Aramb-backed** browsers (browsers that have a `session_id` — anything created via `browser_create` provider=aramb qualifies). Local browsers don't have a session_id and can't participate.

```bash
# List contexts you've saved
npx mcporter call aramb-browser.browser_context_list

# Save the current state of a live browser into a named slot
npx mcporter call aramb-browser.browser_save_context browser=<app-slug> context_name=<name>

# Apply a previously saved context onto a live browser
npx mcporter call aramb-browser.browser_load_context browser=<app-slug> context_name=<name>

# Delete a saved context (Redis record + S3 tarball)
npx mcporter call aramb-browser.browser_context_destroy context_name=<name>
```

Typical flow — log in once, replay on every future session for the same app:

```bash
# First session: reserve the slot, do the login (manual via viewer or click+fill), then snapshot it
npx mcporter call aramb-browser.browser_context_create context_name=<app-slug>-login
npx mcporter call aramb-browser.browser_save_context browser=<app-slug> context_name=<app-slug>-login

# Every subsequent session: skip login entirely
npx mcporter call aramb-browser.browser_create name=<app-slug> provider=aramb ttl_minutes=30
npx mcporter call aramb-browser.browser_load_context browser=<app-slug> context_name=<app-slug>-login
npx mcporter call aramb-browser.navigate_page browser=<app-slug> url=https://<site>/dashboard
```

Save and create are separate operations — `browser_save_context` only writes into an **existing** slot, it does not create one. Reserve with `browser_context_create` first.

Naming: one context per app-slug per logical identity (e.g. `reddit-gather-a-login`). Reuse the same name across sessions — load it, work, leave it; save again only when the state has materially changed (logged in fresh, accepted new cookies, completed an onboarding step). Re-saves overwrite the stored tarball.

Error behavior:

- `browser_load_context` on a missing name → error pointing at `browser_save_context`. The context doesn't exist yet; capture state first against a logged-in browser.
- `browser_save_context` on a missing name → error pointing at `browser_context_create`. Reserve the slot first, then save.
- `browser_context_create` on an existing name (409) → error pointing at `browser_context_destroy`. Pick a new name or delete the old one.
- `browser_context_destroy` on a missing name → error pointing at `browser_context_list`.

## Rules (no exceptions)

- All web access goes through this skill. No `WebSearch` / `WebFetch` / `curl` / `wget` / script HTTP.
- `browser_list` BEFORE `browser_create`. Reuse the matching slug.
- `name=<app-slug>` on every `browser_create`. Never invent names.
- `browser=` AND `target=` on every page-level call.
- One browser per app slug. Siblings reuse via `new_page`, not a second `browser_create`.
- **Never call `browser_destroy`.** TTL cleans up.
- `evaluate_script` uses `function=` (NOT `script=`). Body is a JS arrow function: `function="() => JSON.stringify(...)"`.
- On CAPTCHA / bot wall / 403: **wait 30-60s** for the browser to clear it in the background, then re-check the page. If still blocked, stop and ask the user — describe what you saw, never auto-recommend a specific fix.
- Snapshots are heavy. Use only before click or when stuck. Prefer `evaluate_script` for data extraction.

## Scenarios

### Start a session
```bash
npx mcporter call aramb-browser.browser_list
# slug present → new_page browser=<app-slug>, capture target, navigate
# slug absent  → browser_create name=<app-slug> provider=aramb ttl_minutes=30 && navigate_page browser=<app-slug> url=...
```

### Scrape Reddit / social — browser, never `.json` curl
```bash
npx mcporter call aramb-browser.navigate_page browser=<app-slug> target=<tid> \
  url="https://old.reddit.com/r/<sub>/top/?t=month"
npx mcporter call aramb-browser.evaluate_script browser=<app-slug> target=<tid> \
  function="() => Array.from(document.querySelectorAll('.thing.link')).map(el => ({title: el.querySelector('a.title')?.textContent?.trim(), url: el.querySelector('a.comments')?.href, score: el.querySelector('.score.unvoted')?.title}))"
```

### Search engine query — browser, not WebSearch
```bash
npx mcporter call aramb-browser.navigate_page browser=<app-slug> target=<tid> \
  url="https://duckduckgo.com/?q=<query>"
npx mcporter call aramb-browser.evaluate_script browser=<app-slug> target=<tid> \
  function="() => Array.from(document.querySelectorAll('article')).map(a => ({title: a.querySelector('h2')?.innerText, url: a.querySelector('a')?.href}))"
```

### Parallel sub-agents — one browser, isolated tabs
```bash
# Agent A
npx mcporter call aramb-browser.new_page browser=<app-slug>      # footer → target-A
npx mcporter call aramb-browser.navigate_page browser=<app-slug> target=<target-A> url=https://a.com
# Agent B (no collision with A)
npx mcporter call aramb-browser.new_page browser=<app-slug>      # footer → target-B
npx mcporter call aramb-browser.navigate_page browser=<app-slug> target=<target-B> url=https://b.com
```

## Task

$ARGUMENTS
