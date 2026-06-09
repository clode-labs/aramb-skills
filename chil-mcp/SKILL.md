---
name: chil-mcp
description: >
  MCP toolkit for Slack chat via chil's MCP server (chat.*). Use these
  to post messages, reply in threads, DM users, and read channel/thread
  history. Calls scope by application_id (channel-linked app) or, on
  reads, by channel_id+team_id; chat.send_dm scopes by slack_account_id+team_id.
---

# Chil Chat Toolkit

The `chat.*` tools talk to Slack on the agent's behalf via chil. Chil resolves the scope to a workspace bot token and runs the Slack call.

**Three scope models** depending on the tool:

| Scope | Used by | Args |
|---|---|---|
| Application-scoped | `chat.send_message`, `chat.reply_in_thread` | `application_id` (required) |
| Application or channel-scoped | `chat.read_messages`, `chat.read_thread`, `chat.get_channel_info` | `application_id` **OR** `channel_id`+`team_id` |
| User-scoped (DM) | `chat.send_dm` | `slack_account_id`+`team_id` (no `application_id`) |

`channel_id`+`team_id` is for reading channels with no per-channel app (e.g. scanning the public channels of a workspace). Only public channels in the agent's own org resolve this way.

## CRITICAL: mcporter syntax rules
- All arguments use `key="value"` format (NOT positional).
- Do NOT pass `--output` — unsupported.
- Always include the scope args for the tool you're calling (see table above).

## Send a top-level message

`chat.send_message` posts to the channel linked to this application. Returns `{ok, ts, channel}`. Keep `ts` if you might thread-reply later.

```bash
npx mcporter call chat.send_message application_id="<APPLICATION_ID>" text="<message text>"
```

- Slack mrkdwn is supported (`*bold*`, `_italic_`, backtick code).
- The returned `ts` is also the `thread_ts` for `chat.reply_in_thread`.

## Reply in a thread

`chat.reply_in_thread` posts under an existing thread root. Returns `{ok, ts, channel, thread_ts}`.

```bash
npx mcporter call chat.reply_in_thread application_id="<APPLICATION_ID>" thread_ts="<root ts>" text="<reply>"
```

- `thread_ts` is the `ts` of the **root** message. If you only have a reply's `ts`, use that reply's own `thread_ts` field.

## DM a Slack user

`chat.send_dm` opens (or reuses) a DM channel with a specific Slack user and posts a message. Returns `{ok, channel, ts, slack_user_id, team_id, thread_ts?}`. Note: scope is the **user**, not an application — the workspace bot for `team_id` authorizes the send.

```bash
# Top-level DM
npx mcporter call chat.send_dm slack_account_id="<U0123ABC>" team_id="<T0123ABC>" text="<message>"

# Reply under an earlier DM thread
npx mcporter call chat.send_dm slack_account_id="<U0123ABC>" team_id="<T0123ABC>" text="<reply>" thread_ts="<ts from prior send_dm>"
```

- `slack_account_id`: recipient Slack user id (e.g. `U0123ABC`).
- `team_id`: the workspace the user belongs to.
- `thread_ts` (optional): pass back the `ts` from a previous `chat.send_dm` to the same recipient to thread the reply.

## Read recent channel messages

`chat.read_messages` returns `{messages, next_cursor, has_more}`. **One MCP call = one Slack call — chil does not buffer pages.** To fetch the whole window, keep calling with the returned `cursor` until `has_more` is false.

```bash
# Most recent 20 messages
npx mcporter call chat.read_messages application_id="<APPLICATION_ID>"

# Last 24h, batches of 50
npx mcporter call chat.read_messages application_id="<APPLICATION_ID>" days="1" limit="50"

# Next page
npx mcporter call chat.read_messages application_id="<APPLICATION_ID>" days="1" limit="50" cursor="<next_cursor>"

# By channel_id + team_id (channel with no per-channel app)
npx mcporter call chat.read_messages channel_id="<C0123ABC>" team_id="<T0123ABC>" days="7" limit="50"
```

- `days` (optional): only messages from the last N days. Slack carries the window through cursor pages — pass `days` only on page 1.
- `limit` (optional): default 20, hard cap 200.
- `cursor` (optional): pass back the prior `next_cursor`. Omit on page 1.
- Without `days`, results are newest-first. With `days`, Slack returns the window in time-ascending batches (each batch internally newest-first) — sort client-side if you need strict order.

## Read a thread

`chat.read_thread` returns `{messages, next_cursor, has_more}`. `messages[0]` on every page is the thread root — **dedupe by `ts`** when stitching pages because Slack repeats the root.

```bash
# First page
npx mcporter call chat.read_thread application_id="<APPLICATION_ID>" thread_ts="<root ts>"

# Next page
npx mcporter call chat.read_thread application_id="<APPLICATION_ID>" thread_ts="<root ts>" cursor="<next_cursor>"

# By channel_id + team_id
npx mcporter call chat.read_thread channel_id="<C0123ABC>" team_id="<T0123ABC>" thread_ts="<root ts>"
```

- `thread_ts`: the `ts` of the thread root (required).
- `limit` (optional): default 50, hard cap 200.
- `cursor` (optional): omit on page 1.

## Get channel info

`chat.get_channel_info` returns `{id, name, is_private, topic, purpose}`.

```bash
npx mcporter call chat.get_channel_info application_id="<APPLICATION_ID>"

# Or by channel_id + team_id
npx mcporter call chat.get_channel_info channel_id="<C0123ABC>" team_id="<T0123ABC>"
```

## Error handling

Tool errors come back as `{isError: true, content: [{type: "text", text: "<message>"}]}`. The text is **user-presentable** — relay it verbatim and stop retrying:

- *"The Slack bot is missing a permission required for this action. Ask the workspace owner to reinstall the Clode app in Slack to grant the new scope, then retry."*
- *"The Slack workspace's authorization is no longer valid. Ask the workspace owner to reinstall the Clode app in Slack, then retry."*
- *"The Slack bot is not a member of this channel. Invite the bot to the channel and retry."*
- *"Slack is rate-limiting this workspace. Wait a few seconds and retry."*
- *"Thread not found in this channel. The parent message may have been deleted."*

Read tools may also deny with a capability-scope message (cross-org / private-non-home / no capability presented) — same handling: surface the message, don't retry.
