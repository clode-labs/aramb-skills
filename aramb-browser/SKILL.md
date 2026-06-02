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

```bash
npx mcporter call aramb-browser.browser_create name=<app-slug> provider=steel browser_type=chrome ttl_minutes=30
```

Steel is the default — it ships with residential proxy and managed captcha solving. `browser_type=chrome` is required.

Fails → stop and report. Don't autonomously retry.

### Optional `browser_create` inputs

- `session_context=<string>` — replay a previously captured browser-context string (cookies + per-origin storage) inline at create time, instead of running `browser_load_context` afterwards. Pass the opaque value returned by `browser_save_context` verbatim.
- `use_proxy=true|false` — opt into the residential proxy. Defaults to true.
- `auto_solve_captcha=true|false` — opt into automatic captcha solving. Defaults to true.

### Steel + captcha

When a steel session is solving a captcha, the Aramb viewer UI shows a "solving captcha" status. Don't interact with the page, navigate, or recreate the browser while it's in that state — wait for the status to clear, then continue.

Chain create + first navigate in one Bash call (shell `cwd` resets between mcporter calls; `&&` avoids drift):

```bash
npx mcporter call aramb-browser.browser_create name=<app-slug> provider=steel browser_type=chrome ttl_minutes=30 \
  && npx mcporter call aramb-browser.navigate_page browser=<app-slug> url=https://example.com
```

### Captcha-protected page — wait, then ask

The browser clears most captchas (reCAPTCHA, Cloudflare Turnstile, hCaptcha, etc.) in the background. If you hit a challenge, **wait 30-60s** and re-check — `navigate_page` to refresh, or `evaluate_script` to read `location.href` / `document.title` / page content. Most pages clear on their own in that window.

If after ~60s the page is still blocked, **stop and ask the user**. Don't retry, don't loop, don't recreate the browser.

> `<site>` is still blocked after waiting. Looks like a `<captcha challenge | login wall | rate limit | empty body / generic block>`. How would you like to proceed?
>
> - **Open the browser viewer in the app and clear the challenge yourself** — fastest and most reliable. Tell me when you're past the gate and I'll continue from the same session.
> - Wait and retry later
> - Try a different URL on the same site
> - Skip this site

Let the user pick. When they take the viewer route, **don't refresh, navigate, or recreate the browser** while they're working — same session = same cookies + challenge progress. After they confirm they're through, re-run your last `evaluate_script` to extract from the now-cleared page.

## Named contexts — save & reuse logged-in state

A **context** is a tarball of cookies + per-origin storage saved against your user, identified by name. Replay it on future sessions to skip re-authentication.

### When to use — always ask the user first

**Never save or load a context without explicit user approval.** Both directions require a prompt.

**Before `browser_create`** (any task that needs a new browser): run `browser_context_list`. If saved contexts exist, show them and let the user pick or skip:

> Starting a browser for `<app-slug>`. Saved contexts:
> - `<name-1>`
> - `<name-2>`
>
> Load one to reuse a logged-in session, or start fresh? Reply with a name, or "skip".

User picks a name → pass `session_context=<value>` to `browser_create`, or call `browser_load_context` after create. User says "skip" / no contexts exist → vanilla `browser_create`. Never auto-load.

**After a successful login** (you completed an auth flow, or the user confirmed they signed in via the viewer): ask before saving.

> Logged in to `<site>`. Save this session as a context so the next run for `<app-slug>` skips the login? Suggested name: `<app-slug>-login`. (yes / no / different name)

Only call `browser_context_create` + `browser_save_context` if the user confirms. If they decline, leave the state in memory — the live browser still works for this task; nothing persists.

### Commands

```bash
# List
npx mcporter call aramb-browser.browser_context_list

# Reserve a slot (required before first save)
npx mcporter call aramb-browser.browser_context_create context_name=<name>

# Save current browser state into the slot
npx mcporter call aramb-browser.browser_save_context browser=<app-slug> context_name=<name>

# Apply a saved context onto a live browser
npx mcporter call aramb-browser.browser_load_context browser=<app-slug> context_name=<name>

# Delete (Redis record + S3 tarball)
npx mcporter call aramb-browser.browser_context_destroy context_name=<name>
```

Naming: one context per app-slug per logical identity (e.g. `reddit-gather-a-login`). Reuse the same name; re-save (after user approval) only when state has materially changed.

Error behavior:

- `browser_load_context` on a missing name → reserve + save first.
- `browser_save_context` on a missing name → `browser_context_create` first.
- `browser_context_create` on an existing name (409) → pick a new name or destroy the old one.
- `browser_context_destroy` on a missing name → check `browser_context_list`.

## Rules (no exceptions)

- All web access goes through this skill. No `WebSearch` / `WebFetch` / `curl` / `wget` / script HTTP.
- `browser_list` BEFORE `browser_create`. Reuse the matching slug.
- `name=<app-slug>` on every `browser_create`. Never invent names.
- `browser=` AND `target=` on every page-level call.
- One browser per app slug. Siblings reuse via `new_page`, not a second `browser_create`.
- **Never call `browser_destroy`.** TTL cleans up.
- **Never save or load a context without explicit user approval.** Before `browser_create`, run `browser_context_list` and prompt the user to pick or skip. After a successful login, prompt before `browser_save_context`.
- `evaluate_script` uses `function=` (NOT `script=`). Body is a JS arrow function: `function="() => JSON.stringify(...)"`.
- On CAPTCHA / bot wall / 403: **wait 30-60s** for the browser to clear it in the background, then re-check the page. If still blocked, stop and ask the user — describe what you saw, never auto-recommend a specific fix.
- Snapshots are heavy. Use only before click or when stuck. Prefer `evaluate_script` for data extraction.

## Scenarios

### Start a session
```bash
npx mcporter call aramb-browser.browser_list
# slug present → new_page browser=<app-slug>, capture target, navigate
# slug absent  → browser_context_list, prompt user to load a saved context or skip,
#                then browser_create name=<app-slug> provider=steel browser_type=chrome ttl_minutes=30 [session_context=<value>]
#                && navigate_page browser=<app-slug> url=...
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
