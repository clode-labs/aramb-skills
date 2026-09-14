---
name: accounts
description: >
  How a worker signs up for or registers an account on a third-party service —
  which identity to use, how credentials are generated and stored, how
  verification codes are handled, and what to do at a challenge wall. Use
  whenever the brief involves creating an account, signing up, registering, or
  setting a password on an external service. NOT for signing IN with a credential
  the user already saved (that is `aramb-browser`'s vault_fill path), and NOT for
  creating an account nobody asked for — that never happens.
---

# Accounts — agent identity, vaulted credentials, no walls climbed

An account is a durable thing with the user's name attached to it. Get this wrong and
the damage outlives the task. Three rules carry the whole skill.

## 1. Only when the brief says so

**Never create an account to get past something.** Not to see a price, not to skip a
sign-in wall, not because guest checkout was awkward. A sign-up that was not asked for
is a blocker to report, not an obstacle to route around.

## 2. Agent identity — never the user's

Register as the **agent**, using the identity the brief names:

- **Email** — your own agent address (`aramb_mcp.email_*`), which is exactly what makes
  it usable for sign-ups: the confirmation comes back to an inbox you can actually read.
  If `aramb_mcp.email_*` is not in your tool list you have no address, and that is a
  blocker — say so rather than improvising with someone's connected Gmail account.
- **Name, phone, address, card** — the user's real ones go into a third-party form
  **only** when the brief explicitly directs that exact thing for that exact service.
  Otherwise the agent identity, or a blocker.

If a field genuinely requires something you were not given, stop and name it. Do not
invent a plausible value to get past validation — an invented identity is a real record
on somebody's real system.

## 3. Credentials are generated strong and vaulted, never spoken

- **Generate** the password; never reuse one, never pick something memorable.
- **Store it immediately** — `aramb_mcp.vault_store_secret` for a credential that is
  yours to hold, or the browser-creds store when it is the user's login for the site.
- **It never enters a prompt, a log, a file, a report, or a chat message.** Not in
  passing, not "for debugging", not masked-but-guessable. The read-back you attach to
  your report is the alias and the fields, never the value.
- When you next need it, the **browser** types it (`aramb_browser.vault_fill`) — you do
  not read it back into yourself.

If a credential is ever echoed somewhere it should not be: flag it, say honestly what
was exposed, and rotate it if it is live.

## Verification codes

Email confirmations and magic links arrive at **your** agent inbox — read them with
`aramb_mcp.email_list_inbox` / `aramb_mcp.email_read` and follow the link in the browser.

An **SMS / phone code**, an authenticator enrolment, or any code that lands somewhere
you cannot reach is a **blocker**. Report exactly what is needed, where it will arrive,
and what you will do with it. Do not stall silently waiting for something that cannot
come to you.

## A challenge wall is a STOP

A captcha, an anti-bot interstitial, a phone-verification gate, a device check, a
"suspicious activity" screen, a rate-limit — all of it is a **signal to stop and
report**, never to defeat.

- **Document it precisely**: the exact wall, the URL, what it displayed, what you had
  already completed, and the session / `context_name` so the flow can be resumed rather
  than restarted.
- **Never route around it.** No solver service, no evasive tactic, no second attempt
  from a different angle, no fresh anonymous browser to dodge the fingerprint. Routing
  around a security control is a failure even when it works.
- Repeated identical retries against a wall are a banned loop. If you are going to try
  again, it must be a **genuinely different approach**, and a timer is not a different
  approach.

## What you report

- The **service and the account identifier** created (the email / username), never the
  password.
- The **alias** under which the credential was vaulted, and its field names.
- The **verified end state**: you signed in with it, or the confirmation link resolved —
  a created account you never signed into is not evidence of a working account.
- Any **wall** you stopped at, documented.
- Anything the service required that you found surprising — an unexpected phone
  requirement, a paid tier, terms that bind the user. **Report the smell even when you
  followed the brief.**
