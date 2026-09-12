# aramb-skills — woky WhatsApp fixes (implementation)

**Workspace SOT:** `/Users/siva/workspace/claude/tasks/woky-whatsapp-rca/` (README + per-issue RCA docs).
Cross-repo siblings: `brahmi/claude/tasks/woky-whatsapp-fixes.md`, `chil/…`, `benji/…`.

aramb-skills is touched by issues **#2 / #3** (channel-aware browser skill) and carries a **stale
orchestrator reference** to clean up. Key context established during RCA:

- **woky does NOT configure `aramb-browser` in its Skills tab** (it lists only `aramb-orchestrator` +
  `wake-subscriptions`), but it still receives `aramb-browser`'s SKILL.md because it is a
  **platform-baked default for any browser-capable persona** (`brahmi
  kairo_agent_provisioner.go:61,65,70` → `platformDefaultSkills(browser=true)`). So a fix to
  `aramb-browser/SKILL.md` **does** reach woky.
- **The channel fact is NOT in any skill** — it is injected by brahmi at dispatch (see brahmi doc §1,
  `fragment.browser_howto` / a new no-viewer clause keyed on `isExternalChatSurface`). This skill is
  the **consumer** of that fact, not its source.

---

## 1. Make `aramb-browser/SKILL.md` channel-aware (#2, #3)

**Why:** the skill is written for the console workbench only. It declares delivering the
`browser_session` chip **mandatory**, and its login-wall / captcha path hardcodes "open the browser
viewer and log in yourself." On WhatsApp there is no viewer/chip/panel, and the skill never mentions
the vault link — so woky tells WhatsApp users to "tap the chip" (#2) and never offers the credential
link on its own (#3).

**Changes (`aramb-browser/SKILL.md`):**
- Add a short **"Know your channel"** preamble: the session chip / viewer / "open it yourself" flow
  applies **only when the user has a workbench viewer (console web chat)**. On an external channel
  (WhatsApp / Slack / voice) there is **no viewer** — drive the browser autonomously and never
  reference a chip / viewer / panel. (The agent learns which case it is in from brahmi's injected
  channel fact.)
- **"Deliver the session" section:** make the mandatory `chat_deliver_artifacts` `browser_session`
  chip **conditional on a viewer existing** — fire it when there is a viewer; **skip it on no-viewer
  channels** (the chip is inert on WhatsApp and confuses the delivery path).
- **Login-wall / captcha section (`Captcha handling` step 3 + the `Rules` block):** replace the
  single "open the viewer and log in yourself" branch with **two paths**:
  - **Viewer present** → offer the viewer route (as today).
  - **No viewer (WhatsApp/Slack/voice)** → the FIRST action at a login/credential wall is
    `aramb_vaultlink.request_browser_creds_link(alias, fields, label)`; for a hard block (captcha
    with no stored creds) report the blocker plainly — never "open the viewer." This is the primary
    fix for **#3** (proactive link).
- Cross-reference the vault flow so the skill and brahmi's `vaultHowtoBlock` agree on the single
  correct WhatsApp path.

---

## 2. Fix the stale watcher references in `aramb-orchestrator/SKILL.md`

**Why:** PR #146 renamed `watchers` → `wake-subscriptions` and the tools `aramb_mcp.my_triggers_*` →
`aramb_wake.*` (legacy names kept as aliases). woky is now Published v6 on `wake-subscriptions`, but
`aramb-orchestrator/SKILL.md` still tells the agent to call `aramb_mcp.my_triggers_create_watcher`
and to "see the `watchers` skill" (lines ~32, 52).

**Changes (`aramb-orchestrator/SKILL.md`):**
- Update watcher calls to the new tool names (`aramb_wake.at` / `aramb_wake.schedule` / etc.) and the
  skill reference to `wake-subscriptions`. Works today via aliases, but the text should match the
  shipped surface.
- (Optional, ties to **#6**) note that automatic completion-wake now covers delegated builds, so the
  agent need not arm a watcher purely to learn a delegated child finished (per #146).

---

## 2b. Tighten the `wake-subscriptions` skill — structure + browser-launch pattern (#8)

**Why:** the skill leans on prose for the re-arm/stop/notify decision, and it teaches the browser
only as a **failure-recovery** target ("an autonomous browser step that FAILED is yours to recover")
— it never teaches using a wake to drive a **long or blocked browser task**, which is woky's
canonical WhatsApp use-case. Design SOT: workspace `issue-8-wake-streamline.md`.

**Changes (`wake-subscriptions/SKILL.md`):**
- **Structured decision.** Replace "Done? → don't set another. Not done? → set a new one." with the
  typed contract: on each wake, read real state, then end in exactly one of **stop** (done/abandoned)
  · **continue** (re-arm, and say whether anything actually changed) · **notify the user** (only when
  there's something real) · **blocked** (needs the user / an external event). Make explicit that a
  *silent* re-check (nothing changed) must NOT message the user — only a real result or a block does.
- **Browser-launch pattern (new section).** Teach the proactive loop woky needs: after launching a
  browser task that will take time OR needs the user to act out-of-band, **end the turn and set a
  `wake_at`**, then on wake **re-open the same browser session** (by session id / managed context)
  and continue. Call out the concrete cases: waiting for the user to fill a **`browser.creds` vault
  link** (ties #2/#3/#4 — send link → end turn → wake → resume login), an **OTP/email**, a slow
  page/checkout, captcha auto-solve, or polling a site for a state change. Note that the **automatic**
  completion-wake covers only a2a/architect delegation — a browser wait is NOT a delegated job, so it
  **requires a timed `wake_at`**.
- Keep the honesty rule; align its wording with the silent-by-default structure.

## 2c. Credential-loop behavior — check-vault-first + inform-before-use (#9)

**Why:** the guaranteed credential state machine (design SOT `issue-9-autonomous-browser-creds-loop.md`)
has behavioral steps the skill must teach precisely, so the agent does them 100/100 (backed by the
platform mechanisms in brahmi/akela/aramb-browser).

**Changes (`aramb-browser/SKILL.md`, credential section):**
- **Check the vault FIRST.** At any login/payment wall, look up the credential (`vault_get_secret` /
  `vault_list_secrets`) **before** anything. The `request_browser_creds_link` is emitted **only when
  nothing is stored** — never when a credential already exists.
- **Inform-before-use gate** (owner requirement):
  - Before using ANY stored credential, **inform the user** first.
  - **Login-class** (site logins) → inform **once** per task (*"Using your saved LinkedIn login."*).
  - **Payment-class** (card / UPI / cvv) → stricter: **inform before EACH transaction, with amount +
    recipient** (*"About to pay ₹3,499 to Flipkart with your saved card ending 1234 — going ahead."*).
    A single "once" is unsafe for money. The risk class is provided structurally (from the fields /
    akela tag) — the skill keys the gate on it.
- **Resume-and-continue.** On the vault-fill wake, re-open the **same managed browser context** and
  continue the login/payment (the value injection itself is the FILL half — Sivaram — out of scope).
- These behaviors are the floor; the platform backstops (brahmi auto-emit, akela event resume) make
  them reliable even if the model slips.

## 3. Delivery / registry note

Per memory `reference_skill_registry_manual_reimport`: a **new or renamed** skill needs a manual
skills-registry re-import to reach agents; a **content-only edit to an existing** skill file usually
does not — but verify. Both edits here are content-only (existing files), so they should propagate on
the next provisioning without a re-import — confirm on dev. woky picks up skill content at **VM
bring-up**, not mid-conversation (per the Skills-tab note), so test on a fresh woky session.

---

## Test plan (aramb-skills)
- Skill review: no unconditional "chip / viewer / panel" language on the no-viewer path; login-wall
  branch names `request_browser_creds_link` as the first no-viewer action; orchestrator watcher calls
  use the new names.
- Real-stack WhatsApp E2E (mocks OFF, brahmi channel fragment landed): woky at a login wall over
  WhatsApp emits a `browser.creds` link on its own and never says "tap the chip / open the viewer";
  on web it still offers the viewer route.

## Sequencing
Pairs with brahmi §1 (the channel fact injection). The skill change is inert without brahmi telling
the agent which channel it's on; ship them together.
