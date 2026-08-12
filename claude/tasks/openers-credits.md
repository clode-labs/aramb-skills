# [aramb-skills] Teach the architect conversation starters and the new opener model

**Slice:** clode-labs/aramb-skills#123 · **Epic:** clode-labs/aramb-epics#50
**Workspace design doc:** `$WORKSPACE_HOME/claude/tasks/openers-credits/openers-credits-invariants.md`
**Branch:** `feat/openers-credits` (already checked out in this worktree)

You are the aramb-skills implementer. This is a documentation/guidance slice — no code.

---

## Why

The architect drafts agents. It has never known `conversation_starters` exists, because
`aramb-agents/SKILL.md` (~line 16) lists the versioned-config fields as *"(name, system
prompt, greeting, mode, skills, disabled tools)"* — starters are missing. So every
architect-drafted agent ships with no starters, and its users get a greeting that costs a
model call instead of pills that cost nothing.

**The dependency is already satisfied:** `conversation_starters` is now a real field on the
`aramb_agents` MCP tool (create + update, tri-state, validated) in the brahmi worktree. The
schema advertises it. So guidance you write here is immediately actionable by the architect.

Skill CONTENT reaches agents at RUNTIME — no image rebake is needed for this to take effect.

## Scope

### 1. Add `conversation_starters` to the field list

`aramb-agents/SKILL.md` ~line 16. Keep the existing prose style.

### 2. Document the opener model, so the architect designs to it

- **Starters are the PREFERRED opener.** 3–6 short, concrete, task-shaped examples of what to
  ask this agent. The console's own hint is *"Add at least 3 to guide new conversations."*
  Caps: **max 6, each ≤200 chars** — state the caps so the architect never proposes a payload
  the tool rejects.
- **The greeting is a canned literal rendered by the chat surface.** It is not a prompt
  instruction and not model output. Do not write greetings that assume the model can adapt
  them to context ("Welcome back, I see you were working on…" is now impossible — the surface
  renders a fixed string).
- **Neither an opener nor a resume costs a model call.** Say this explicitly; it is the whole
  point of the change.
- Starters and greeting are mutually exclusive at render time: when starters exist the surface
  shows pills and **no** greeting text. So an agent with good starters does not need a clever
  greeting.

### 3. Make proposing starters part of the drafting flow

When the architect creates or updates a **product** agent it should propose starters derived
from the agent's actual job, and confirm them with the user the same way it settles the system
prompt. Worked example for a spending assistant:

- *"Summarise my August spending"*
- *"How much did I spend on Food & Dining?"*
- *"What did I spend at Amazon last month?"*

Concrete and task-shaped — not *"Ask me anything"*, not *"Hello"*.

### 4. Note the mcporter array-argument form

Same rule the skill already documents for `skills` / `disabled_tools`:

```
conversation_starters='["Summarise my August spending","How much did I spend on Food & Dining?"]'
```

---

## Out of scope

- The MCP tool change itself (already done in the brahmi worktree)
- Rendering (console slice)

## Verification

There is no unit-test harness for skills, and the owner has dialed out behavioural/e2e
validation for this task. So verify by **inspection against the live tool schema** and state
in your commit message that you did:

1. Every field your updated list names must actually exist in the `aramb_agents` tool schema.
   Check it against `internal/mcp/tools.go` → `arambAgentsPersonaProperties()` in the brahmi
   worktree at `$WORKSPACE_HOME/.lt-worktrees/openers-credits/brahmi`. Read-only — do not edit
   brahmi from this session.
2. The caps you document (max 6, ≤200 chars) must match
   `models.ValidatePersonaConversationStarters` in that same worktree.

A mismatch here is the failure mode this slice exists to prevent — the skill telling the
architect about a field the tool does not accept, or caps that differ from what is enforced.

## Definition of done

1. Field list includes `conversation_starters`.
2. Opener model documented: starters preferred, greeting is a surface-rendered literal,
   neither costs a model call, caps stated.
3. Drafting flow proposes starters for product agents, with concrete examples.
4. mcporter array form noted.
5. Field names + caps verified against the brahmi worktree; say so in the commit message.
6. Commit on `feat/openers-credits` in THIS worktree. Do not push or open a PR — the
   orchestrator does that after the audit pass.
