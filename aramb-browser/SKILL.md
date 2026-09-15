---
name: aramb-browser
description: >
  The way to touch JS-rendered, authenticated, or visually-inspected web
  content — every URL visit, scrape, search engine query, form fill,
  filling a credential the user saved in their vault (vault_fill),
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

All tools: `npx mcporter call aramb_browser.<tool> [param=value ...]`. The mcp server
is `aramb_browser` (underscored); the hyphenated `aramb-browser.<tool>` is unregistered
and rejected.

## Whose browser this is — the worker's, not the orchestrator's

**The browser belongs to `task-agent`, the worker that executes briefs.** If you are an
orchestrator holding a conversation with a user, browsing is not yours to do — it blocks
you for minutes while the user waits. Hand it to `task-agent` with a brief (see the
`delegation` skill) and stay available.

If you are the worker, the rest of this skill is yours end to end. **The browser is
YOURS**: you open it, drive it, own getting past what it hits, and report the observed
end state with evidence. Two consequences:

- **Always a named, persistent context — never anonymous.** A context keeps cookies and
  logged-in state alive across runs. Pass the `context_name` you were given on every
  `browser_create` (see *Contexts*); a fresh anonymous browser throws that away and makes
  the user log in again.
- **You do not talk to the user.** Everything a user hears comes from the orchestrator. At
  a wall, report what you saw — don't address them directly.

## Know your channel — is there a viewer, or not?

**Before you rely on ANY "show the user the browser" step, know your channel.** brahmi
tells you at dispatch (a no-viewer clause is injected into your system prompt on external
surfaces); trust that over any instinct.

- **Console web chat (the workbench) — there IS a viewer.** The browser panel, the
  `browser_session` chip, and "open it yourself" all work.
- **External channels (WhatsApp / Slack / voice) — there is NO viewer.** No panel, no
  chip, no live page to "tap". Drive **autonomously**. NEVER tell the user to "tap the
  chip", "open the viewer", "log in in the live browser", or "do it in the browser panel"
  — none of that exists here, and saying so strands them.

Every step below that mentions a chip/viewer/panel is **viewer-only**. On a no-viewer
channel, skip it: at a login/credential wall that means **check browser creds
(`aramb_mcp.vault_list_browser_creds`) → `vault_fill` if present, else
`aramb_mcp.vaultlink_request_browser_creds_link` → wake and resume** (see *Credential &
login walls*), never "open the viewer".

## Fetch hierarchy — reach for the browser LAST

Before opening a browser, ask: **does this content actually need a rendered DOM, JS, a
login, or visual inspection?** If not, fetch it the cheap way. The browser is 30–120s per
call and **hiccups** under load (mid-run batch failures, partial fetches); `curl` /
`git clone` don't. Routing public files through a browser is the single biggest cause of
slow, flaky runs.

**Default to non-browser fetch for public / static content** — `curl`,
`git clone --depth 1`, or `WebFetch`:

- **Public GitHub repos & raw files** — `git clone --depth 1 https://github.com/<o>/<r>`
  or `curl -sL https://raw.githubusercontent.com/<o>/<r>/<branch>/<path>`. ~50× faster,
  never hiccups. Public repos need NO auth / GitHub toolkit / OAuth — never reason "the
  toolkit isn't connected so I'll browser the API".
- **Plain HTML, raw/exported docs, real API/JSON endpoints** whose content is in the
  response body, not assembled client-side. (Traps: many "public" Notion/Google
  Docs/Drive pages are JS-rendered and return an empty shell to `curl`; social `.json`
  URLs — Reddit/X/LinkedIn — return HTML, not JSON. Those are **browser** cases.)

**Toolkit-unconnected fallback is curl, never the browser** — fall back to the
unauthenticated public path, never scrape what `curl` can fetch.

**Use the browser ONLY for** content that genuinely needs it: JS/client-side-rendered
pages, authenticated/gated content, visual inspection (Figma, Rive, canvas, web apps), or
sites that return SPA HTML / 403 to a datacenter UA.

**Escalation — curl first, browser on failure.** If a `curl`/`WebFetch` of a
supposedly-static page comes back as SPA HTML, an empty shell, a login/redirect, or 403,
that page was rendered/restricted — switch to the browser. Content you already know needs
JS/auth/visual inspection skips straight to the browser.

**Forbidden for rendered/restricted content:** `WebSearch` / `WebFetch` / `Fetch` /
`curl` / `wget` / `httpie` / Node `fetch` / Python `requests` / any script HTTP — they hit
the datacenter-UA wall and return SPA HTML or 403. No "this restricted site is simple, let
me just curl it" exception.

## Deliver the session — viewer channels only

**Viewer (console web) only.** On a no-viewer channel, SKIP every chip delivery — the chip
is inert and a stray one confuses the delivery path.

When there IS a viewer, surface every session via `aramb_mcp.chat_deliver_artifacts` with
a `browser_session` artifact (it routes the workbench panel to the live session). Fire it
**(a) right after `browser_create` succeeds** (or a `browser_list` reuse you're about to
drive — pins the tab open) and **(b) every time you pause to ask the user for input or
attention** (captcha, login wall, stop-and-ask). Re-fire on each new attention-request.

```bash
npx mcporter call aramb_mcp.chat_deliver_artifacts \
  project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" \
  artifacts='[{"kind":"browser_session","session_id":"<Session ID from browser_create footer>","title":"<short label>"}]' \
  summary="<one-line context>"
```

- `session_id` = the **`Session ID` from the `browser_create` footer** (or `browser_list`
  for a reuse) — the opaque per-session uuid, verbatim. **Not** the `<app-slug>` (the slug
  is only the `browser=` handle; the workbench can't resolve it → viewer fails to open).
- `title` = short label (`"LinkedIn login"`, `"captcha — needs you"`).
- `project_id` + `application_id` verbatim from your User Message's `## Current Context`.
- Prose mentions don't open the tab — the artifact is mandatory.

## Credential & login walls — check the store, then fill or collect

**A login / credential / payment wall is a *user wall* (class B in `driving-to-completion`),
not a failure to retry.** Shape: **collect once and wait** — check the store, fill if
present; else send the secure link, end your turn, let the wake resume you. Never ask the
user to type a credential value in chat, never poll ("done yet?"), never guess a password.

**Security model — internalise this.** Website logins live in a dedicated
**browser-credential store**. **You never read a credential's value** — only its
**metadata** (aliases, field names). The **browser** fetches and types the value itself via
`vault_fill`; plaintext never passes through you or chat. This store is SEPARATE from your
own agent vault (`vault_store_secret` / `vault_get_secret` / `vault_list_secrets`, the
`vault-mcp` skill — your own API keys). Never `vault_get_secret` a website login, and never
use `fill` / `fill_form` / `type_text` for a saved credential (those need a value you must
not hold — a vault credential goes in **only** via `vault_fill`). You *can* fill a value you
can't see — never tell the user the vault is "write-only" or that they must sign in by hand.

**The sequence:**

1. **Check the store FIRST** — `aramb_mcp.vault_list_browser_creds` returns each entry's
   `alias`, `kind` (`site_creds` / `address` / `card`), and **field names** (never values).
   This is the **only** list for browser logins — not `vault_list_secrets`.
2. **Present → inform, confirm, then let the BROWSER fill.** If more than one could fit,
   confirm which ("Use your saved `LINKEDIN_ACC1` login?"). Inform per the gate below, then
   one `vault_fill` per field, then submit with a normal `click`. **On login success,
   immediately `browser_save_context` into the managed `context_name`** (see *Contexts*).

   ```bash
   # one field per call. key="ALIAS.field"; selector = the input's CSS selector on the page
   # (find it via take_snapshot / evaluate_script). session_id = the live session id (footer
   # / browser_list), NOT the app-slug. target = the URL the field is on.
   npx mcporter call aramb_browser.vault_fill \
     session_id=<session-id> app_id=<APPLICATION_ID> target=https://www.linkedin.com/login \
     key="LINKEDIN_ACC1.username" selector="#username"
   npx mcporter call aramb_browser.vault_fill \
     session_id=<session-id> app_id=<APPLICATION_ID> target=https://www.linkedin.com/login \
     key="LINKEDIN_ACC1.password" selector="#password"
   ```
   Errors: **404** session gone (`browser_list`); **422** precheck failed — page not on
   `target`, or `selector` matched nothing → re-`take_snapshot` and retry; **504** browser
   didn't ack → check `browser_session_info` and retry.
3. **Absent → collect** (never ask for the raw value in chat):
   - **No viewer → your FIRST action is `aramb_mcp.vaultlink_request_browser_creds_link`**
     with `alias` (e.g. `"linkedin"`), exact `fields` (`["username","password"]`), and a
     human `label`. It sends a secure one-time link. **Then end your turn and set
     `aramb_mcp.wake_at`** (see `wake-subscriptions`). On wake: re-open the SAME
     session/`context_name`, re-check `vault_list_browser_creds`, `vault_fill`, continue.
   - **Viewer → ** offer the viewer route ("sign in yourself") OR still use the link (keeps
     creds for next time). Both work.

**Inform before you USE a stored credential** (risk class is structural: `payment` iff
fields include `card_number`/`cvv`/`expiry`/`upi`, else `login`):
- **Login-class** — inform **once** per task (*"Using your saved LinkedIn login."*).
- **Payment-class** — inform **before EVERY transaction, with amount + recipient**
  (*"About to pay ₹3,499 to Flipkart with your card ending 1234 — going ahead."*).

`request_browser_creds_link` fires **only when nothing is stored**; when a credential
exists, skip straight to inform-and-`vault_fill`.

## Browser name = app slug. Always reuse.

`name=<app-slug>` is mandatory on every `browser_create`. The slug is in your workspace
path (`/home/node/workspace/reddit-gather-a-9920b7f` → `reddit-gather-a-9920b7f`), in
`$APPLICATION_SLUG`, and the dispatch prompt. Never use generic names (`default`,
`scraper`) — they collide across apps.

**Start every web task with `browser_list`:**

```bash
npx mcporter call aramb_browser.browser_list app_id=<APPLICATION_ID>
```

- Slug matches → **reuse it**: `new_page browser=<app-slug>`, capture `target` from the
  footer, navigate.
- No match → run the provider flow.

`browser_list` reconciles the local registry against live server sessions, so it flags
**orphaned live sessions** (still running + billing, no local entry, left by a mid-handshake
failure). Close one before creating a new browser:
`browser_destroy app_id=<APPLICATION_ID> session_id=<id>`.

**Never call `browser_destroy`** — three exceptions: (1) the aramb→steel provider fallback
(destroy the aramb session to recreate the same slug on steel); (2) closing an orphaned live
session by id; (3) changing `proxy_country` on an already-open browser (save context →
destroy → recreate with the new country + same context — see *Geo-targeting the proxy
exit*). Otherwise the browser persists across tasks and sibling sub-agents; destroying forces
everyone to recreate. When done, leave it.

## `target=` on every page-level call

Page-level responses end with a footer:

```
--- browser: <app-slug> | target: <targetId> | url: <url>
```

Pass **both** `browser=<app-slug>` AND `target=<targetId>` on every page-level call
(`navigate_page`, `take_snapshot`, `take_screenshot`, `click`, `fill`, `select_page`,
`close_page`, `list_pages`, `wait_for`, `evaluate_script`, `list_console_messages`,
`list_network_requests`). Read the footer and carry `target` forward — without it the call
lands on whichever tab a sibling navigated last.

Lifecycle tools (`browser_create`, `browser_list`, `browser_switch`, `browser_stats`,
`browser_clients_list`, `browser_session_*`, `browser_context_*`, `browser_save_context`,
`browser_load_context`, `new_page`) do NOT take `target=`.

## Interacting with elements — `click`/`fill` take a `uid` from `take_snapshot`

**You cannot click or fill by CSS selector, text, or coordinates.** `click`, `fill`,
`hover`, `drag` act on a **`uid`** — an opaque element id that exists *only* in
`take_snapshot` output. Guessing a uid, or passing `selector=`/`text=`/`x=`/`y=`, is
rejected with **`MCP error -32602 Invalid arguments`**. The loop is always **snapshot →
read the uid → act on that uid → re-snapshot if the page changed**:

```bash
npx mcporter call aramb_browser.take_snapshot browser=<app-slug> target=<tid>   # each element line carries uid=…
npx mcporter call aramb_browser.click browser=<app-slug> target=<tid> uid=<uid>
npx mcporter call aramb_browser.fill  browser=<app-slug> target=<tid> uid=<uid> value="<text>"
# fill also selects a <select> <option> (option's uid + its value). Many fields at once:
npx mcporter call aramb_browser.fill_form browser=<app-slug> target=<tid> \
  elements='[{"uid":"<u1>","value":"<v1>"},{"uid":"<u2>","value":"<v2>"}]'
```

**uids go stale on any DOM change** (navigation, a re-render, an SPA route change, content
loading) — acting on a stale uid throws `-32602` / "no element for uid". Re-`take_snapshot`
after anything that changes the page. (This is also why raw `evaluate_script` DOM clicks
throw `Cannot read properties of null (reading 'click')` — snapshot-then-act instead.)

**`select_page` / `new_page` use different args** (not `uid`/`target`):
- `select_page pageId=<number> browser=<app-slug>` — `pageId` is the **numeric** index
  from `list_pages` (0,1,2…), not a slug/url/target (a string is `-32602`). You rarely need
  it — pin the tab with `target=` instead.
- `new_page url="<url>" browser=<app-slug>` — takes a **`url`** (optional `background=true`),
  no `target=`; returns a footer with the new `target` to carry forward.

## mcporter exits non-zero even on success — judge by the body, not the exit code

`npx mcporter call …` frequently returns a **non-zero shell exit (`Exit code 1`) on a fully
successful call** — the body says `Successfully clicked on the element` and carries the
normal `--- browser: … | target: …` footer. **Decide success/failure from the response
body, never the exit code.** If the body reports success, it worked — do not retry or
deviate. A real failure is an explicit error string in the body (`MCP error -32602`,
`Target closed`, `upstream connection failed`, a stack trace), not a bare non-zero exit.

## Provider flow — aramb primary, steel fallback

Only if `browser_list` had no match. **Always create on `provider=aramb` first** (the
server default; residential proxy + captcha auto-solving default on; `browser_type=chrome`
required). Chain create + first navigate in one Bash call (`cwd` resets between mcporter
calls; `&&` avoids drift):

```bash
npx mcporter call aramb_browser.browser_create name=<app-slug> app_id=<APPLICATION_ID> provider=aramb browser_type=chrome ttl_minutes=30 \
  && npx mcporter call aramb_browser.navigate_page browser=<app-slug> url=https://example.com
```

### `app_id` is REQUIRED — pass it on every Aramb/ikki call

**Always pass `app_id=<APPLICATION_ID>`** — the `application_id` copied verbatim from the
`## Current Context` block of your User Message (the same value you use for
`aramb_mcp.chat_deliver_artifacts`). Do **not** rely on it being picked up from the
environment: the platform's `ARAMB_APP_ID` default is **unreliable** — it is *not injected
at all* for some agents (e.g. a project with no cloud claim), and when you hold more than
one application it carries only **one arbitrary** app, so a session silently gets tracked
under the wrong one. A missing/empty app_id makes the call fail with **`app_id is required`**.
(The tool description says "auto from the environment — do not pass app_id"; that guidance
is wrong for this runtime. Pass it.)

Pass `app_id` on **every command that reaches Aramb/ikki** — provisioning, session,
context, and vault calls:

- `browser_create`, `browser_list`, `browser_destroy`
- `browser_session_list`, `browser_session_info`, `browser_session_extend`, `browser_clients_list`
- `browser_context_list`, `browser_context_create`, `browser_context_destroy`, `browser_save_context`, `browser_load_context`
- `vault_fill`

**Page-level calls do NOT take `app_id`** (`navigate_page`, `take_snapshot`, `click`,
`fill`, `select_page`, `new_page`, `close_page`, `list_pages`, `wait_for`,
`evaluate_script`, `list_console_messages`, `list_network_requests`), nor do the
local-registry `browser_switch` / `browser_stats`.

**Optional `browser_create` inputs:**
- `context_name=<slug>` — the **managed per-user context** (see *Contexts*); pass it
  whenever the platform gave you one.
- `session_context=<string>` — replay a previously captured context blob inline at create
  (opaque value from `browser_save_context`, verbatim). Steel-only; distinct from
  `context_name`. **Carry it onto the steel fallback** so login state survives.
- `use_proxy=true|false` (default true), `auto_solve_captcha=true|false` (default true).
- `proxy_country=<ISO-3166 alpha-2>` — geo-target the residential proxy exit (see below).

### Geo-targeting the proxy exit — `proxy_country`

Some tasks only make sense from a specific country's IP; most are global. **Read the geo
intent off the request and set `proxy_country` on the first `browser_create`:**

- **Location-specific → the country's alpha-2 code**, inferred from the query ("pizza in
  **NY**" → `US`, "broadband **UK**" → `GB`, "**Amazon.de**" / "news in **Germany**" →
  `DE`, "restaurants in **Paris**" → `FR`; use the *country*, NY→`US` not a city).
  Localized results, regional pricing, and geo-blocked content all want the matching
  country so the site serves the right locale and doesn't treat you as out-of-region.
- **Global / universal → omit it** (flight fares, generic docs, worldwide SaaS, crypto
  prices, a specific global site the user named). Don't invent a country.

```bash
npx mcporter call aramb_browser.browser_create name=<app-slug> app_id=<APPLICATION_ID> provider=aramb browser_type=chrome ttl_minutes=30 proxy_country=US
```

**The allowed set is enforced.** If create is rejected with `proxy_country "XX" not
allowed; allowed: GB, US, DE, …`, pick the closest allowed country or omit it. (Applies
only to the residential proxy — rejected with `use_user_network`, which egresses via the
user's own IP.)

**`proxy_country` is fixed at create.** To change it on an open browser, recreate carrying
the context: `browser_save_context` → `browser_destroy browser=<app-slug>` (a sanctioned
destroy, same standing as the steel fallback) → `browser_create … proxy_country=<new>
context_name=<same-slug>` (the managed context auto-reloads, so you resume logged in on the
new exit). Setting it up front avoids this dance.

**Steel is the fallback**, only after aramb has actually failed, in two cases: (1) **aramb
unavailable** — create fails / never ready / 503; (2) **aramb can't clear a captcha** after
~60s. Switch by terminating aramb and recreating the same slug on steel, reapplying context:

```bash
npx mcporter call aramb_browser.browser_destroy browser=<app-slug> app_id=<APPLICATION_ID> \
  && npx mcporter call aramb_browser.browser_create name=<app-slug> app_id=<APPLICATION_ID> provider=steel browser_type=chrome ttl_minutes=30 [session_context=<value>] \
  && npx mcporter call aramb_browser.navigate_page browser=<app-slug> url=<same-url>
```

`browser_destroy browser=<app-slug>` unregisters the slug and auto-terminates its aramb
session — the one sanctioned destroy (fallback only, never to "reset" a working browser).
Steel ships its own residential proxy + managed captcha solving.

**Before switching, clean up a half-created session.** A create can provision a live session
then fail the CDP handshake (`Protocol error (Target.getBrowserContexts): Target closed` /
`upstream connection failed`) — the session is still live and billing. This counts as "aramb
unavailable", but do NOT just recreate on steel or you leak it: `browser_list`, then
`browser_destroy browser=<app-slug> app_id=<APPLICATION_ID>` (local entry) and/or
`browser_destroy app_id=<APPLICATION_ID> session_id=<id>` (orphan), THEN recreate on steel.
**Every abandoned session gets a `browser_destroy`.**

Both providers fail → stop and report. Don't retry a third time or loop back to a failed
provider.

### Captcha handling — aramb solves, steel is the fallback, then ask

aramb clears most captchas (reCAPTCHA, Turnstile, hCaptcha) in the background. While it's
solving, the viewer shows "solving captcha" — don't interact, navigate, or recreate; wait,
then continue. Step in order — never skip straight to asking:

1. **Hit a challenge → wait 30-60s and re-check** (`navigate_page` reload, or
   `evaluate_script` reads `location.href` / `document.title`). Most clear on their own.
2. **Still blocked after ~60s → switch to steel** (fallback command above, reapply context);
   give steel the same 30-60s.
3. **Steel still blocked → branch on channel:**
   - Is it actually a **login/credential wall**? → the vault path, not a captcha stop (see
     *Credential & login walls*).
   - **Viewer →** deliver the session chip, then ask the user (offer the viewer route).
   - **No viewer →** report the hard block plainly — site, what you saw, what you need.
     Never reference a chip/viewer/panel.

Don't retry a failed provider, don't loop, don't recreate beyond the single aramb→steel
fallback. Viewer "ask the user" menu:

> `<site>` is still blocked after aramb and steel. Looks like a `<captcha | login wall |
> rate limit | generic block>`. How would you like to proceed?
> - **Open the browser viewer and clear it yourself** — fastest; tell me when you're past.
> - Wait and retry later · Try a different URL · Skip this site

When they take the viewer route, **don't refresh/navigate/recreate** while they work (same
session = same cookies + progress). After they confirm, re-run your last `evaluate_script`.

## Contexts — persistent cookies + logged-in state

A **context** is a tarball of cookies + per-origin storage keyed to one end user; replaying
it restores their logged-in sessions.

**Managed per-user context (the default).** When your instructions give a `context_name`,
pass it on `browser_create`:

```bash
npx mcporter call aramb_browser.browser_create name=<app-slug> app_id=<APPLICATION_ID> provider=aramb browser_type=chrome ttl_minutes=30 context_name=<slug>
```

The platform then **loads it once the browser is ready** and **saves it before teardown**
(plus a periodic snapshot) — automatically, per user. For it you do NOT prompt the user, do
NOT call `browser_load_context` (loading is automatic), and do NOT pass it as
`session_context=`. First run has nothing to load — expected.

**But save at milestones yourself** — the auto-saves are a safety net, not a guarantee: if
the container crashes or is OOM-killed before teardown, everything since the last save is
lost. The moment you reach a milestone (login succeeded, consent accepted, 2FA passed —
anywhere losing state means redoing real work), save into the **same** managed context:

```bash
npx mcporter call aramb_browser.browser_save_context browser=<app-slug> app_id=<APPLICATION_ID> context_name=<the-managed-slug>
```

**Manual named contexts** — only when a **user explicitly asks** to save/reuse a named login
themselves. Never save/load a manual context unprompted.

```bash
# every browser_context_* / save / load call takes app_id=<APPLICATION_ID> too (omitted for brevity)
npx mcporter call aramb_browser.browser_context_list app_id=<APPLICATION_ID>
npx mcporter call aramb_browser.browser_context_create app_id=<APPLICATION_ID> context_name=<name>   # reserve before first save
npx mcporter call aramb_browser.browser_save_context browser=<app-slug> app_id=<APPLICATION_ID> context_name=<name>
npx mcporter call aramb_browser.browser_load_context browser=<app-slug> app_id=<APPLICATION_ID> context_name=<name>
npx mcporter call aramb_browser.browser_context_destroy app_id=<APPLICATION_ID> context_name=<name>   # Redis record + S3 tarball
```

One context per app-slug per identity (`reddit-gather-a-login`); reuse the name, re-save
(after approval) only when state materially changed. Errors: load/save on a missing name →
`browser_context_create` first; create on an existing name (409) → new name or destroy old;
destroy on a missing name → check `browser_context_list`.

## Rules (no exceptions)

- **Rendered/restricted/authenticated/visual** → this skill, no `WebSearch`/`WebFetch`/
  `curl`/`wget`/script HTTP. **Public/static** (GitHub repos & raw files, plain pages,
  JSON/APIs) → `curl`/`git clone --depth 1`/`WebFetch`, never the browser.
- `browser_list` BEFORE `browser_create`; reuse the matching slug. `name=<app-slug>` on
  every create — never invent names. One browser per slug; siblings reuse via `new_page`.
- **`app_id=<APPLICATION_ID>` on every Aramb/ikki call** (`browser_create`/`_list`/`_destroy`,
  `browser_session_*`, `browser_clients_list`, `browser_context_*`/save/load, `vault_fill`) —
  the `application_id` from your `## Current Context`. Don't trust the env default (missing
  for some agents, wrong app when you hold several); a missing one fails `app_id is required`.
  Page-level calls and `browser_switch`/`browser_stats` don't take it. See *`app_id` is REQUIRED*.
- **Resuming after an interruption (a "ran too long" cutoff, a wake, a retry) is not a fresh
  start.** If you come back to only system notices, `browser_list` your slug and
  re-`take_snapshot` the live session first — a half-built cart / mid-flow page means the
  task is still in progress. Don't reply "there's no task" while your browser holds the work.
- `browser=` AND `target=` on every page-level call.
- **`click`/`fill`/`hover`/`drag` take a `uid` from `take_snapshot`** — never a selector,
  text, or coordinates (`-32602`). Snapshot → act → re-snapshot after any DOM change (stale
  uids also `-32602`). `select_page` takes a **numeric `pageId`** from `list_pages`;
  `new_page` takes a **`url`**.
- **mcporter's non-zero exit is not a failure** — judge by the response body, not the exit
  code; `Exit code 1` with a "Successfully …" body = success, don't retry or deviate.
- **Always create on `provider=aramb` first.** Steel is the fallback, only when aramb is
  unavailable (create fails / never ready / 503) or can't clear a captcha after ~60s.
- **Never call `browser_destroy`** except the aramb→steel fallback (recreate the slug on
  steel, reapply `session_context`), an orphaned session by id, or changing `proxy_country`
  on an open browser (save context → destroy → recreate with the new country + same
  context). Otherwise TTL cleans up.
- **Know your channel.** No-viewer (WhatsApp/Slack/voice): NEVER say "tap the chip / open
  the viewer / log in in the live browser / do it in the browser panel". Drive autonomously.
- **Deliver a `browser_session` artifact — VIEWER ONLY** — after `browser_create`, and every
  time you stop to ask the user. On a no-viewer channel SKIP it (inert). Prose won't open it.
- **At a login/auth/payment wall: check the store FIRST** (`vault_list_browser_creds`,
  metadata only). Present → inform (login: once; payment: per-transaction with amount +
  recipient), then `vault_fill`. Absent → no-viewer: FIRST action is
  `vaultlink_request_browser_creds_link(alias, fields, label)`, then end turn + `wake_at`.
  Never `vault_get_secret` a website login; never "have the user log in" on a no-viewer
  channel; never `fill`/`fill_form`/`type_text` a saved credential.
- **Managed `context_name`: always pass it on `browser_create`** (auto-load + auto-save, per
  user); don't prompt or `browser_load_context` for it. **DO `browser_save_context` with the
  same name at each milestone** (login, consent, 2FA) so state survives a crash/OOM.
- **A bare "Target closed" mid-task usually self-heals — don't panic-recreate.** The tool
  probes the session and reconnects transparently. Only `browser_create` a fresh one when an
  error says the session is **confirmed terminated/gone** (a real status check).
- `evaluate_script` uses `function=` (NOT `script=`), a JS arrow function
  (`function="() => JSON.stringify(...)"`). Use it for **reading data**, not clicking; guard
  every DOM lookup with `?.`. To interact, snapshot-then-`click`/`fill` on a uid.
- Snapshots are heavier than `evaluate_script` but are the **only** source of `uid`s — so
  snapshot before every interaction (and after the page changes); `evaluate_script` for bulk
  data extraction.

## Scenarios

### Login wall, no-viewer channel — check creds, fill or link
```bash
npx mcporter call aramb_mcp.vault_list_browser_creds                       # metadata only
# PRESENT → inform, then one vault_fill per field (browser types the value; continue login)
npx mcporter call aramb_browser.vault_fill session_id=<id> app_id=<APPLICATION_ID> target="https://www.linkedin.com/login" \
  key="linkedin.username" selector="#username"
# ABSENT → send the secure link FIRST (not "open the viewer"), then end turn + wake
npx mcporter call aramb_mcp.vaultlink_request_browser_creds_link alias=linkedin fields='["username","password"]' label="LinkedIn login"
npx mcporter call aramb_mcp.wake_at in="3m" message="creds link sent — re-check vault_list_browser_creds, re-open session <id>/<context_name>, vault_fill, continue"
```

### Scrape / search — browser, never `.json` curl or WebSearch
```bash
npx mcporter call aramb_browser.navigate_page browser=<app-slug> target=<tid> url="https://old.reddit.com/r/<sub>/top/?t=month"
npx mcporter call aramb_browser.evaluate_script browser=<app-slug> target=<tid> \
  function="() => Array.from(document.querySelectorAll('.thing.link')).map(el => ({title: el.querySelector('a.title')?.textContent?.trim(), url: el.querySelector('a.comments')?.href}))"
```

### Parallel sub-agents — one browser, isolated tabs
```bash
npx mcporter call aramb_browser.new_page browser=<app-slug>                 # footer → target-A
npx mcporter call aramb_browser.navigate_page browser=<app-slug> target=<target-A> url=https://a.com
npx mcporter call aramb_browser.new_page browser=<app-slug>                 # footer → target-B (no collision)
npx mcporter call aramb_browser.navigate_page browser=<app-slug> target=<target-B> url=https://b.com
```

## Task

$ARGUMENTS
