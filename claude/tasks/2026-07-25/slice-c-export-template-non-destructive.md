# Slice C — export-template skill: non-destructive (aramb-skills)

Ref workspace findings: `/Users/siva/workspace/claude/tasks/2026-07-24/local-test-findings.md`
(issues #10 + #11). Companion brahmi doc:
`/Users/siva/workspace/brahmi/claude/tasks/2026-07-25/slice-c-export-template-non-destructive.md`.

## Problem

The old `export-template/SKILL.md` told the Architect to variabilize by **writing
`{{placeholders}}` back into the live agent** via `aramb_agents.update` +
`aramb_workflows.update`. That pollutes the user's working agent AND is a long
tool-call chain that outruns the run `lifetime_cap` before `export_template` is
even reached.

## Fix — organize, don't mutate

Rewrite the skill so the Architect:

1. **ORGANIZES** — reads the whole agent (persona, every workflow node/spec, KB) and
   verifies completeness (nothing dropped, every sub-agent spec authored). Read-only.
2. **IDENTIFIES + MAPS + QUESTIONS** — finds every org-specific value and builds a
   **variabilization map** (`{"Aramb":"{{company_name}}", …}`) in memory, plus one
   `wizard` question per distinct placeholder. **No `aramb_agents.update` /
   `aramb_workflows.update` — the live draft is never rewritten.**
3. **DANGER-SCAN** — screen every layer for secrets / internal endpoints / PII /
   private knowledge; strip or map, never ship.
4. **EXPORT** — one `aramb_agents.export_template` call passing `variabilization_map`
   + `wizard` (+ optional `include_knowledge_doc_ids`). brahmi applies the map to the
   exported envelope only; the live agent stays exactly as the user built and tested it.

## Contract with brahmi

- `variabilization_map`: object of `{ "<literal source value>": "{{placeholder}}" }`.
- `wizard`: one `{key,label,required?,description?}` per distinct placeholder; `key`
  is the placeholder name without braces. Every map placeholder has a wizard question
  and vice-versa.
- brahmi replaces each literal with its placeholder across persona + node prose +
  sub-agent specs in the ENVELOPE, and substitutes the answers back on import.

The skill delivers a MAP + questions; it does not persist any variabilized text.
