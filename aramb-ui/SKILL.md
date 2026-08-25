---
name: aramb-ui
description: >
  MCP toolkit for driving the console UI (aramb_mcp.ui_*). Use these to move the
  user's view to a specific console page (navigate) and to read a page's
  structured layout — its buttons, tabs, and where they sit — so you can point
  the user at the exact on-screen control. You live in the console side panel,
  so put the user in front of the right screen instead of only describing where
  to click.
---

# Aramb UI Toolkit

The `aramb_mcp.ui_*` tools let you act on the console the user is looking at while they talk to you. Two tools:

- `aramb_mcp.ui_navigate` — move the user's console to an in-app page.
- `aramb_mcp.ui_read_layout` — read a page's structured layout (actions + where they are) so you can guide a click when there is no navigable target.

Prefer *showing* over *telling*: when you finish an action, take the user to where it landed instead of reciting a path.

## CRITICAL: mcporter syntax rules
- ALL arguments MUST use `key="value"` format (NOT positional args).
- Do NOT use `--output`.
- ALWAYS include `project_id` and `application_id` (copy them from your User Message context). The agent serves multiple applications — without them the action hits the wrong console.

## Navigate the user's view

`aramb_mcp.ui_navigate` sends the console to a page. The path must be a **relative** console path under `/app/` — never a full URL, never a domain.

```bash
npx mcporter call aramb_mcp.ui_navigate project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" path="/app/agents/<AGENT_ID>/configure" reason="Opening the Configure page"
```

- `path` — a relative `/app/…` path. Get the exact path for a screen from `read_layout` (or the console map you already know), e.g. `/app/agents/<AGENT_ID>/knowledge`, `/app/agents/<AGENT_ID>/tools`, `/app/integrations`.
- `reason` — a short, user-safe line shown to the user as a toast ("Opening the Configure page"). Plain language; no internal ids.
- Returns `{"delivered": true, "path": "..."}`. `delivered:true` means the frame reached the app's open console. If the user has no console tab open, nothing moves — say so plainly if it matters.

Rules:
- Navigate to **confirm** an action, not to yank the user around. After you do something ("added the doc", "saved the draft"), take them to where they can see it and say so in one line — this replaces reciting the path.
- Only real, routable `/app/…` paths. Never a coming-soon surface (`read_layout` flags these `coming_soon`), never an external URL, never a domain.
- One purposeful move per action — don't navigate every message.

## Read a page's layout

`aramb_mcp.ui_read_layout` returns the structured layout of a console screen: its title, purpose, and the actions on it — label, kind, on-screen location, where each routes or what it does, and when it's enabled. Use it to guide the user to a control you can't navigate to directly (a button, a tab, a toggle).

```bash
# One screen — by path or by short key
npx mcporter call aramb_mcp.ui_read_layout project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" screen="/app/agents/<AGENT_ID>/configure"
npx mcporter call aramb_mcp.ui_read_layout project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>" screen="agent.configure"

# Omit screen → the full index of screens (key, path, title, group)
npx mcporter call aramb_mcp.ui_read_layout project_id="<PROJECT_ID>" application_id="<APPLICATION_ID>"
```

- `screen` — a console path (`/app/agents/<AGENT_ID>/configure`) OR a short key (`agent.configure`). Concrete ids in the path are fine — they are normalized for lookup. Omit it to get the index of every screen.
- Returns a page layout for one screen, `{"screens":[...]}` for the index, or `{"error":"unknown_screen","valid_keys":[...]}` when the key/path isn't recognized.
- Each action carries `label`, `kind` (button/link/tab/toggle/input), `location` (top-bar-right, left-nav, right-rail, page-body, dialog, drawer), and optionally `navigates_to`, `effect`, `enabled_when`, `coming_soon`.

Use it to say the precise thing: "Hit **Publish** (top-right) — it lights up once the draft has unpublished changes," or "Open the **Tools → Workflows** tab to set when the workflow fires." When an action has a `navigates_to`, prefer `navigate` to just take them there.

## Using the two together

- Reachable by URL → `navigate` them there and name the screen.
- A click with no direct route (Publish, a tab, a dialog) → `read_layout` the current screen, then name the exact label + location.
- "Where do I…" → `read_layout` (index or the specific screen) to point them, then `navigate` if it helps.

## Confidentiality
- `project_id` / `application_id` are tool arguments only — never repeat them to the user.
- Speak in screen names and button labels, not paths or ids. The user watches the view change; they don't need the URL.
