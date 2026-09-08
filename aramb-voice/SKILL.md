---
name: aramb-voice
description: >
  MCP toolkit for voice notes (aramb_mcp.voice_transcribe / aramb_mcp.voice_synthesize).
  Use voice_transcribe to read an incoming voice note (audio file → text), and
  voice_synthesize to speak a reply (text → audio) that you then hand to
  aramb_chat.deliver_artifacts as a downloadable/playable attachment. Use for
  chat surfaces that exchange voice messages (Slack, WhatsApp, Telegram, and
  the like). NOT for placing phone calls — that is aramb_phone.
---

# Aramb Voice Toolkit

Two tools turn audio into text and text into audio, so an agent can **read the
voice notes people send** and **reply with a spoken voice note**.

- `aramb_mcp.voice_transcribe` — an incoming audio file → its text.
- `aramb_mcp.voice_synthesize` — your text → an audio file, returned as a blob
  artifact you deliver through `aramb_chat`.

## When to use this

- A user sends a **voice message** and you need its contents → `voice_transcribe`.
- You want to answer **out loud** (a spoken reply on a chat that supports voice
  notes) → `voice_synthesize`, then deliver the result.
- Accessibility or hands-free flows where a spoken reply is expected.

**Do NOT** use this to place a real phone call (that is `aramb_phone`), or to send
an ordinary text message (that is `aramb_chat`). Synthesizing audio is only worth
it when the recipient actually wants a voice note.

## CRITICAL: mcporter syntax rules

- ALL arguments MUST use `key="value"` format (NOT positional args).
- Do NOT use `--output` — it is not supported by `mcporter call`.

## Tool 1 — `voice_transcribe` (voice note → text)

When a voice note arrives it is attached to your message like any other file, and
shown to you as a path, e.g. `@/…/attachments/<id>-note.ogg`. Pass that path
**exactly as shown** — the platform resolves it to the stored audio for you; you
never handle a storage key yourself. A leading `@` is optional and a bare
absolute path also works.

Args:
- `audio` (required) — the attachment path of the voice note, as shown to you.
- `language` (optional) — a hint like `en`; omit to auto-detect.

```bash
npx mcporter call aramb_mcp.voice_transcribe audio="@/…/attachments/<id>-note.ogg"
```

Returns:

```json
{ "text": "the spoken words, transcribed", "language": "en", "duration_seconds": 2.9 }
```

Read `text` and continue as you would with any user message.

## Tool 2 — `voice_synthesize` (text → voice note) + delivery

`voice_synthesize` speaks your text and returns a **blob artifact descriptor** —
it does not send anything on its own. To get the voice note to the user you pass
that descriptor to `aramb_mcp.chat_deliver_artifacts` (see the `aramb-chat`
skill).

Args:
- `text` (required) — what to say. Keep it to what should be spoken aloud (no
  markdown, links, or code — those do not read well as speech).
- `format` (optional) — `ogg` (default) or `mp3`. Prefer **`ogg`**: it is the
  voice-note format chat apps expect, so it plays inline as a voice message.
- `voice_id` (optional) — a specific voice from the voice catalog; omit for the
  default voice.

```bash
npx mcporter call aramb_mcp.voice_synthesize text="Your order ships tomorrow — talk soon!" format="ogg"
```

Returns a ready-to-deliver blob:

```json
{ "kind": "blob", "s3_key": "…", "content_type": "audio/ogg",
  "filename": "voice-note.ogg", "size": 4841 }
```

### Delivering it

Pass it to `deliver_artifacts` in the `artifacts` array. The **only required
field is `s3_key`**; the platform infers the audio type from the key, so a
minimal delivery is just `kind` + `s3_key`. Optionally add `name` (display
filename) and `mime_hint` (e.g. `audio/ogg`):

```bash
npx mcporter call aramb_mcp.chat_deliver_artifacts \
  artifacts='[{"kind":"blob","s3_key":"…","name":"voice-note.ogg","mime_hint":"audio/ogg"}]'
```

The delivery layer re-validates the `s3_key` against your session and generates a
fresh download/playback URL when the message is sent, so the recipient gets a
playable voice note. You never construct or presign a URL yourself.

> Field-name note: `voice_synthesize` reports the audio as `content_type` /
> `filename`, but `deliver_artifacts` reads the equivalent optionals as
> `mime_hint` / `name`. Either way `s3_key` is the field that matters — the rest
> is inferred if omitted.

## End-to-end pattern (reply to a voice note with a voice note)

1. A voice note arrives → call `voice_transcribe` with its `@path` → read `text`.
2. Decide your reply and keep it speakable (plain sentences).
3. `voice_synthesize` your reply (`format="ogg"`) → get the blob descriptor.
4. `deliver_artifacts` with that descriptor → the user hears your answer.

## Notes

- Supported voice-note formats include ogg/opus, mpeg (mp3), wav, mp4/m4a, webm,
  and opus. If a sender's clip is in another container, transcription may return
  empty text — ask them to resend as a standard voice note.
- Synthesis and transcription each run a real speech model; use them when a
  voice interaction is actually intended, not for routine text turns.
