---
name: aramb-phone
description: >
  MCP toolkit for placing real outbound phone calls (aramb_mcp.phone_*). Use
  these to call a phone number, speak with the person who answers, check whether
  the call is still live, and hang up. Use when the user asks you to phone
  someone, confirm something by voice, leave a spoken message, or run an outbound
  call task. NOT for sending chat messages or notifications — that is aramb_chat.
---

# Aramb Phone Toolkit

The `aramb_mcp.phone_*` tools let you place and manage a **real outbound phone
call**. You dial an E.164 number; when the person answers, the agent joins the
call as a voice participant and talks to them. Every call runs under **your own
application**, so you do not mint tokens or pass any credential — the toolkit is
bound to you automatically.

## When to use this

- The user asks you to **call someone** — confirm a booking, chase a reply,
  deliver a spoken message, run a reminder call, qualify a lead by voice.
- A task needs a **voice** step, not a text step (a chat message or notification
  would not reach the person, or the user explicitly wants a phone call).

**Do NOT** use this for chat/Slack messages, questions, or notifications — those
go through `aramb_mcp.chat_*`. Phone calls place an actual PSTN call and cost
call minutes; only use them when a real call is intended.

## CRITICAL: mcporter syntax rules

- ALL arguments MUST use `key="value"` format (NOT positional args).
- Do NOT use `--output` — it is not supported by `mcporter call`.
- **ALWAYS include `project_id`** (and `application_id` when you have it). The
  agent is deployed per-project and serves multiple applications; the call is
  bound from this context, so without `project_id` the call cannot be placed.

## Invocation

```bash
npx mcporter call aramb_mcp.phone_<tool> project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" <args...>
```

## The call handle (`room`)

`phone_call` returns a `room` string. **Keep it** — `phone_status` and
`phone_hangup` both key off that exact `room`. It is your only handle on the
call once it is placed.

## Tools

### `phone_call` — place the call

Args:
- `to` (required) — destination number in **E.164** format, e.g. `+14155550123`
  (leading `+`, country code, no spaces or dashes). Malformed numbers are
  rejected before dialing.
- `greeting` (optional) — the exact words the agent speaks first when the person
  answers. If omitted, the agent opens the conversation itself.

```bash
npx mcporter call aramb_mcp.phone_call project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" \
  to="+14155550123" greeting="Hi, this is Ada calling from Acme about your order."
```

Returns: `{ "room": "...", "sip_call_id": "...", "participant_id": "...", "message": "..." }`.
The agent greets the person when they pick up. Use `phone_status` with the
returned `room` to watch progress, or `phone_hangup` to end it.

### `phone_status` — is the call still live?

Args: `room` (required) — the handle from `phone_call`.

```bash
npx mcporter call aramb_mcp.phone_status project_id="<PROJECT_ID>" room="<ROOM>"
```

Returns: `{ "active": true|false, "num_participants": <n>, "room": "..." }`.
`active:false` means the call has ended (the person hung up, or it never
connected).

### `phone_hangup` — end the call

Args: `room` (required) — the handle from `phone_call`.

```bash
npx mcporter call aramb_mcp.phone_hangup project_id="<PROJECT_ID>" room="<ROOM>"
```

Returns: `{ "ended": true }`. Hanging up an **already-ended** call succeeds — it
is safe to call defensively when you are unsure whether the call is still up.

## Typical flow

1. `phone_call to="+1..." greeting="..."` → grab the `room`.
2. Poll `phone_status room="<ROOM>"` until `active:false` (person answered and
   the conversation ran its course) — or until you decide to end early.
3. `phone_hangup room="<ROOM>"` to close the call when you are done.

## Cautions

- **This dials a real phone.** Only call numbers the user has given you or asked
  you to reach. Do not guess numbers, and do not place repeated or bulk calls
  unless explicitly asked.
- **E.164 only.** `+` + country code + number, digits only. `(415) 555-0123` or
  `415-555-0123` will be rejected — normalize to `+14155550123` first.
- **"Not configured" corrective.** If the deployment has no voice backend wired
  up, the tools return a clear "phone calling is not configured" message instead
  of dialing. That is expected on stacks without voice enabled — surface it to
  the user rather than retrying.
