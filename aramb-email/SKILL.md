---
name: aramb-email
description: >
  Your own email address (inbox + outbox) via the aramb_mcp server (email_*
  tools). SEND mail as yourself, READ the mail delivered to you, and REPLY to it,
  threaded. Your from-address is your own agent address and is stamped
  server-side — you cannot send as anyone else. Use for sign-ups / confirmations
  / magic-links that need a real inbox, for corresponding with a person by email,
  and for handling mail forwarded to you. All via `aramb_mcp.email_*`.
---

# Aramb Email — your agent inbox & outbox

`aramb_mcp.email_*` gives you a real email address of your own. You can **send**
mail, **list** and **read** the mail that arrives for you, and **reply** to it.
Every agent has its own stable address (`<slug>@agent.clode.space` /
`<slug>@agents.aramb.work`) — the same address across all of your projects.

**Your from-address is you, and only you.** The `from` on everything you send is
your own agent address, stamped **server-side** — there is no `from` argument and
you cannot spoof another sender. This is what makes the address trustworthy for
registrations and confirmations: the reply/confirmation comes back to *your*
inbox, where you can read it.

**Availability — not every persona gets email.** If `aramb_mcp.email_*` is not in
your tool list, this agent has no email address provisioned. Say so plainly rather
than improvising another way to send mail (do **not** reach for
`aramb_mcp.toolkits_*` Gmail as a substitute for your own address — that is a
*user's* connected account, not you).

## How to call

Reach these tools with `mcporter`:

```bash
# structured args → use --json (reliable for the nested `body` object)
npx mcporter call aramb_mcp.email_send --json '{"to":"person@example.com","subject":"Hello","body":{"text":"Hi there.","html":"<p>Hi there.</p>"}}'

# a single simple arg → key="value" is fine too
npx mcporter call aramb_mcp.email_read id="<message-id>"
```

Rules:
- **Prefer `--json '{...}'`** whenever a call carries the `body` object or a list
  of recipients — it is unambiguous.
- **`body` is an object `{html?, text?}`** — provide `text`, `html`, or both.
  Sending both is best (text for plain clients, html for rich ones).
- **You do not set `from`** — it is always your own agent address.
- **`to` / `cc`** accept a single address string or a list of addresses.

## Tools

- `email_get_address` — get your own email address and current allowlist mode.
  No args. Call this first if you need to tell a person where to write to you, or
  to put your address into a sign-up form.
  ```bash
  npx mcporter call aramb_mcp.email_get_address
  ```
- `email_send` — send a new email as yourself. Args: `to` (address or list,
  required), `subject`, `body` `{html?, text?}`; optional `cc`, `reply_to`.
  ```bash
  npx mcporter call aramb_mcp.email_send --json '{"to":["a@x.com","b@y.com"],"cc":"c@z.com","subject":"Update","body":{"text":"..."},"reply_to":"me@agent.clode.space"}'
  ```
- `email_list_inbox` — list the emails delivered to your address (most recent
  first), each with its `id`, sender, subject, and timestamp. No args.
  ```bash
  npx mcporter call aramb_mcp.email_list_inbox
  ```
- `email_read` — read one inbound email in full (body + headers, and any
  attachment metadata) by its `id` from `list_inbox`. Args: `id` (required).
  ```bash
  npx mcporter call aramb_mcp.email_read id="<message-id>"
  ```
- `email_reply` — reply to an inbound email, **threaded** (In-Reply-To /
  References are set for you). The reply goes to the original sender, from your
  own address. Args: `message_id` (required), `body` `{html?, text?}`.
  ```bash
  npx mcporter call aramb_mcp.email_reply --json '{"message_id":"<message-id>","body":{"text":"Thanks — confirmed."}}'
  ```

## The core loop: check → read → act → reply

You are often woken **because** an email arrived (inbound mail is a trigger). The
reliable pattern:

1. **`email_list_inbox`** — see what has arrived; pick the `id` of the message to
   handle.
2. **`email_read id=<id>`** — read the full message. For a confirmation or
   magic-link mail, the link/code is in the body here — extract it and use it.
3. **act** — click through / submit the code / do whatever the mail asked for
   (e.g. `aramb_mcp.toolkits_*` or a browser step), or compose your response.
4. **`email_reply message_id=<id>`** — reply to the sender when a reply is what's
   called for, so the thread stays intact. Use `email_send` only to start a
   *new* conversation.

## Using your address for sign-ups & confirmations

When a flow asks for an email address (registering for a service, requesting a
magic link):

1. `email_get_address` → get your address.
2. Enter it in the form / API call.
3. Wait for the wake (or poll `email_list_inbox`), then `email_read` the
   confirmation and follow the link or enter the code.

This is the intended use — you own the inbox the confirmation lands in, so you can
complete the loop end to end without a human relaying the code.

## Notes

- **Allowlist.** Your inbox may be allowlist-gated by your owner (only approved
  senders are delivered). `email_get_address` reports the mode; if expected mail
  never appears, the sender may not be allowed — tell the user rather than
  assuming the mail was lost.
- **Attachments** arrive as metadata (`filename`, `mime`, `size`) on a read
  message; the raw bytes are not inlined into the tool result.
- **Don't loop.** Auto-generated mail (bounces, "do-not-reply", your own sends
  echoed back) should not be replied to — replying to an automated sender can
  bounce back and forth. Reply only to real correspondence.
