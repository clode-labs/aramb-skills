---
name: chil-mcp
description: >
  MCP toolkit for chat via chil's MCP server. Use to post messages, reply in
  threads, DM users, read channel/thread history, and list a user's channels.
  Every tool is scoped by your JWT's org_id; the bound workspace is resolved
  server-side, so no team_id / application_id is passed.
---

# Chil Chat Toolkit

These tools talk to the connected chat platform (Slack today) on the agent's behalf via chil. Chil's server uses your JWT's `organization_id` to find the org's installed workspace and authorize every call — you never pass a `team_id`, `application_id`, or workspace selector.

## CRITICAL: mcporter syntax rules
- All arguments use `key="value"` format (NOT positional).
- Do NOT pass `--output` — unsupported.
- The MCP server name is `chil`; tool names are flat (no `chat.` prefix). So calls are `npx mcporter call chil <tool> …`.

## Identifier vocabulary

| Field | What it is |
|---|---|
| `channel_id` | The channel to act in (e.g. a Slack `C…` id or a DM channel id like `D…` returned by `send_dm`). |
| `account_id` | A user id (e.g. a Slack `U…`). Used by `send_dm` and `list_channels`. |
| `thread_id` | Identifier of a thread root (the `id` returned by a prior `send_message` / `send_dm`). |

## Send a top-level message

`send_message` posts to a channel. Returns `{ok, id, channel_id}`. Keep `id` if you might thread-reply later.

```bash
npx mcporter call chil send_message channel_id="<CHANNEL_ID>" text="<message text>"
```

- Slack mrkdwn is supported (`*bold*`, `_italic_`, backtick code).
- The returned `id` is also the `thread_id` for `reply_in_thread`.

## Reply in a thread

`reply_in_thread` posts under an existing thread root. Returns `{ok, id, channel_id, thread_id}`. Works for channel threads AND DM threads (pass the DM channel id).

```bash
npx mcporter call chil reply_in_thread channel_id="<CHANNEL_ID>" thread_id="<root id>" text="<reply>"
```

- `thread_id` is the `id` of the **root** message. If you only have a reply's `id`, use that reply's own `thread_id` field.

## DM a user

`send_dm` opens (or reuses) a DM channel and posts a message. Returns `{ok, id, channel_id, account_id, thread_id?}`. The returned `channel_id` is the DM channel — reusable with `reply_in_thread`.

```bash
# Top-level DM
npx mcporter call chil send_dm account_id="<U0123ABC>" text="<message>"

# Reply under an earlier DM thread
npx mcporter call chil send_dm account_id="<U0123ABC>" text="<reply>" thread_id="<id from prior send_dm>"
```

- `account_id`: recipient user id (e.g. `U0123ABC`).
- `thread_id` (optional): pass the `id` from a previous `send_dm` to the same recipient to thread the reply.

## Read recent channel messages

`read_messages` returns `{messages, next_cursor, has_more}`. **One MCP call = one platform call — chil does not buffer pages.** To fetch the whole window, keep calling with the returned `cursor` until `has_more` is false.

```bash
# Most recent 20 messages
npx mcporter call chil read_messages channel_id="<CHANNEL_ID>"

# Last 24h, batches of 50
npx mcporter call chil read_messages channel_id="<CHANNEL_ID>" days="1" limit="50"

# Next page
npx mcporter call chil read_messages channel_id="<CHANNEL_ID>" days="1" limit="50" cursor="<next_cursor>"
```

- `days` (optional): only messages from the last N days. The window carries through cursor pages — pass `days` only on page 1.
- `limit` (optional): default 20, hard cap 200.
- `cursor` (optional): pass back the prior `next_cursor`. Omit on page 1.
- Without `days`, results are newest-first. With `days`, the window comes back in time-ascending batches (each batch internally newest-first) — sort client-side if you need strict order.
- Each message has `{user, text, id, thread_id?}`.

## Read a thread

`read_thread` returns `{messages, next_cursor, has_more}`. `messages[0]` on every page is the thread root — **dedupe by `id`** when stitching pages because the root may repeat.

```bash
# First page
npx mcporter call chil read_thread channel_id="<CHANNEL_ID>" thread_id="<root id>"

# Next page
npx mcporter call chil read_thread channel_id="<CHANNEL_ID>" thread_id="<root id>" cursor="<next_cursor>"
```

- `thread_id`: the `id` of the thread root (required).
- `limit` (optional): default 50, hard cap 200.
- `cursor` (optional): omit on page 1.

## Get channel info

`get_channel_info` returns `{id, name, is_private, topic, purpose}`.

```bash
npx mcporter call chil get_channel_info channel_id="<CHANNEL_ID>"
```

## List the channels a user is in

`list_channels` returns `{channels: [{id, name, is_private}, …]}` — the channels `account_id` is a member of inside the caller-org's workspace.

```bash
npx mcporter call chil list_channels account_id="<U0123ABC>"
```

- Useful before reading or posting to find a target channel by name.

## Error handling

Tool errors come back as `{isError: true, content: [{type: "text", text: "<message>"}]}`. The text is **user-presentable** — relay it verbatim and stop retrying:

- *"No chat workspace is connected for your organization. Connect a workspace and retry."*
- *"That user isn't part of your organization's workspace."*
- *"The bot is missing a permission required for this action. Ask the workspace owner to reinstall the Clode app, then retry."*
- *"The workspace's authorization is no longer valid. Ask the workspace owner to reinstall the Clode app, then retry."*
- *"The bot is not a member of this channel. Invite the bot to the channel and retry."*
- *"The chat platform is rate-limiting this workspace. Wait a few seconds and retry."*
- *"Thread not found in this channel. The parent message may have been deleted."*

Read tools may also deny with a capability-scope message (cross-org / private-non-home / no capability presented) — same handling: surface the message, don't retry.
