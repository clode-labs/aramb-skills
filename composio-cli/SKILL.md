---
name: composio-cli
description: Help agents operate the Composio CLI to find the right tool, connect accounts, inspect schemas, execute tools, subscribe to trigger events with `composio listen`, script workflows with `composio run`, and call authenticated app APIs with `composio proxy`. Use when the agent needs to discover a slug with `composio search`, fix a missing connection with `composio link`, inspect tool inputs with `--get-schema` or `--dry-run`, or run any composio command.
---

# Composio CLI

## ⚠️ GitHub is NOT a Composio toolkit

Do NOT use `composio execute GITHUB_*` or `composio search "github..."`. GitHub
lives in gitana — a different broker — and every `GITHUB_*` slug is rejected
on the `/cli` surface with `403 github is not on /cli`. GitHub tools are also
hidden from `composio search` results (no slugs to discover).

To do GitHub work:
1. Call `aramb_toolkits.get_github_credential` (MCP tool, no arguments) → returns `{username: "x-access-token", token, account_ref}`.
2. Export the token: `export GH_TOKEN=<token>`.
3. Use **native git / gh CLI** for everything: `git clone`, `git push`, `gh pr create`, `gh issue list`, `gh release create`, etc.
4. On 401 from git/gh, call `aramb_toolkits.get_github_credential` again for a fresh token (~8h lifetime).

See the `aramb-toolkits` skill for the full GitHub workflow.

## Default Workflow (for non-GitHub toolkits)

1. Start with `composio execute <slug>` whenever the slug is known.
2. If several independent tool calls must happen at once, use `composio execute -p/--parallel` with repeated `<slug> -d <json>` groups.
3. If `execute` says the toolkit is not connected, run `composio link <toolkit>` and retry.
4. If the arguments are unclear, run `composio execute <slug> --get-schema` or `--dry-run` before guessing.
5. Reach for `composio search "<task>"` only when the slug is unknown. `search` accepts one or more queries, so batch related discovery work into a single command when useful.

## `execute` - Run A Tool

Use `execute` when the tool slug is already known.

```bash
composio execute GMAIL_GET_PROFILE -d '{}'
```

Inspect required inputs without executing:
```bash
composio execute GMAIL_SEND_EMAIL --get-schema
```

Preview safely:
```bash
composio execute GMAIL_SEND_EMAIL --skip-connection-check --dry-run -d '{ recipient_email: "user@example.com", subject: "Hi", body: "Hello" }'
```

Pass data from a file or stdin:
```bash
composio execute GMAIL_SEND_EMAIL -d @issue.json
cat issue.json | composio execute GMAIL_SEND_EMAIL -d -
```

Upload a local file:
```bash
composio execute SLACK_UPLOAD_OR_CREATE_A_FILE_IN_SLACK \
  --file ./image.png \
  -d '{ channels: "C123" }'
```

Run independent tool calls in parallel:
```bash
composio execute --parallel \
  GMAIL_SEND_EMAIL -d '{ recipient_email: "a@b.com", subject: "Hi" }' \
  GMAIL_SEND_EMAIL -d '{ recipient_email: "user@example.com", subject: "Hi", body: "Hello" }'
```

Key flags:
- `--get-schema`: Inspect required arguments without executing the tool.
- `--dry-run`: Preview the request shape without performing the action.
- `--file`: Inject a local file path into a tool that exposes exactly one uploadable file argument.
- `--parallel`: Execute multiple independent tool calls in the same invocation.
- `--account`: Select which connected account to use by alias, word_id, or account id when multiple accounts exist for the same toolkit.

- `--file` only works when the tool exposes a single uploadable file input. Otherwise use explicit `-d` JSON.

## `search` - Find The Slug

Use `search` only when the tool slug is not already known.

```bash
composio search "send an email"
composio search "send an email" --toolkits gmail
composio search "send an email" "create a slack message"
composio search "list calendar events" "send an email" --toolkits googlecalendar,gmail
```

- Batch related discovery work into one `search` invocation, then move back to `execute` once the correct slugs are known.
- `composio search "<query>" --toolkits github` returns nothing — github is intentionally hidden (see the GitHub callout at the top).

## `link` - Connect An Account

Use `link` when `execute` reports that a toolkit is not connected, or when the user explicitly wants to authorize an account.

```bash
composio link gmail
composio link googlecalendar --no-browser
```

Key flags:
- `--alias`: Assign an alias to the connected account. Required when creating an additional account for the same toolkit.

- Retry the original `execute` command after linking succeeds.

## `proxy` - Raw API Access

Use `proxy` when a toolkit supports a raw API operation that is easier than finding a dedicated tool slug.

```bash
composio proxy https://gmail.googleapis.com/gmail/v1/users/me/profile --toolkit gmail --method GET </dev/null
```

> `composio proxy ... --toolkit github` is blocked — github isn't on the `/cli` surface. Use `aramb_toolkits.get_github_credential` then native `gh api /user`.

## `run` - Scripting, LLMs, and Programmatic Workflows

For programmatic calls, loops, output plumbing, or anything beyond a single tool call, prefer `composio run`.

`composio run` executes an inline ESM JavaScript/TypeScript snippet with authenticated `execute()`, `search()`, `proxy()`, and the experimental `experimental_subAgent()` helper pre-injected. No SDK setup required.

Chain multiple tools:
```bash
composio run '
  const me = await execute("GMAIL_GET_PROFILE");
  const emails = await execute("GMAIL_FETCH_EMAILS", { max_results: 1 });
  console.log({ login: me.data.login, fetchedEmails: !!emails.data });
'
```

Fan out with Promise.all:
```bash
composio run '
  const [me, emails] = await Promise.all([
    execute("GMAIL_GET_PROFILE"),
    execute("GMAIL_FETCH_EMAILS", { max_results: 5 }),
  ]);
  console.log({ login: me.data.login, emailCount: emails.data.messages?.length });
'
```

Feed tool output into an LLM and get structured JSON back:
```bash
composio run --logs-off '
  const emails = await execute("GMAIL_FETCH_EMAILS", { max_results: 5 });
  const brief = await experimental_subAgent(
    `Summarize these emails and count them.\n\n${emails.prompt()}`,
    { schema: z.object({ summary: z.string(), count: z.number() }) }
  );
  console.log(brief.structuredOutput);
'
```

- Use top-level `execute --parallel` instead when the user only needs a few independent tool calls and does not need script logic.

## Auth

```bash
composio whoami   # check current session
composio login    # authenticate if whoami fails
```

## Escalate Only When Needed

If the user is stuck on top-level commands or needs fallback inspection commands, load [references/troubleshooting.md](references/troubleshooting.md).

If the user needs more complex scripting patterns, `composio run` with LLMs, or `proxy()` examples, load [references/power-user-examples.md](references/power-user-examples.md).
