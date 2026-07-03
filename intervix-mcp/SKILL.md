---
name: intervix-mcp
description: >
  Intervix recruiter tools via intervix's MCP server. Create and manage
  job postings, send interview invites (single or bulk), read finished
  interview status / transcripts / recordings / proctor events, and
  manage interviewer agents — all scoped to the caller's organization.
---

# Intervix Recruiter Toolkit

Use this when you are acting on behalf of a recruiter inside an org — authoring the interview program, sending invites to candidates, and reviewing the material the interview leaves behind. Everything in this toolkit runs against **intervix's own recruiter API**, exposed as MCP tools; there is no separate REST call for you to make.

## When to reach for this

- Standing up the org's interview program: creating agents (interviewer personas), creating job postings, tuning per-job settings.
- Inviting candidates: one at a time from a chat, or in bulk from a spreadsheet.
- Reviewing a candidate: full interview record, transcript with tool calls, screen + webcam recordings, proctor events.
- Answering "what happened with candidate X" — status, terminal timestamps, why it ended.

## When NOT to reach for this

- **You are the candidate-side agent.** Nothing here belongs to the candidate flow — recording upload, lifecycle events, feedback submission, slot booking are all handled through session-scoped endpoints intervix owns internally, and are deliberately not exposed as MCP tools.
- **You want to score an interview.** Scoring is written by the interviewer agent at end-of-session through its own service-account path, not by you. It is not in this toolkit.
- **You want to touch projects.** Projects (the org's grouping layer above jobs) are out of scope here. Ask the recruiter to create the project through the intervix UI first.

## The domain in one paragraph

An **org** owns everything. Inside an org, a **project** groups **jobs** (openings). Each job pins one **agent** (the interviewer persona: name, voice, gender, brief identity) and produces many **interviews** (one per invited candidate). Every interview carries its own invite token, its own conversation transcript, its own screen + webcam recordings, and its own log of proctor events (tab switches, focus loss). You never talk about candidates in the abstract — every candidate exists as an interview under a specific job.

## The caller's organization is the only scope

Every tool is scoped to whoever is holding the JWT. You never pass `org_id`. If a job / interview / agent belongs to a different org, the tool returns `not_found` — the same error you'd get for a truly missing row. That's deliberate: cross-org existence is not information you're entitled to.

Corollary: nothing you do here can affect another org's data. If a recruiter asks you to "look up candidate Alice", they mean **within their org**. Do not offer to look elsewhere.

## Identifiers are UUIDs, and they nest

- `agent_id`, `project_id`, `job_id`, `interview_id` are all UUIDs.
- Interviews are addressed by **(job_id, interview_id)** on most read tools — not by interview_id alone. If you have only an interview_id, you'll need to find the job first (list a candidate's jobs, or ask).
- The one exception is a lightweight status peek that takes just `interview_id` — meant for polling.
- Invite tokens are separate from interview ids. The invite path (`/i/<token>`) is what you paste into an email; the interview id is what you use to look the row up later.

## Create → invite → review, in that order

You can't skip steps. A job needs an existing **agent** and an existing **project** in the same org before you can create it — if either is missing, the tool refuses with a plain-English error naming the missing piece. An interview needs an existing job. Etc.

For a fresh org this means: create at least one agent, ask the recruiter for a project, then create the job, then invite candidates.

## Bulk invites are partial-success by contract

The bulk create tool takes up to 200 candidate rows and processes each row independently. **You will get back a `created` list, an `errors` list, and a `summary` — the response always has all three, even if every row failed or every row succeeded.** Do not retry the whole batch on partial failure. Read the row indices under `errors`, fix those rows, and re-submit only them.

Row-level errors are shaped like `{"row": 4, "error": "candidate_email is required and must contain '@'"}` — the `row` field points into the original input array so the recruiter can see which spreadsheet line to edit.

## Read tools are org-scoped, not candidate-authenticated

The full-detail transcript, recordings, and proctor-events tools take **(job_id, interview_id)** and let a recruiter see everything the interview produced — score, comments, feedback, tool calls per turn, screen/webcam playback URLs, every proctor flag. This is fine because you're already authenticated as the org. The candidate never uses these tools; they have their own session-scoped path that isn't in this toolkit.

## Recording URLs expire in 24 hours

Get-recordings returns a **presigned URL per finalized recording**, valid for 24 hours. Do not stash them. If the recruiter needs the link again tomorrow, call the tool again. In-progress recordings (candidate still recording, or the finalize POST hasn't landed yet) come back with **no `url` field** — surface them as "still processing", don't invent a link.

The tool also fires a best-effort server-side finalize before listing, so a candidate whose tab died mid-upload will usually complete on the first recruiter read. If a recording stays perpetually in-progress across two or three calls, the underlying multipart upload is broken and there's nothing you can do from here.

## Transcripts and events paginate; pagination is offset-based

Transcript and events tools take `limit` + `offset` and return `{..., limit, offset, has_more}`. Loop with `offset += limit` until `has_more == false`. Defaults are tuned for a normal interview (a few dozen turns, a few hundred events) so most calls come back in one page.

Do **not** ask for a huge limit thinking you're being efficient — the tool caps them (200 for transcript, 500 for events) and silently trims. If you need everything, page through.

## Invocation

```bash
npx mcporter call intervix.<tool> key="value" key="value"
```

- All args are named: `key="value"` with quotes.
- No positional args, no `--output` flag.
- Nested objects (job `settings`, interview `metadata`) are passed as a JSON string.

For exact field names, defaults, required-vs-optional, and per-tool limits, read the tool's own MCP schema and description — they are the source of truth. This document is deliberately about the shape of the surface, not the individual tools.

## Errors

Errors come back as `{isError: true, content: [{type: "text", text: "…"}]}`. The text is short and user-presentable: relay it verbatim.

Common shapes to expect:

- `not_found` — the row doesn't exist in the caller's org (or exists in a different org). Do not retry. If the recruiter believes it should exist, ask them to double-check the id.
- Plain-English validation strings — `"title is required"`, `"candidate_email is required and must contain '@'"`, `"agent_id not found in this org"`. These come back on create/update. Fix the input; do not retry unchanged.
- `agent_in_use` — surfaces from delete-agent when a job or interview still references the agent. Reassign or remove the dependents first.
- `create_failed` / `update_failed` / `delete_failed` / `list_failed` / `lookup_failed` — an unexpected server-side failure. Retrying once is fine; if it persists, the intervix backend is unhappy and a human needs to look.

Transport-level failures (bad JSON, unknown tool, missing auth) come back on the JSON-RPC envelope with a numeric code, not as a tool result. mcporter will surface those as its own errors — you don't need to handle them.

## Gotchas

- **The agent used at interview time is fixed when the interview row is created**, not when the candidate joins. If the recruiter edits the job's agent or adds a per-candidate override *after* the invite has been sent, the invite that was already minted still points at the original agent. Cancel and re-invite if this matters.
- **Deleting a job does not delete its invites.** The invite token stays valid until it expires (7 days) or is consumed. If the recruiter needs to shut down a job in a hurry, delete or expire the invites out-of-band; the API doesn't do that as a side effect.
- **`settings` on create/update fully replaces the previous object** — it is not a partial merge. Fetch the current settings first if you want to change one field.
- **`metadata` on a candidate is capped and validated**: at most 8 keys, non-empty values, ≤64-char keys, ≤200-char values, no reserved keys (`candidate_name`, `candidate_email`, `role`, `repo_url`, `interview_id`, `public_base_url`). Bulk rows that violate this fail with the specific reason — the batch itself still completes for the good rows.
- **Status vs. full record are different tools.** The lightweight status peek returns status + terminal timestamps only. The full-record read returns those *plus* score, comments, feedback, invite token, timestamps, agent — use it when the recruiter wants to see everything, not on every poll tick.
- **Trial endpoints exist in intervix but are not in this toolkit.** If someone asks you to "create a trial interview", they mean a different, unauthenticated flow that intervix runs behind its public web UI. That path is not available through MCP.
