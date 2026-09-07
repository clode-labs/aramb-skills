---
name: aramb-phone
description: >
  MCP toolkit for placing a real outbound phone call (aramb_mcp.phone_call). Use
  it to call a phone number from a published agent's claimed number; the agent
  speaks with whoever answers. Use when the user asks you to phone someone,
  confirm something by voice, or leave a spoken message. NOT for chat messages
  or notifications — that is aramb_chat.
---

# Aramb Phone Toolkit

`aramb_mcp.phone_call` places a **real outbound phone call**. It dials an E.164
number from a **published agent's claimed phone number** (that number is the
caller ID); when the person answers, the agent joins the call and talks to them.

## When to use this

- The user asks you to **call someone** — confirm a booking, chase a reply,
  deliver a spoken message, run a reminder call.
- A task needs a **voice** step, not a text step.

**Do NOT** use this for chat/Slack messages, questions, or notifications — those
go through `aramb_mcp.chat_*`. Phone calls place an actual PSTN call and cost
call minutes; only use them when a real call is intended.

## Prerequisites

- The **agent must be published** (`agent_id` below). A draft-only agent is
  rejected before any number is dialled — publish it first.
- The **agent must have claimed a phone number** — that number is the caller ID.
  Without one the call fails with "no active phone number — claim one first".

## CRITICAL: mcporter syntax rules

- ALL arguments MUST use `key="value"` format (NOT positional args).
- Do NOT use `--output` — it is not supported by `mcporter call`.

## Tool

### `phone_call` — place the call

Args:
- `agent_id` (required) — UUID of the **published** agent whose claimed number
  places the call.
- `to` (required) — destination number in **E.164** format, e.g. `+14155550123`
  (leading `+`, country code, digits only — no spaces or dashes). Malformed
  numbers are rejected before dialing.

```bash
npx mcporter call aramb_mcp.phone_call agent_id="<AGENT_UUID>" to="+14155550123"
```

Returns:

```json
{ "call_uuid": "…", "from": "<agent's claimed number>", "to": "+14155550123",
  "message": "Call placed. The agent will speak when the person answers." }
```

`call_uuid` identifies the placed call. The agent answers and speaks when the
person picks up.

## Cautions

- **This dials a real phone.** Only call numbers the user has given you or asked
  you to reach. Do not guess numbers, and do not place repeated or bulk calls
  unless explicitly asked.
- **E.164 only.** `+` + country code + number, digits only. `(415) 555-0123` or
  `415-555-0123` will be rejected — normalize to `+14155550123` first.
- **"Not configured" corrective.** If the deployment has no voice backend wired
  up, `phone_call` returns a clear "phone calling is not configured" message
  instead of dialing. Surface that to the user rather than retrying.
- **No status/hangup yet.** There is currently no tool to poll a placed call's
  status or hang it up from the agent side — `phone_call` places the call and
  returns. (A follow-up will add these once the voice backend exposes call
  control keyed by `call_uuid`.)
