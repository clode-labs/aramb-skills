# aramb-skills — connect is the user's action, not the Architect's (2026-07-29)

Workspace doc: `/Users/siva/workspace/claude/tasks/2026-07-29/agent-project-data-model-fixes.md`
Spec: `/Users/siva/workspace/claude/tasks/2026-07-28/agent-project-data-model/issues.md` (I1)

**Branch:** `integ/tb-export` → PR #110. Markdown only, no build.

## Why

brahmi now hides `aramb_mcp.toolkits_connect_toolkit` / `request_connection` /
`get_github_credential` from the **Architect** persona's MCP surface (`FilterToolsByMode`),
because an Architect-brokered connect scopes to the Architect's own project — which never
executes, so the authorized account is invisible at run time. Connecting is the user's
console action at their runtime project.

The skills must not instruct a persona to reach for a tool it cannot see.

## Edits

> **Correction to the original plan:** `create-agent/SKILL.md` is NOT a target. It is the
> **benji CLI** agent-scaffolding playbook (`benji agent create`, `workspace-<name>/` on
> disk) — the Architect is explicitly forbidden from using it ("no create-agent runtime
> playbook"). The Architect's real authoring surface is **`aramb-agents/SKILL.md`**, which
> is where the `request_connection` instruction actually lived.
>
> Likewise `create-workflow/SKILL.md:452` (`check_connection` → `connect_toolkit` → share
> `redirect_url`) is a **runtime node closing-instruction template** — text baked into a
> workflow node's prompt and executed by the *worker* agent, which keeps those tools.
> Left unchanged deliberately.

**`aramb-agents/SKILL.md`** — the section "Required toolkits — connect the accounts an
agent needs (`aramb_mcp.toolkits_request_connection`)" is rewritten to
"Required toolkits — you DECLARE them, the USER connects them": ground slugs via
`list_toolkits`, set `required_toolkits`, hand the connect step to the user on the Tools
page. States why (a builder-brokered connection scopes to a project that never executes)
and keeps the existing truthfulness rule, restated for the new reality.

**`create-workflow/SKILL.md`** — under MUST rule 1 (`required_toolkits` per node), add
that declaring is the whole job; the user connects. Explicitly notes this is no reason to
avoid authoring a workflow.

**`aramb-toolkits/SKILL.md`** — this skill is shared by all personas, and
`connect_toolkit` / `get_github_credential` remain valid for non-Architect agents. Do
**not** delete those sections. Add a short availability note near the top (around the
routing table at line ~29-32):

> **Availability:** `connect_toolkit` / `request_connection` / `get_github_credential` are
> not advertised to the **Architect** persona — the builder declares `required_toolkits`
> and the user connects the accounts in the console. If a tool below isn't in your tool
> list, that's why; say so plainly and point the user at the Tools page instead of
> improvising a link.

Keep `list_toolkits` documented as always available — grounding `required_toolkits` slugs
depends on it.

**NO `Co-Authored-By: Claude` trailer on commits.**
