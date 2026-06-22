---
name: chil-mcp
description: >
  Chat tools via chil's MCP server. Post, reply, DM, ask, read channels
  and threads, list a user's channels — on whatever chat platform the
  caller's org has installed (Slack today; MS Teams / Discord later).
---

# Chil Chat Toolkit

Use this when you need to talk to a chat platform on behalf of the caller's organization — sending a message, asking the user a question, reading recent history, looking up a channel or a user's channels.

## Provider model

Chil is a chat-platform-agnostic gateway. The org has exactly one chat platform installed (Slack, MS Teams, Discord, …), and chil exposes only that platform's tools to you. You do not choose the provider — it is decided by the caller's organization.

Tools are named `<provider>_<action>`, e.g. `slack_post_message`, `msteams_post_message`, `discord_post_message`. If you see `slack_*` tools in your tool list, the org is on Slack; you will not see `msteams_*` or `discord_*` and there is no point asking for them.

The examples below all use Slack because that is what most orgs have today. The pattern (`<provider>_<verb>`, same argument shape modulo platform-native fields) is the same on any platform.

## You own the formatting

Chil sends what you give it, verbatim, to the platform. Plain text goes through as plain text. If you want a richer message (buttons, sections, images, dividers, code blocks rendered properly, mentions that resolve, an action card), pass the platform's native rich-content payload in the tool call — Slack Block Kit for `slack_*`, Adaptive Cards for `msteams_*`, embeds + components for `discord_*`. The tool schema documents which field carries it.

Use rich content when the message is decision-shaped (a question with choices, an approval, a link with context) or status-shaped (a deploy summary, a check list). Use plain text for one-liners.

## Identifiers

Channel ids, user ids, and thread ids are always **the platform's own ids** (Slack `C…`/`U…`/`ts`, Teams channel + message ids, Discord snowflakes). Chil does not invent its own ids. The `id` returned by a send call is the message id — reuse it as `thread_id` when you want the next message to land in the same thread.

## Invocation

```bash
npx mcporter call chil.<tool> key="value" key="value"
```

- All args are named: `key="value"` with quotes.
- No positional args, no `--output` flag.
- Rich payloads (Block Kit, Adaptive Card, embeds) are passed as a JSON string in the documented field.

## Examples (Slack — substitute your org's provider prefix)

```bash
# Plain message
npx mcporter call chil.slack_post_message channel_id="C0B8P73U77Y" text="Deploy starting in 5 min"

# Reply in a thread (thread_id = id from a prior send / read)
npx mcporter call chil.slack_reply_in_thread channel_id="C0B8P73U77Y" thread_id="1781360386.219519" text="Done."

# Rich message with a button — full Block Kit in `blocks`
npx mcporter call chil.slack_post_message channel_id="C0B8P73U77Y" \
  text="Ready to deploy?" \
  blocks='[{"type":"section","text":{"type":"mrkdwn","text":"*Ready to deploy?*"}},{"type":"actions","elements":[{"type":"button","text":{"type":"plain_text","text":"Yes"},"value":"yes"},{"type":"button","text":{"type":"plain_text","text":"No"},"value":"no"}]}]'

# DM a user
npx mcporter call chil.slack_send_dm account_id="U0BABQ1V882" text="Quick sync?"

# Read recent history, paginate via cursor
npx mcporter call chil.slack_read_messages channel_id="C0B8P73U77Y" days="7"
```

For exact field names, defaults, limits, and any platform-specific extras, read the tool's own MCP schema and description — they are the source of truth.

## Receiving button clicks

If you post a Block Kit button (or any interactive element) and want the click to come back to you, give the button an `action_id` that starts with **`aramb_btn:`**. Whatever you put after the colon is yours — an option name, a correlation id, a small payload — and you'll get it back verbatim.

When the user clicks, the click arrives as a regular user message in the same thread. The message body is the button's `value` (falling back to the button label if `value` is empty), followed by a single machine-readable line:

```
<value-or-label>

[aramb:button] action_id=aramb_btn:<your-suffix> message_ts=<ts> user=<U…>
```

That `message_ts` is the same `id` you got back from your earlier `slack_post_message` (or reply/DM) call, so you can pinpoint which of your messages was clicked — even if the user replied much later, after other conversation.

Buttons without the `aramb_btn:` prefix are ignored. The convention is the only handshake — nothing is registered server-side per button.

Example (one card, two buttons, distinct correlation):

```json
{
  "type": "actions",
  "elements": [
    {"type": "button", "action_id": "aramb_btn:deploy_yes", "text": {"type": "plain_text", "text": "Yes, deploy"}, "value": "yes"},
    {"type": "button", "action_id": "aramb_btn:deploy_no",  "text": {"type": "plain_text", "text": "Cancel"},     "value": "no"}
  ]
}
```

A click on the first button arrives as `"yes\n\n[aramb:button] action_id=aramb_btn:deploy_yes message_ts=…"` in the thread.

> Note: today the click is attributed to the org's service account, not the human who clicked. Identity-preserving forwarding is a tracked follow-up.

## Errors

Errors come back as `{isError: true, content: [{type: "text", text: "…"}]}`. The text is user-presentable: relay it verbatim and stop retrying. Capability / membership / rate-limit / stale-thread errors are not something you can fix by retrying or by trying a different provider's tool — there is no different provider.
