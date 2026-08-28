---
name: aramb-browser
description: >
  The way to touch JS-rendered, authenticated, or visually-inspected web
  content — every URL visit, scrape, search engine query, form fill,
  screenshot, JS evaluation, or live data fetch on a rendered/restricted
  site goes through this skill. For those sites do NOT use WebSearch,
  WebFetch, curl, wget, or HTTP libraries — they use the datacenter UA,
  can't execute JS, and return SPA HTML or 403 from any half-restricted
  site. Public/static content (GitHub repos & raw files, plain pages,
  JSON/APIs) is the opposite case — fetch it with curl/git clone/WebFetch,
  not the browser (see the Fetch hierarchy). Fork of chrome-devtools-mcp;
  standard CDP actions all work.
argument-hint: "[task or URL]"
---

# Aramb Browser

All tools: `npx mcporter call aramb_browser.<tool> [param=value ...]`

> **Heads-up — mcp server renamed.** The mcp server used to be
> `aramb-browser` (hyphenated) and is now `aramb_browser` (underscored), to
> match the rest of the `aramb_*` namespaces. The binary on disk is still
> `aramb-browser`; only the mcp-server name changed. Always call
> `aramb_browser.<tool>` — the hyphenated form is no longer registered, so a
> `aramb-browser.<tool>` call will be rejected as an unknown server.

## Fetch hierarchy — reach for the browser LAST

Before you open a browser, ask: **does this content actually need a rendered DOM, JS execution, a login, or visual inspection?** If not, fetch it the cheap, reliable way. The browser is 30–120s per call and **hiccups** under load (mid-run batch failures, partial fetches); `curl` / `git clone` do not. Routing public files through a headless browser is the single biggest cause of slow, flaky big-node runs — don't.

**Default to non-browser fetch for public / static content.** Use `curl`, `git clone --depth 1`, or `WebFetch` from Bash for:

- **Public GitHub repos & raw files** — `git clone --depth 1 https://github.com/<owner>/<repo>` or `curl -sL https://raw.githubusercontent.com/<owner>/<repo>/<branch>/<path>`. ~50× faster than driving the browser, and it never "hiccups."
- **Plain HTML pages, raw/exported docs, and real API / JSON endpoints** whose content is in the response body, not assembled client-side. (Two traps: many "public" Notion / Google Docs / Drive pages are JS-rendered and return a near-empty shell to `curl`, and social `.json` URLs — Reddit / X / LinkedIn — return HTML, not JSON. Those are **browser** cases. When unsure, `curl` first and apply the escalation rule below.)

**Public repos need NO auth, NO GitHub toolkit, NO OAuth.** Never reason "the GitHub toolkit isn't connected, so I'll use the browser to hit the API" — a public repo is a plain `git clone` / `curl`. If you discover an unmetered raw URL (e.g. `raw.githubusercontent.com`), `curl` it directly; do **not** route it through the browser.

**Toolkit-unconnected fallback is curl, never the browser.** If a toolkit (GitHub, Sheets, …) isn't connected, fall back to the **unauthenticated** public path (`curl` / `clone` / public API). Never fall back to the browser to scrape what `curl` can fetch.

**Use the browser ONLY for** content that genuinely requires a real, rendered browser:

- JS-rendered / client-side-rendered pages where the meaningful content isn't in the initial HTML.
- Authenticated / gated content — login walls, dashboards behind auth.
- Visual inspection — Figma, Rive, interactive web apps, canvas, anything you need to *see* rendered.
- Sites that return SPA HTML or 403 to a datacenter UA (most half-restricted sites — the sections below cover these).

**Never drive the browser to fetch a file you could `curl`.**

**Escalation — curl first, browser on failure.** The hierarchy is a default, not a guess you're locked into. If a `curl` / `WebFetch` of a supposedly-static page comes back as **SPA HTML, a near-empty shell, a login/redirect, or a 403**, that page was actually rendered or restricted — switch to the browser for it. So the rule is: try the cheap fetch first for anything that *looks* public/static; escalate to the browser the moment the response proves it wasn't. Content you already know needs JS / auth / visual inspection (the list below) skips straight to the browser.

## Use this for every (rendered / restricted) web touch — no exceptions

For the content that *does* need a browser (per the Fetch hierarchy above), this skill is the only path — no escape hatch.

URL visits to JS-rendered or restricted pages, search-engine queries, scraping, form interaction, JSON endpoints behind public sites (Reddit/X/LinkedIn `.json` returns HTML), JS evaluation, network inspection, live pricing/status — all of it.

**Forbidden for this class of content:** built-in `WebSearch` / `WebFetch` / `Fetch`, `curl`, `wget`, `httpie`, Node `fetch`, Python `requests`, or any script that makes HTTP calls — against restricted / JS-rendered / gated sites they hit the datacenter-UA wall and return SPA HTML or 403. There is no "this restricted site is simple, let me just curl it" exception. (The opposite case — public/static files like GitHub raw — is exactly what the **Fetch hierarchy** sends to `curl`; don't browser those.)

## Deliver the session — mandatory after create, mandatory when asking the user

Every browser session you open or attach to must be surfaced to the user via `aramb_mcp.chat_deliver_artifacts` with a `browser_session` artifact. The chip routes the workbench's browser panel to the live session so the user can see exactly what you're doing.

**Fire it in two cases — no exceptions:**

1. **Right after `browser_create` succeeds** (or right after a `browser_list` reuse hits an existing session you're about to drive). The first chip pins the workbench tab open before you do anything visible — the user shouldn't have to hunt for it after the fact.
2. **Every time you're about to pause and ask the user for input or attention** — captcha challenge, login wall, "stop and ask" path, "open the viewer and clear it yourself" prompts. The chip is what gives the user a one-click route into the live browser; surfacing the question without the chip leaves them blind.

```bash
npx mcporter call aramb_mcp.chat_deliver_artifacts \
  project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" \
  artifacts='[{"kind":"browser_session","session_id":"<app-slug>","title":"<short label>"}]' \
  summary="<one-line context, e.g. 'LinkedIn login — open the viewer and sign in'>"
```

- `session_id` is the browser name you passed to `browser_create` (the `<app-slug>`). It IS the session identifier — reuse it verbatim. If `browser_create` returned a distinct opaque id in its response footer, prefer that.
- `title` is a short human label: `"LinkedIn login"`, `"Reddit feed scrape"`, `"captcha — needs you"`.
- Copy `project_id` + `application_id` verbatim from the `## Current Context` block of your User Message — same rule as every other MCP tool.
- Mentioning the session in chat prose without the artifact is forbidden — the workbench tab won't open from prose, and "open the viewer" instructions become dead text.

Re-fire on every new attention-request even if you've already delivered the chip earlier in the conversation — each call repins the tab and signals "look here now".

## Browser name = app slug. Always reuse.

`name=<app-slug>` is mandatory on every `browser_create`. The app slug is in your workspace path (e.g. `/home/node/workspace/reddit-gather-a-9920b7f` → slug `reddit-gather-a-9920b7f`), in `$APPLICATION_SLUG`, and in the dispatch prompt. Never use generic names (`default`, `scraper`, `researcher`) — they collide across apps.

**Start every web task by listing.** Always:

```bash
npx mcporter call aramb_browser.browser_list
```

- Slug matches an existing browser → **reuse it**. `new_page browser=<app-slug>`, capture `target` from the footer, navigate.
- No match → run the provider flow below.

**Never call `browser_destroy`** — with one exception: the aramb→steel provider fallback (below), where you destroy the aramb session precisely to recreate the same slug on steel. Outside that, the browser persists across tasks and sibling sub-agents on the same app; destroying it forces every other task to recreate. TTL handles cleanup. When your work is done, leave it.

## `target=` on every page-level call

Page-level tool responses end with a footer:

```
--- browser: <app-slug> | target: <targetId> | url: <url>
```

Pass **both** `browser=<app-slug>` AND `target=<targetId>` on every page-level call (`navigate_page`, `take_snapshot`, `take_screenshot`, `click`, `fill`, `select_page`, `close_page`, `list_pages`, `wait_for`, `evaluate_script`, `list_console_messages`, `list_network_requests`). Read the footer and carry `target` forward.

Without `target=`, the call lands on whichever tab is "selected" — which is whatever tab a sibling sub-agent navigated last. Always pin the tab.

Lifecycle tools (`browser_create`, `browser_list`, `browser_switch`, `browser_stats`, `browser_clients_list`, `browser_session_*`, `browser_context_*`, `browser_save_context`, `browser_load_context`, `new_page`) do NOT take `target=`.

## Provider flow — aramb primary, steel fallback

Only if `browser_list` had no match for your slug. **Always create on `provider=aramb` first:**

```bash
npx mcporter call aramb_browser.browser_create name=<app-slug> provider=aramb browser_type=chrome ttl_minutes=30
```

`aramb` is the primary provider (the server default). It runs with the residential proxy (`use_proxy`) and captcha auto-solving (`auto_solve_captcha`) defaulted on, so aramb clears most captchas itself with its built-in solvers. `browser_type=chrome` is required.

Chain create + first navigate in one Bash call (shell `cwd` resets between mcporter calls; `&&` avoids drift):

```bash
npx mcporter call aramb_browser.browser_create name=<app-slug> provider=aramb browser_type=chrome ttl_minutes=30 \
  && npx mcporter call aramb_browser.navigate_page browser=<app-slug> url=https://example.com
```

### Steel is the fallback — only on aramb's incapability or unavailability

Switch to `provider=steel` in exactly two cases, and only after aramb has actually failed:

1. **aramb is unavailable** — `browser_create` fails, the session never reaches ready, or the provider returns 503.
2. **aramb can't clear a captcha** — you hit a challenge and, after waiting ~60s (see the captcha steps below), aramb still hasn't solved it despite its solvers.

To switch, **terminate the aramb session and recreate the same slug on steel**, reapplying any context you loaded so logged-in state carries over:

```bash
npx mcporter call aramb_browser.browser_destroy browser=<app-slug> \
  && npx mcporter call aramb_browser.browser_create name=<app-slug> provider=steel browser_type=chrome ttl_minutes=30 [session_context=<value>] \
  && npx mcporter call aramb_browser.navigate_page browser=<app-slug> url=<same-url>
```

`browser_destroy browser=<app-slug>` unregisters the slug and auto-terminates its Aramb session. This is the **one sanctioned exception** to the never-destroy rule — provider fallback only, never to "reset" a working browser. Steel ships with its own residential proxy and managed captcha solving.

Both providers fail → stop and report. Don't autonomously retry a third time or loop back to a provider that already failed.

### Optional `browser_create` inputs

- `session_context=<string>` — replay a previously captured browser-context string (cookies + per-origin storage) inline at create time, instead of running `browser_load_context` afterwards. Pass the opaque value returned by `browser_save_context` verbatim. **Carry it onto the steel fallback too** — pass the same `session_context` (or re-run `browser_load_context` after create) so the fallback session keeps the logged-in state you loaded on aramb.
- `use_proxy=true|false` — opt into the residential proxy. Defaults to true.
- `auto_solve_captcha=true|false` — opt into automatic captcha solving. Defaults to true.

### Captcha handling — aramb solves, steel is the fallback, then ask

aramb clears most captchas (reCAPTCHA, Cloudflare Turnstile, hCaptcha, etc.) in the background with its own solvers. While a session is actively solving, the Aramb viewer UI shows a "solving captcha" status — don't interact with the page, navigate, or recreate the browser while it's in that state; wait for it to clear, then continue.

Step through it in order — never skip straight to asking the user:

1. **Hit a challenge → wait 30-60s and re-check.** `navigate_page` to refresh, or `evaluate_script` to read `location.href` / `document.title` / page content. Most pages clear on their own in that window.
2. **Still blocked after ~60s → aramb couldn't solve it. Terminate and switch to steel** (the fallback command above), reapplying any loaded context. Give steel the same 30-60s to clear the challenge with its managed captcha solving, then re-check.
3. **Steel still blocked after ~60s → stop and ask the user — but first deliver the session chip.** The chip is what makes "open the browser viewer" a one-click action; without it, the user has nowhere to click. Fire `aramb_mcp.chat_deliver_artifacts` with a `browser_session` artifact (see the deliver-the-session section above), then ask.

Don't retry a provider that already failed, don't loop, and don't recreate the browser beyond the single aramb→steel fallback.

> `<site>` is still blocked after aramb and steel both tried. Looks like a `<captcha challenge | login wall | rate limit | empty body / generic block>`. How would you like to proceed?
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
npx mcporter call aramb_browser.browser_context_list

# Reserve a slot (required before first save)
npx mcporter call aramb_browser.browser_context_create context_name=<name>

# Save current browser state into the slot
npx mcporter call aramb_browser.browser_save_context browser=<app-slug> context_name=<name>

# Apply a saved context onto a live browser
npx mcporter call aramb_browser.browser_load_context browser=<app-slug> context_name=<name>

# Delete (Redis record + S3 tarball)
npx mcporter call aramb_browser.browser_context_destroy context_name=<name>
```

Naming: one context per app-slug per logical identity (e.g. `reddit-gather-a-login`). Reuse the same name; re-save (after user approval) only when state has materially changed.

Error behavior:

- `browser_load_context` on a missing name → reserve + save first.
- `browser_save_context` on a missing name → `browser_context_create` first.
- `browser_context_create` on an existing name (409) → pick a new name or destroy the old one.
- `browser_context_destroy` on a missing name → check `browser_context_list`.

## Rules (no exceptions)

- **Rendered / restricted / authenticated / visual** web access goes through this skill — no `WebSearch` / `WebFetch` / `curl` / `wget` / script HTTP for those. **Public / static** content (GitHub repos & raw files, plain pages, JSON/APIs) goes the other way: `curl` / `git clone --depth 1` / `WebFetch`, never the browser (see the **Fetch hierarchy** at the top).
- `browser_list` BEFORE `browser_create`. Reuse the matching slug.
- `name=<app-slug>` on every `browser_create`. Never invent names.
- `browser=` AND `target=` on every page-level call.
- One browser per app slug. Siblings reuse via `new_page`, not a second `browser_create`.
- **Always create on `provider=aramb` first.** Steel is the fallback, used only when aramb is unavailable (create fails / never ready / 503) or can't clear a captcha after waiting ~60s. Never open on steel by default.
- **Never call `browser_destroy`** — except to switch aramb→steel on the provider fallback (destroy the aramb session, recreate the slug on steel, reapply any loaded `session_context`). Otherwise TTL cleans up.
- **Deliver a `browser_session` artifact via `aramb_mcp.chat_deliver_artifacts` (a) immediately after `browser_create` succeeds, and (b) every time you stop to ask the user for input or attention.** Both are mandatory. Prose mentions don't open the workbench tab.
- **Never save or load a context without explicit user approval.** Before `browser_create`, run `browser_context_list` and prompt the user to pick or skip. After a successful login, prompt before `browser_save_context`.
- `evaluate_script` uses `function=` (NOT `script=`). Body is a JS arrow function: `function="() => JSON.stringify(...)"`.
- On CAPTCHA / bot wall / 403: **wait 30-60s** for aramb to clear it in the background, then re-check. Still blocked → **terminate aramb and switch to `provider=steel`** (reapply any loaded context) and give steel the same 30-60s. Only if steel is also still blocked, deliver the session chip and stop to ask the user — describe what you saw, never auto-recommend a specific fix.
- Snapshots are heavy. Use only before click or when stuck. Prefer `evaluate_script` for data extraction.

## Scenarios

### Start a session
```bash
npx mcporter call aramb_browser.browser_list
# slug present → new_page browser=<app-slug>, capture target, navigate
# slug absent  → browser_context_list, prompt user to load a saved context or skip,
#                then browser_create name=<app-slug> provider=aramb browser_type=chrome ttl_minutes=30 [session_context=<value>]
#                && navigate_page browser=<app-slug> url=...
#                aramb unavailable OR can't clear a captcha after ~60s → browser_destroy browser=<app-slug>
#                && browser_create name=<app-slug> provider=steel browser_type=chrome ttl_minutes=30 [session_context=<value>]  (steel = fallback)

# Immediately after a successful create OR a list-reuse, deliver the session chip:
npx mcporter call aramb_mcp.chat_deliver_artifacts \
  project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" \
  artifacts='[{"kind":"browser_session","session_id":"<app-slug>","title":"<short label>"}]' \
  summary="Browser is up — opened the workbench tab so you can watch."
```

### Scrape Reddit / social — browser, never `.json` curl
```bash
npx mcporter call aramb_browser.navigate_page browser=<app-slug> target=<tid> \
  url="https://old.reddit.com/r/<sub>/top/?t=month"
npx mcporter call aramb_browser.evaluate_script browser=<app-slug> target=<tid> \
  function="() => Array.from(document.querySelectorAll('.thing.link')).map(el => ({title: el.querySelector('a.title')?.textContent?.trim(), url: el.querySelector('a.comments')?.href, score: el.querySelector('.score.unvoted')?.title}))"
```

### Search engine query — browser, not WebSearch
```bash
npx mcporter call aramb_browser.navigate_page browser=<app-slug> target=<tid> \
  url="https://duckduckgo.com/?q=<query>"
npx mcporter call aramb_browser.evaluate_script browser=<app-slug> target=<tid> \
  function="() => Array.from(document.querySelectorAll('article')).map(a => ({title: a.querySelector('h2')?.innerText, url: a.querySelector('a')?.href}))"
```

### Parallel sub-agents — one browser, isolated tabs
```bash
# Agent A
npx mcporter call aramb_browser.new_page browser=<app-slug>      # footer → target-A
npx mcporter call aramb_browser.navigate_page browser=<app-slug> target=<target-A> url=https://a.com
# Agent B (no collision with A)
npx mcporter call aramb_browser.new_page browser=<app-slug>      # footer → target-B
npx mcporter call aramb_browser.navigate_page browser=<app-slug> target=<target-B> url=https://b.com
```

## Task

$ARGUMENTS
