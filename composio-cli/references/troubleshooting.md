# Troubleshooting

Load this file when the agent is stuck on top-level Composio CLI flows.

## Not Logged In

Symptoms:

- `composio` commands fail because there is no user session

- the agent is unsure which account the CLI is using

Fix:

If `composio whoami` fails, run `composio login` and then return to the original `execute` or `search` flow.

```bash
composio whoami
```

## No Active Connection Found

Symptoms:

- `execute` reports that no active connection exists for a toolkit

Fix:

After linking, retry the exact same `execute` command.

```bash
composio link gmail --no-browser --no-wait
composio link googlecalendar --no-browser --no-wait
```

## Invalid JSON Input

Symptoms:

- `execute` rejects `-d` input

- the payload is not valid JSON or JS-style object syntax

Fix:

- Pass JSON or a JS-style object literal to `-d`

- Use `@file` for large payloads

- Use `-` to read from stdin

Examples:

```bash
composio execute GITHUB_CREATE_AN_ISSUE --skip-connection-check --dry-run -d '{"owner":"acme","repo":"app","title":"Bug report","body":"Steps to reproduce..."}'
composio execute GITHUB_CREATE_AN_ISSUE --skip-connection-check --dry-run -d '{ owner: "acme", repo: "app", title: "Bug report", body: "Steps to reproduce..." }'
composio execute GITHUB_CREATE_AN_ISSUE --skip-connection-check --dry-run -d @payload.json
cat payload.json | composio execute GITHUB_CREATE_AN_ISSUE --skip-connection-check --dry-run -d -
```

## Unknown Or Wrong Slug

Symptoms:

- the agent does not know the tool slug

- the slug exists but is not the right tool for the job

Fix:

Use multiple queries in one `search` call when exploring several related tasks at once. Use `composio tools list <toolkit>` only when the toolkit is known and you need to browse available slugs manually.

```bash
composio search "create a github issue"
composio search "send an email" --toolkits gmail
composio search "send an email" "create a github issue"
```

## Confusion About Required Inputs

Symptoms:

- unsure what fields a tool accepts

- the first payload attempt failed validation

Fix:

Use `composio tools info <slug>` only when a compact summary is needed and `execute --get-schema` output is still not enough.

```bash
composio execute GITHUB_CREATE_AN_ISSUE --get-schema -d '{}'
composio execute GITHUB_CREATE_AN_ISSUE --skip-connection-check --dry-run -d '{ owner: "acme", repo: "app", title: "Bug report", body: "Steps to reproduce..." }'
```

## Several Independent Tool Calls

Symptoms:

- need to run multiple unrelated tools in one step

- about to write a script only to execute a few independent calls

Fix:

Escalate to `composio run` only when control flow, loops, `Promise.all`, `search()` inside a script, `proxy()`, or `experimental_subAgent()` are needed.

```bash
composio execute --parallel \
  GMAIL_SEND_EMAIL -d '{ recipient_email: "a@b.com", subject: "Hi" }' \
  GITHUB_CREATE_AN_ISSUE -d '{ owner: "acme", repo: "app", title: "Bug" }'
```

## `tools info` And `tools list` Are Fallbacks

Treat these commands as secondary inspection tools:

Do not lead with them when `execute`, `search`, `--get-schema`, or `--dry-run` can get unstuck faster.

```bash
composio tools info GMAIL_SEND_EMAIL
composio tools list gmail
```
