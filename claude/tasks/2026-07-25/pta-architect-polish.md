# aramb-skills — Slice D #4: document main-persona soul/agents_doc authoring

Workspace design: `/Users/siva/workspace/claude/tasks/2026-07-25/pta-architect-polish/DESIGN.md`
Branch: `feat/pta-architect-polish` off `feat/publish-through-architect`.
File: `aramb-agents/SKILL.md`. (Docs only — no build.)

## Problem (findings #4)

The brahmi change added `soul` + `agents_doc` to `aramb_agents.create`/`update`,
but the aramb-agents skill never mentions them, so the Architect left them empty
(`soul=false, agents_doc=false`) on the main persona while authoring souls on
sub-agents (whose skill documents them).

## Change

Document the two fields on create/update and instruct authoring them for a
domain agent:

- `soul` (string) — the agent's SOUL.md: personality / behavioural voice.
  Empty ⇒ platform default (domain-neutral).
- `agents_doc` (string) — the agent's AGENTS.md: operational playbook (how it
  works). Empty ⇒ platform default.

Snake_case on the main persona — distinct from the sub-agent `agent_specs`
shape which uses camelCase `soul`/`agentsDoc`. For a real domain agent, author
a soul (and an agents doc when its operating flow is non-trivial), not just the
system prompt.
