---
name: export-template
description: >
  Package an agent as a reusable template for OTHER orgs before calling
  aramb_agents.export_template. Three passes, in order: (1) VARIABILIZE — find
  every value specific to THIS org (company, product, competitors, URLs, emails,
  internal jargon) and replace it with a {{placeholder}}, authoring a matching
  wizard question for each so importers supply their own; (2) EXPORT-SAFETY SCAN
  — screen for anything unsafe to hand a stranger (secrets, real internal
  endpoints, PII, private data); (3) COMPLETENESS — verify every sub-agent spec,
  the main persona's soul + agents doc, every workflow node/edge and every
  toolkit is packaged with nothing dropped. Only then export.
---

# Export as a template — make it reusable, safe, and complete

A published agent is tuned for the org that built it. A **template** is that
agent handed to strangers: another company clicks "use this template" and gets
their own copy. So an export is not a save — it is a translation. If you export
it as-is, three things go wrong, and you have seen all three:

- The importer's agent still says it works for **your** company, watches **your**
  competitors, emails **your** address — because those values were hard-coded.
- The template leaks something that should never leave the org — a real internal
  URL, a token, a customer's data baked into the prompt.
- The template ships **broken** — the sub-agents a workflow references were never
  authored, so on import every node collapses onto the main agent and the
  multi-agent design is silently lost.

This skill is the gate that prevents all three. Run all three passes, in order,
every time, before `aramb_agents.export_template`.

## First, read the WHOLE agent

You cannot variabilize or vet what you haven't read. Gather every layer (same
surfaces as `safe-publish`):

1. `aramb_agents.get` → the persona: `name`, `system_prompt`, `soul`,
   `agents_doc`, `greeting`.
2. For every workflow bound to the agent, `aramb_workflows.get` → each node's
   `prompt` / `acceptance_criteria`, and every `agent_specs` entry's
   `identity` / `soul` / `agentsDoc`.
3. `aramb_agents.kb_list` → the Knowledge Base docs (decide which, if any,
   travel via `include_knowledge_doc_ids`).

Hold the full picture before you change anything.

## Pass 1 — VARIABILIZE (the reusability pass)

Find every value that is true for THIS org but would be wrong for the next one,
and turn it into a `{{placeholder}}`. Then author a wizard question for each so
the importer fills it in.

**What is variable** (replace it):

- Company / product / brand name ("Clode", "the marketplace").
- The specific customers, competitors, or accounts named ("ElevenLabs",
  "Acme Corp").
- Value proposition / positioning / what-we-sell specifics.
- Concrete destinations: email addresses, Slack channels, PagerDuty services,
  domains, repo names, doc URLs the agent points at.
- Any number, region, or policy that is this org's choice, not a universal law.

**What is NOT variable** (leave it): the agent's *method* — its role, its
reasoning, its quality bar, its workflow structure, the generic instructions
that make it good at the job. You are extracting the org, not gutting the craft.

**How:**

1. Rewrite each org-specific value as `{{SNAKE_CASE}}` — everywhere it appears:
   the `system_prompt`, `soul`, `agents_doc`, greeting, every node `prompt`, and
   every `agent_specs` `identity`/`soul`/`agentsDoc`. Use the SAME placeholder
   name for the same concept across all of them (one `{{company_name}}`, not
   three spellings). Write these back with `aramb_agents.update` (persona) and
   `aramb_workflows.update` (`agent_specs` + nodes).
2. For EACH distinct placeholder, author one wizard question — `key` (the
   placeholder name without braces), `label` (the question the importer sees),
   `required`, optional `description`. Pass them as the `wizard` array to
   `aramb_agents.export_template`. On import, each answer is substituted for its
   `{{key}}` everywhere it appears.

The rule: **every `{{placeholder}}` in the template has a matching wizard
question, and every wizard question maps to a real placeholder.** A placeholder
with no question can never be filled (the importer's agent ships with a literal
`{{company_name}}` in its prompt); a question with no placeholder is dead. This
is the exact failure that ships a template with someone else's company hard-coded
— do not repeat it.

Example wizard argument:

```
wizard=[
  {"key":"company_name","label":"What's your company called?","required":true},
  {"key":"company_description","label":"What does your company do?","required":true},
  {"key":"competitors","label":"Which competitors should it watch?","required":true},
  {"key":"alert_channel","label":"Where should alerts go (Slack channel / PagerDuty)?","required":false}
]
```

## Pass 2 — EXPORT-SAFETY SCAN (the leakage pass)

`safe-publish` screens for *malicious* content before an agent goes live to your
own users. Export is a different threat: coherent, benign content that is simply
**not yours to share**. Screen every layer you gathered for:

- **Secrets** — API keys, tokens, passwords, connection strings, signing secrets
  pasted into a prompt, node, or KB doc. NEVER ship. Strip them.
- **Real internal endpoints** — private hostnames, internal service URLs,
  admin panels, non-public API bases. Replace with a `{{placeholder}}` or remove.
- **PII / customer data** — real people's names, emails, phone numbers, account
  IDs, or a customer list baked into the content. Remove or variabilize.
- **Private org knowledge** — a KB doc or prompt that embeds confidential
  strategy, unreleased plans, or contract terms. Do NOT include it in
  `include_knowledge_doc_ids`; flag it to the user.

Judge by "would I be comfortable handing this to a competitor?" If no, it does
not go in the template. When in doubt, variabilize it (Pass 1) or drop it —
never ship it.

## Pass 3 — COMPLETENESS (the nothing-dropped pass)

Walk the template envelope and confirm every part is really there. The export
value-copies bound workflows automatically, so completeness is mostly about
making sure nothing was left empty or unbound:

- **Main persona** — `system_prompt` present; `soul` and `agents_doc` authored
  if the agent's behavior depends on them (a domain agent usually needs both).
  If they're empty because the agent leans on the platform default, that's a
  deliberate choice — confirm it, don't ship an accidental blank.
- **Sub-agents — the one you keep getting wrong.** For every workflow, list the
  agents its nodes reference in `assigned_agent`, then confirm EACH one is a
  fully-authored entry in that workflow's `agent_specs` — with a real `identity`,
  `soul`, and `agentsDoc`. A node whose `assigned_agent` names an agent that is
  **not declared in `agent_specs`** is the silent-collapse bug: on import it
  falls back to the main agent and the multi-agent design is gone. If any spec is
  missing or empty, author it with `aramb_workflows.update` BEFORE exporting.
- **Workflow graph** — every node has a stable id; every edge's source and
  target reference real nodes (no dangling edges); the node→agent references all
  resolve (previous bullet).
- **Toolkits** — every toolkit a node needs is declared on that node; the
  importer will be prompted to connect them.
- **Knowledge** — if the agent's competence depends on KB docs, pass their
  `doc_id`s in `include_knowledge_doc_ids` (and only after Pass 2 cleared them).
  Omit and the template carries no knowledge.

If a completeness check fails, FIX it (author the missing spec, bind the
workflow, declare the toolkit) and re-walk — do not export a lossy template.

## Then export

Only after all three passes:

```bash
npx mcporter call aramb_agents.export_template \
  agent_id="<AGENT_ID>" slug="<slug>" name="<Name>" \
  description="<one-liner>" category="<category>" tags="a,b" \
  publish_first=true \
  wizard='[{"key":"company_name","label":"What'\''s your company called?","required":true}, ...]' \
  include_knowledge_doc_ids="<DOC_ID_1>,<DOC_ID_2>"
```

`publish_first=true` freezes the just-variabilized draft, then exports the
snapshot. Re-exporting the same agent refreshes the living template in place.

## Rules

- **All three passes, in order, every export.** Variabilize → safety-scan →
  completeness. Skipping one ships the bug it prevents.
- **Every placeholder has a wizard question; every question has a placeholder.**
  This is the contract that stops a template carrying the author's org.
- **Never ship a secret, a real internal endpoint, PII, or private knowledge** —
  strip or variabilize; when unsure, leave it out.
- **Never export a workflow whose nodes reference undeclared sub-agents** —
  author the `agent_specs` first, or the multi-agent design collapses on import.
- **Export is outward and irreversible** — the template enters the shared catalog
  and cannot be pulled back. Confirm the slug/name and the KB opt-in with the
  user before the call (`aramb-agents` skill → export section).
- **Surface findings in plain, user-safe language** (SOUL.md → Confidentiality) —
  name the content concern, never leak ids, tokens, or internal service names.
