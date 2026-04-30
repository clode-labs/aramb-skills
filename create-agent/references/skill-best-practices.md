# Skill Best Practices

Condensed guidelines from the skill-creator skill. Use when creating skills for new agents.

## Structure

```
skill-name/
├── SKILL.md              (required)
├── scripts/              (optional — deterministic/reusable code)
├── references/           (optional — loaded into context as needed)
└── assets/               (optional — used in output, not loaded into context)
```

## SKILL.md Rules

### Frontmatter (YAML, required)

```yaml
---
name: skill-name
description: >
  What the skill does AND when to trigger it. This is the primary
  triggering mechanism — be comprehensive. Include "Use when:" and
  "NOT for:" patterns.
---
```

Only `name` and `description` in frontmatter. Nothing else.

### Body

- **Imperative form** — "Run the tests" not "You should run the tests"
- **Under 500 lines** — split into references if approaching this limit
- **Only non-obvious knowledge** — the agent is already smart; add what it can't infer
- **No boilerplate docs** — no README.md, CHANGELOG.md, INSTALLATION_GUIDE.md

## Core Principles

### Conciseness
Context window is shared. Every token must earn its place. Challenge each paragraph: "Does the agent really need this?"

### Degrees of Freedom
- **High freedom** (text guidance): multiple valid approaches, context-dependent
- **Medium freedom** (pseudocode/parameterized scripts): preferred pattern exists
- **Low freedom** (exact scripts): fragile operations, consistency critical

### Progressive Disclosure
1. **Metadata** (~100 words) — always in context (name + description)
2. **SKILL.md body** (<5k words) — loaded when skill triggers
3. **References/scripts** — loaded only when needed

Reference files from SKILL.md with clear "when to read" guidance.

## Naming

- Lowercase letters, digits, hyphens only
- Short, verb-led phrases: `run-tests`, `deploy-service`, `check-health`
- Namespace by tool when helpful: `gh-review-pr`, `k8s-deploy`
- Folder name = skill name

## Common Patterns

### High-level guide with references
Keep core workflow in SKILL.md. Move variant-specific details to `references/`:

```markdown
## Deploying
Core deploy steps here.
For AWS specifics: see references/aws.md
For GCP specifics: see references/gcp.md
```

### Conditional details
Basic in SKILL.md, advanced in separate files:

```markdown
## Basic Usage
Simple instructions here.

**For advanced configuration**: see references/advanced-config.md
```

## Quality Checklist

- [ ] Frontmatter has `name` and `description` (description includes triggers)
- [ ] Body is under 500 lines
- [ ] Instructions use imperative form
- [ ] No unnecessary files (README, CHANGELOG, etc.)
- [ ] References are one level deep from SKILL.md
- [ ] Long reference files (>100 lines) have a table of contents
- [ ] Scripts are tested before inclusion
