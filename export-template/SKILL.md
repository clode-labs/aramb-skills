---
name: export-template
description: >
  Turn a published agent into a reusable template for OTHER orgs. You have ONE
  job: read the published agent and identify which literal values are specific to
  THIS org, expressed as a variabilization_map ({"Aramb":"{{company_name}}", …})
  plus one wizard question per placeholder — then call aramb_agents.export_template
  with them. READ-ONLY: you never edit the agent or its workflow. The MCP call does
  all the packaging (copies the published snapshot, applies your map to the copy,
  attaches the wizard, freezes it). The live agent is never touched.
---

# Export as a template

Publishing makes an agent live for YOUR org. Exporting hands it to strangers: another
company clicks "use this template" and gets their own copy. Your **only** job is to
say which values are org-specific so brahmi can turn them into fill-in-the-blank
`{{placeholders}}` in the exported copy.

**You do exactly one thing: identify the variables and submit them. You never edit
the agent or the workflow.** `aramb_agents.export_template` does everything else — it
copies the published snapshot (persona + bound workflow + sub-agent specs + chosen KB
docs), applies your map to the COPY only, attaches your wizard, and freezes it. The
live agent stays exactly as the user built and tested it.

If you notice something broken or missing (a malformed workflow, a sub-agent spec that
isn't declared, a secret pasted into a prompt) — **tell the user in plain language and
stop.** That is a defect to fix in the agent separately; it is NOT yours to fix here,
and NEVER a reason to call `aramb_agents.update` / `aramb_workflows.update`.

## Read (the published version — what end-users actually get)

Reads only, no writes:

- `aramb_agents.get` — persona: `name`, `system_prompt`, `soul`, `agents_doc`, `greeting`.
- `aramb_workflows.get` for each bound workflow — node `prompt` / `acceptance_criteria`
  and each `agent_specs` entry's `identity` / `soul` / `agentsDoc`.
- `aramb_agents.kb_list` — decide which docs travel (`include_knowledge_doc_ids`).

## The one job — find the org-specific values

Pick out every literal that is true for THIS org but wrong for the next, and map each
to a `{{placeholder}}`:

- Company / product / brand names; the specific customers, competitors, or accounts
  named; positioning / value-prop specifics.
- Concrete destinations: emails, Slack channels, domains, repo names, doc URLs.
- Any number, region, or policy that is this org's choice, not a universal law.

**Leave the craft alone** — the role, the reasoning, the quality bar, the workflow
structure, the generic instructions that make it good. You are extracting the org, not
gutting the method. Leave **structural identifiers** alone too (sub-agent role names,
each node's `assigned_agent`) — brahmi never variabilizes those, so references keep
resolving.

**Don't ship what isn't yours to share:** secrets / API keys (flag to the user, never
ship — a secret in a prompt is a defect regardless of export), PII, real internal
endpoints (map them to a placeholder), confidential KB docs (leave out of
`include_knowledge_doc_ids`). Test: "would I hand this to a competitor?" If no, map it
or drop it.

## Submit — one call, zero edits

Build two things and pass them to `aramb_agents.export_template`:

1. **`variabilization_map`** — `{literal: "{{placeholder}}"}`. Same placeholder for the
   same concept everywhere. Use the full specific literal (the whole proper noun /
   channel / email / URL) so it never matches inside an unrelated word. Every value is a
   single `{{token}}`.
2. **`wizard`** — one question per DISTINCT placeholder: `{key, label, required,
   [description]}`. Every placeholder has a question; every question maps to a
   placeholder. That pairing is what stops a template shipping the author's org.

```bash
npx mcporter call aramb_agents.export_template \
  agent_id="<AGENT_ID>" slug="<slug>" name="<Name>" description="<one-liner>" \
  category="<category>" tags="a,b" publish_first=true \
  variabilization_map='{"Aramb":"{{company_name}}","ElevenLabs":"{{competitors}}"}' \
  wizard='[{"key":"company_name","label":"What'\''s your company called?","required":true}]' \
  include_knowledge_doc_ids="<DOC_ID_1>"
```

`publish_first=true` freezes the current published snapshot, then exports it with your
map applied to the template envelope only. Re-exporting refreshes the living template in
place.

## Rules

- **Never edit the agent or the workflow — ever.** No `aramb_agents.update` /
  `aramb_workflows.update`, not to insert placeholders, not to "organize", not to "fix"
  anything. The `variabilization_map` + `wizard` are the ONLY output you produce. A
  missing spec or broken workflow → tell the user and stop.
- Every placeholder in the map has a wizard question, and every question has a
  placeholder.
- Never ship a secret, PII, a real internal endpoint, or a private KB doc — map it or
  leave it out; when unsure, leave it out.
- Export is outward and irreversible — confirm the slug/name and the KB opt-in with the
  user before the call.
- Report findings in plain, user-safe language — name the concern, never leak ids,
  tokens, or internal service names.
