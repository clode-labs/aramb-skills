---
name: chil-mcp
description: >
  Chat tools (Slack today) via chil's MCP server. Post, reply, DM,
  read channels/threads, list a user's channels. Scope is the caller's
  org — no team_id or application_id.
---

# Chil Chat Toolkit

Server name is `chil`. Tool names are flat. Every call is scoped server-side by the JWT's `organization_id` — pass only what the action needs.

## Tools

| Tool | Args | Returns |
|---|---|---|
| `send_message` | `channel_id`, `text` | `{ok, id, channel_id}` |
| `reply_in_thread` | `channel_id`, `thread_id`, `text` | `{ok, id, channel_id, thread_id}` |
| `send_dm` | `account_id`, `text`, `thread_id?` | `{ok, id, channel_id, account_id, thread_id?}` |
| `read_messages` | `channel_id`, `days?`, `limit?`, `cursor?` | `{messages, next_cursor, has_more}` |
| `read_thread` | `channel_id`, `thread_id`, `limit?`, `cursor?` | `{messages, next_cursor, has_more}` |
| `get_channel_info` | `channel_id` | `{id, name, is_private, topic, purpose}` |
| `list_channels` | `account_id` | `{channels: [{id, name, is_private}]}` |
| `list_joined_channels` | — | `{channels: [{id, name}]}` |

- `channel_id`: target channel id (DM channels work too — use the `channel_id` returned by `send_dm`).
- `account_id`: a user id.
- `thread_id`: the `id` of the thread root (also the `id` returned by a prior `send_message`/`send_dm`).
- `id` in responses is the message identifier — reuse it as the next `thread_id`.

## Invocation

All tools: `npx mcporter call chil.<tool> key="value" key="value"`. Server is `chil`, tool name is appended after a dot (same pattern as `aramb_chat.send_message`, `aramb_tasks.update`).

## CRITICAL: mcporter syntax rules

- All arguments MUST be `key="value"` format with quotes.
- Do NOT use `--output` — it is not supported by `mcporter call`.
- Do NOT use positional args — every parameter is named.

## Examples

```bash
# Post in a channel
npx mcporter call chil.send_message channel_id="C0B8P73U77Y" text="Heads up — deploy starting in 5 min"

# Reply inside an existing thread (thread_id = root message id from a prior send_message / read)
npx mcporter call chil.reply_in_thread channel_id="C0B8P73U77Y" thread_id="1781360386.219519" text="Done."

# DM a user (opens or reuses the DM channel; returns channel_id + id)
npx mcporter call chil.send_dm account_id="U0BABQ1V882" text="Quick sync?"

# Reply in the same DM thread (reuse the id returned by send_dm as thread_id)
npx mcporter call chil.send_dm account_id="U0BABQ1V882" text="follow-up" thread_id="1781360471.979729"

# Read recent messages (last 7 days, default page size)
npx mcporter call chil.read_messages channel_id="C0B8P73U77Y" days="7"

# Paginate
npx mcporter call chil.read_messages channel_id="C0B8P73U77Y" cursor="<next_cursor from prior call>"

# Read a thread (root is repeated as messages[0] on every page)
npx mcporter call chil.read_thread channel_id="C0B8P73U77Y" thread_id="1781360386.219519"

# Channel metadata
npx mcporter call chil.get_channel_info channel_id="C0B8P73U77Y"

# What channels is a user in?
npx mcporter call chil.list_channels account_id="U0BABQ1V882"

# What public channels is the bot itself in?
npx mcporter call chil.list_joined_channels
```

## Read tool details

- One MCP call = one platform call. Paginate with `cursor` until `has_more` is false.
- `days` (read_messages only): window in days, set once on page 1; the window carries through cursor pages.
- `limit`: read_messages default 20, read_thread default 50, hard cap 200 both.
- `read_thread` repeats the root as `messages[0]` on every page — dedupe by `id`.

## DM threading

`send_dm` opens (or reuses) a DM channel and returns `channel_id` + `id`. To reply in the same DM thread, pass that `id` back as `thread_id` on the next `send_dm`, or use `reply_in_thread` with the returned `channel_id`.

## Errors

Errors come back as `{isError: true, content: [{type: "text", text: "..."}]}`. The text is user-presentable — relay it verbatim and stop retrying. Common messages:

- *"No chat workspace is connected for your organization."* → no install for this org; nothing the agent can fix.
- *"That user isn't part of your organization's workspace."* → wrong `account_id`.
- *"The bot is not a member of this channel."* → invite the bot, then retry.
- *"… rate-limiting this workspace."* → back off briefly.
- *"Thread not found in this channel."* → parent deleted; the `thread_id` is stale.

Read tools may also deny with a capability-scope message (cross-org / private channel / no capability) — same handling.
