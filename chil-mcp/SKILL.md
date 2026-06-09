---
name: chil-mcp
description: >
  MCP toolkit for Slack chat via chil's MCP server (chat.*). Use these
  to post messages, reply in threads, read channel history and threads,
  and inspect channel info. Calls are scoped by application_id (one Slack
  channel per app), and READ tools may instead scope by channel_id+team_id
  to read a channel that has no per-channel application.
---

# Chil Chat Toolkit

The `chat.*` tools talk to Slack on the agent's behalf via chil. Most calls carry `application_id` — chil resolves it to the linked Slack channel and uses the workspace's bot token automatically.

**Two ways to name the channel on READ tools** (`chat.read_messages`, `chat.read_thread`, `chat.get_channel_info`):
- **`application_id`** — the app linked to a single channel (the usual case).
- **`channel_id` + `team_id`** — a Slack channel id (e.g. `C0123ABC`) plus its workspace/team id (e.g. `T0123ABC`), used to read a channel that has **no per-channel application** (e.g. scanning many public channels of a workspace). Only public channels in the agent's own org are readable this way. WRITE tools (`chat.send_message`, `chat.reply_in_thread`) require `application_id` — they do not accept `channel_id`.

## CRITICAL: mcporter syntax rules
- ALL arguments MUST use `key="value"` format (NOT positional args).
- Do NOT use `--output` — it is not supported by mcporter call.
- **Scope every call.** Write tools: always include `application_id`. Read tools: include EITHER `application_id` OR `channel_id`+`team_id` — without one of those the call has no scope.

## Send a top-level message

`chat.send_message` posts a new top-level message to the channel linked to this application. Returns `{ok, ts, channel}`. Keep the returned `ts` if you might want to reply to this message in a thread later.

```bash
npx mcporter call chat.send_message application_id="<APPLICATION_ID>" text="<message text>"
```

- Slack mrkdwn is supported in `text` (`*bold*`, `_italic_`, backtick code).
- Returns the Slack message timestamp `ts` — that's also the `thread_ts` you'd pass back to `chat.reply_in_thread`.

## Reply inside an existing thread

`chat.reply_in_thread` posts a reply under an existing thread root. Returns `{ok, ts, channel, thread_ts}`. Use this when continuing a conversation under a specific message.

```bash
npx mcporter call chat.reply_in_thread application_id="<APPLICATION_ID>" thread_ts="<root message ts>" text="<reply text>"
```

- `thread_ts` is the `ts` of the **root** message of the thread (not a reply's `ts`). If you only have a reply's `ts`, use the reply's own `thread_ts` field instead.

## Read recent channel messages

`chat.read_messages` returns `{messages, next_cursor, has_more}`. **One MCP call = one Slack call — chil does not buffer pages.** To fetch everything, keep calling with the returned `cursor` until `has_more` is false.

```bash
# Most recent 20 messages
npx mcporter call chat.read_messages application_id="<APPLICATION_ID>"

# Last 24h, in batches of 50
npx mcporter call chat.read_messages application_id="<APPLICATION_ID>" days="1" limit="50"

# Next page of the same window
npx mcporter call chat.read_messages application_id="<APPLICATION_ID>" days="1" limit="50" cursor="<next_cursor from prior response>"

# By channel_id + team_id (a channel with no per-channel app — e.g. scanning workspace channels)
npx mcporter call chat.read_messages channel_id="<CHANNEL_ID>" team_id="<TEAM_ID>" days="7" limit="50"
```

- `channel_id` + `team_id` (optional alternative to `application_id`): read a Slack channel directly. Use this when you were given raw channel ids to scan and there is no application per channel. Only public channels in your org resolve this way.
- `days` (optional): only messages from the last N days. Translates to Slack's `oldest`. Slack carries the window through cursor pages — pass `days` only on page 1.
- `limit` (optional): max messages per page. Default 20, hard cap 200.
- `cursor` (optional): pass back the `next_cursor` from the previous response to fetch the next page. Omit on the first call.
- Without `days`, results are newest-first. With `days` set, Slack returns the window in time-ascending batches (each batch internally newest-first). Sort client-side if you need strict order.

## Read a thread

`chat.read_thread` returns `{messages, next_cursor, has_more}`. `messages[0]` on every page is the thread root — when stitching pages together, **dedupe by `ts`** because Slack repeats the root on each page.

```bash
# First page of a thread
npx mcporter call chat.read_thread application_id="<APPLICATION_ID>" thread_ts="<root message ts>"

# Next page of the same thread
npx mcporter call chat.read_thread application_id="<APPLICATION_ID>" thread_ts="<root message ts>" cursor="<next_cursor from prior response>"
```

- `thread_ts`: the `ts` of the thread root.
- `limit` (optional): max replies per page. Default 50, hard cap 200.
- `cursor` (optional): `next_cursor` from a prior response. Omit on the first call.

## Get channel info

`chat.get_channel_info` returns `{id, name, is_private, topic, purpose}`. Useful when the agent needs to know which channel it's talking in.

```bash
npx mcporter call chat.get_channel_info application_id="<APPLICATION_ID>"

# Or by channel_id + team_id (channel with no per-channel app)
npx mcporter call chat.get_channel_info channel_id="<CHANNEL_ID>" team_id="<TEAM_ID>"
```

## Error handling

Tool errors come back as `{isError: true, content: [{type: "text", text: "<message>"}]}`. The text is **user-presentable** — relay it verbatim if you need to tell the user what's wrong:

- *"The Slack bot is missing a permission required for this action. Ask the workspace owner to reinstall the Clode app in Slack to grant the new scope, then retry."*
- *"The Slack workspace's authorization is no longer valid. Ask the workspace owner to reinstall the Clode app in Slack, then retry."*
- *"The Slack bot is not a member of this channel. Invite the bot to the channel and retry."*
- *"Slack is rate-limiting this workspace. Wait a few seconds and retry."*
- *"Thread not found in this channel. The parent message may have been deleted."*

For any of these, surface the message to the user (so they can take the named action) and stop retrying that call.
