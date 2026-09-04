---
name: indeed-mcp
description: >
  Indeed job search via the indeed-mcp server. Search live Indeed job
  postings with rich filters (location, country, remote, job type,
  recency) and look up an employer's public profile plus its open roles.
  Anonymous public data — no candidate login, no resumes.
---

# Indeed Job Search Toolkit

Use this when the person you're helping wants to **find jobs on Indeed** or learn about a **company that's hiring**. Everything here runs against Indeed's public job data, exposed as MCP tools — there is no separate API call for you to make, and no account or login is involved.

## When to reach for this

- "Find me remote Go jobs", "software roles in Austin posted this week", "part-time nursing jobs near Boston".
- Narrowing a search: by location + radius, country, remote-only, employment type, or recency.
- "Tell me about company X" when the intent is *who's hiring and what roles are open* — industry, size, revenue, website, logo, and a sample of current openings.

## When NOT to reach for this

- **Résumé / candidate data.** Indeed's résumé and applicant tools are gated behind a partner login we don't have. There is no "get resume", no application submission, no candidate profiles here. If asked, say plainly that only public job-search data is available.
- **Applying to a job.** These tools read postings; they don't apply. Hand the user the `job_url` / `job_url_direct` to apply themselves.
- **Non-Indeed sources.** This is Indeed only. It won't search LinkedIn, Glassdoor, company career pages, etc.

## The two tools

- **`search_jobs`** — the workhorse. Returns a list of postings with full detail *inline*: title, company, location, remote flag, job type(s), date posted, salary (when present), apply URLs, employer profile fields, and the full job description. One call answers most requests.
- **`get_company`** — an employer's public profile (industry, size, revenue, website, logo, description) plus a sample of its current open roles. It's built *on top of* search, so read its caveat below.

You do not need `org_id`, a token, or any credential — the tools are anonymous.

## Searching well

`query` is the only required argument. Everything else narrows the result:

- **`query`** — job title / keywords, e.g. `"senior golang engineer"`. Keep it to the role, not the location.
- **`location`** — city/region, e.g. `"Austin, TX"`. Pair with **`distance`** (miles, default 50) for a radius. Omit for a nationwide search.
- **`country`** — an Indeed country name: `"USA"` (default), `"India"`, `"UK"`, `"Canada"`, `"Germany"`, `"Australia"`, etc. Set this whenever the user is clearly outside the default country — Indeed is per-country, so a US search won't surface London roles.
- **`remote`** — `true` to restrict to remote/WFH roles.
- **`job_type`** — one of `fulltime` / `parttime` / `contract` / `internship`.
- **`hours_old`** — only postings from the last N hours (e.g. `24` for "today", `168` for "this week"). **Takes precedence over `remote`/`job_type`** — Indeed can't combine a recency filter with the type filter, so if you set `hours_old`, the type/remote filters are ignored. Pick one intent.
- **`results_wanted`** — how many to return (default 15, max 100). Ask for a handful unless the user wants a long list — full descriptions are verbose.
- **`offset`** — skip the first N for a "show me more" follow-up. Capped, so this is for one extra page, not deep scrolling.

Prefer one well-shaped call over many. If the first result set is too broad, *tighten* (add location/type/recency) rather than paging.

## `get_company` — know its shape

`get_company` runs a keyword search for the company name and returns the profile of the best-matching employer plus its open roles. Because it's search-backed:

- A **name-only** query can surface a posting that merely *mentions* the term rather than one *from* that employer (e.g. "Stripe" may match a role that lists Stripe as a skill). Add a `location` or use a distinctive full company name to disambiguate, and tell the user when the match looks loose (`matched_exact: false` in the result).
- `found: false` means no posting matched — the company may simply have no current Indeed openings, which is not the same as "doesn't exist."
- Profile fields (industry, size, revenue, logo) come from Indeed's employer dossier and are often **partial or null** — surface what's there, don't invent the rest.

For a specific, known employer with open roles, `search_jobs` with the company name in `query` (or as part of it) is often clearer than `get_company`.

## Presenting results to the user

- Lead with the **title, company, and location**; add **salary** and **remote** when present. Give the **`job_url`** so they can open/apply.
- Full descriptions are long — **summarize** per role and offer the link, rather than dumping every description, unless the user asked for full text on a specific job.
- Many real postings have **no employer name** (aggregated listings) or **no salary** — that's normal. Say "salary not listed", don't guess or omit the row.
- Salary comes with an `interval` (`yearly`/`hourly`/…) and a `source` (`direct` from the employer, or `estimated` by Indeed) — mention "estimated" when that's what it is.

## Invocation

```bash
npx mcporter call <alias>.search_jobs query="golang engineer" location="Remote" results_wanted="5"
npx mcporter call <alias>.get_company company="Stripe"
```

- `<alias>` is the name this MCP server was attached under in your configuration.
- All args are named `key="value"` with quotes. Numbers and booleans are passed as quoted strings (`results_wanted="5"`, `remote="true"`).
- For exact field names, defaults and limits, the tool's own MCP schema/description is the source of truth — this document is about the shape of the surface, not each field.

## Errors

Tool errors come back as `{isError: true, content: [{type: "text", text: "…"}]}`. The text is short and user-presentable — relay it. The common one is `Indeed request failed: …` (a network or upstream hiccup); a single retry is fine, and if it persists, tell the user Indeed is temporarily unavailable rather than fabricating results.

## Gotchas

- **`hours_old` disables `job_type`/`remote`.** Don't set all three and expect all three — recency wins. If the user wants "remote roles posted today", search remote first and mention recency, or vice-versa, but don't rely on the combination.
- **`country` is not `location`.** "Jobs in Toronto" needs `country: "Canada"` *and* `location: "Toronto"` — a US-country search for a Canadian city returns little.
- **`offset` is shallow.** It's capped for rate-limit safety; use it for one "more results" step, not to walk hundreds of listings.
- **Descriptions are HTML-flattened to text** — mostly clean, but occasionally a little rough. Summarize rather than pasting raw.
- **No résumé, no apply, no auth.** If a request needs any of those, it's out of scope — say so and hand over the apply URL.
