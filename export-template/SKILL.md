---
name: export-template
description: >
  Package an agent as a reusable template for OTHER orgs before calling
  aramb_agents.export_template. NON-DESTRUCTIVE: you never rewrite the live
  agent. Three passes, in order: (1) ORGANIZE — read the whole agent and verify
  nothing is dropped or unauthored; (2) PARAMETRIZE — find every value specific
  to THIS org and build a variabilization MAP ({"Aramb":"{{company_name}}", …})
  plus one wizard question per placeholder, WITHOUT editing the agent; (3)
  DANGER-SCAN — screen for anything unsafe to hand a stranger (secrets, internal
  endpoints, PII, private data). Then export once, passing the map + wizard;
  brahmi applies them to the exported template only.
---

# Export as a template — reusable, safe, complete, and NON-DESTRUCTIVE

A published agent is tuned for the org that built it. A **template** is that
agent handed to strangers: another company clicks "use this template" and gets
their own copy. So an export is a translation, not a save.

The one rule that governs everything below: **you do not modify the user's
agent.** The old approach wrote `{{placeholders}}` back into the live agent via
`aramb_agents.update` / `aramb_workflows.update` — that polluted the user's
working agent (it would literally say `{{company_name}}` instead of "Aramb") and
was so long a tool-chain it ran out of time before exporting. Never do that.

Instead you **ORGANIZE** the agent, **describe** how to parametrize it as a
`variabilization_map` + `wizard`, and hand both to `aramb_agents.export_template`.
brahmi applies the map to the **exported template envelope only** — the live agent
stays exactly as the user built and tested it. That is the whole point of this
skill: the exported template is reusable and safe, and the user's agent is
untouched.

## First, read the WHOLE agent (read-only)

You cannot organize, parametrize, or vet what you haven't read. Gather every
layer — reads only, no writes:

1. `aramb_agents.get` → the persona: `name`, `system_prompt`, `soul`,
   `agents_doc`, `greeting`.
2. For every workflow bound to the agent, `aramb_workflows.get` → each node's
   `name` / `prompt` / `acceptance_criteria`, and every `agent_specs` entry's
   `identity` / `soul` / `agentsDoc`.
3. `aramb_agents.kb_list` → the Knowledge Base docs (decide which, if any,
   travel via `include_knowledge_doc_ids`).

Hold the full picture before you describe a single change.

## Pass 1 — ORGANIZE (the nothing-dropped pass)

Confirm the agent is coherent and complete so the export carries everything —
you are auditing, not editing.

- **Main persona** — `system_prompt` present; `soul` and `agents_doc` authored if
  the agent's behavior depends on them (a domain agent usually needs both). If
  they're empty because the agent leans on the platform default, confirm that's
  deliberate — don't ship an accidental blank.
- **Sub-agents — the one that silently breaks.** For every workflow, list the
  agents its nodes reference in `assigned_agent`, then confirm EACH one is a
  fully-authored entry in that workflow's `agent_specs` — real `identity`, `soul`,
  `agentsDoc`. A node whose `assigned_agent` names an agent NOT declared in
  `agent_specs` collapses onto the main agent on import and the multi-agent design
  is lost. If a spec is genuinely missing, that is the ONE case where you fix the
  agent — author the spec with `aramb_workflows.update` so the design survives —
  because a missing spec is a defect in the agent itself, not a template concern.
  (Adding `{{placeholders}}` is NEVER such a fix — that is Pass 2, envelope-only.)
- **Workflow graph** — every node has a stable id; every edge's source/target
  reference real nodes; the node→agent references resolve.
- **Toolkits** — every toolkit a node needs is declared on that node.

## Pass 2 — PARAMETRIZE (the reusability pass — describe, don't rewrite)

Find every value that is true for THIS org but wrong for the next, and record it
in a **variabilization map** you build IN YOUR HEAD / in the call — a mapping of
each literal value to the `{{placeholder}}` it should become. You do NOT write
these placeholders into the agent.

**What is variable** (map it):

- Company / product / brand name ("Aramb", "the marketplace").
- The specific customers, competitors, or accounts named ("ElevenLabs",
  "Acme Corp").
- Value proposition / positioning / what-we-sell specifics.
- Concrete destinations: email addresses, Slack channels, PagerDuty services,
  domains, repo names, doc URLs the agent points at.
- Any number, region, or policy that is this org's choice, not a universal law.

**What is NOT variable** (leave it): the agent's *method* — its role, its
reasoning, its quality bar, its workflow structure, the generic instructions that
make it good at the job. You are extracting the org, not gutting the craft. Also
leave **structural identifiers** alone — the sub-agent role names and each node's
`assigned_agent` — brahmi never variabilizes those, so node→agent references keep
resolving.

**How — two arguments, zero mutations:**

1. **`variabilization_map`** — an object mapping each org-specific LITERAL value to
   its `{{placeholder}}`. Use the SAME placeholder for the same concept
   everywhere (one `{{company_name}}`, not three spellings). brahmi replaces each
   literal across the persona (`name`, `system_prompt`, `soul`, `agents_doc`,
   `greeting`), every node (`name`, `prompt`, `acceptance_criteria`), and every
   sub-agent spec (`identity`, `soul`, `agentsDoc`) — in the EXPORTED TEMPLATE
   ONLY.

   ```
   variabilization_map={
     "Aramb": "{{company_name}}",
     "ElevenLabs": "{{competitors}}",
     "#competitor-watch": "{{alert_channel}}"
   }
   ```

2. **`wizard`** — one question per DISTINCT placeholder so the importer supplies
   their own value: `key` (the placeholder name without braces), `label`,
   `required`, optional `description`.

   ```
   wizard=[
     {"key":"company_name","label":"What's your company called?","required":true},
     {"key":"competitors","label":"Which competitors should it watch?","required":true},
     {"key":"alert_channel","label":"Where should alerts go (Slack channel)?","required":false}
   ]
   ```

The contract: **every placeholder in the map has a matching wizard question, and
every wizard question maps to a placeholder in the map.** A placeholder with no
question can never be filled; a question with no placeholder is dead. This pairing
is what stops a template shipping the author's org hard-coded.

**Use substring-safe literals.** brahmi replaces each literal by plain substring
match, so a short or common literal will match INSIDE unrelated words —
`"Meta" → "{{competitors}}"` would corrupt "Metadata" into "{{competitors}}data".
Map the most specific form that identifies the org value (the full proper noun,
the whole channel/email/URL), not a short fragment of it. If a value only appears
as part of a longer word, leave it — over-variabilizing corrupts the template's
prose. Every map value must be a single `{{placeholder}}` token (brahmi rejects a
bare, unbraced value — the importer could never fill it).

## Pass 3 — DANGER-SCAN (the leakage pass)

Export is a different threat from publish: coherent, benign content that is simply
**not yours to share**. Screen every layer you read for:

- **Secrets** — API keys, tokens, passwords, connection strings, signing secrets
  pasted into a prompt, node, or KB doc. NEVER ship. Flag them to the user; they
  must be removed from the agent (a secret in a prompt is a defect regardless of
  export).
- **Real internal endpoints** — private hostnames, internal service URLs, admin
  panels, non-public API bases. Map them to a `{{placeholder}}` (Pass 2) so the
  importer supplies their own.
- **PII / customer data** — real people's names, emails, phone numbers, account
  IDs, or a customer list baked into content. Map it or leave it out.
- **Private org knowledge** — a KB doc or prompt embedding confidential strategy,
  unreleased plans, or contract terms. Do NOT include it in
  `include_knowledge_doc_ids`; flag it to the user.

Judge by "would I be comfortable handing this to a competitor?" If no, either map
it (Pass 2) or drop it — never ship it.

## Then export — one call

Only after all three passes, export once. brahmi variabilizes the envelope from
your map, attaches your wizard, and freezes the snapshot — your live agent is not
touched:

```bash
npx mcporter call aramb_agents.export_template \
  agent_id="<AGENT_ID>" slug="<slug>" name="<Name>" \
  description="<one-liner>" category="<category>" tags="a,b" \
  publish_first=true \
  variabilization_map='{"Aramb":"{{company_name}}","ElevenLabs":"{{competitors}}"}' \
  wizard='[{"key":"company_name","label":"What'\''s your company called?","required":true}, ...]' \
  include_knowledge_doc_ids="<DOC_ID_1>,<DOC_ID_2>"
```

`publish_first=true` freezes the current published snapshot, then exports it with
your map applied to the template. Re-exporting the same agent refreshes the living
template in place.

## Rules

- **Never rewrite the live agent to variabilize.** No `aramb_agents.update` /
  `aramb_workflows.update` to insert `{{placeholders}}`. Variabilization is
  envelope-only, expressed as `variabilization_map` + `wizard`. The ONLY edit you
  ever make is authoring a genuinely-missing sub-agent spec in Pass 1 — never a
  placeholder.
- **All three passes, in order, every export.** Organize → parametrize →
  danger-scan. Skipping one ships the bug it prevents.
- **Every placeholder in the map has a wizard question; every question has a
  placeholder.** This pairing is the contract that stops a template carrying the
  author's org.
- **Never ship a secret, a real internal endpoint, PII, or private knowledge** —
  map it or leave it out; when unsure, leave it out.
- **Never export a workflow whose nodes reference undeclared sub-agents** — author
  the `agent_specs` first (the one allowed edit), or the multi-agent design
  collapses on import.
- **Export is outward and irreversible** — the template enters the shared catalog
  and cannot be pulled back. Confirm the slug/name and the KB opt-in with the user
  before the call (`aramb-agents` skill → export section).
- **Surface findings in plain, user-safe language** (SOUL.md → Confidentiality) —
  name the content concern, never leak ids, tokens, or internal service names.
