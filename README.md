# aramb-skills

Markdown-based skill definitions for LLM task execution in the aramb orchestrator system.

## Overview

This repository contains skill definitions that control how LLM agents execute specific types of tasks. Each skill is a `SKILL.md` file that provides:

- **Specialized workflows** - Multi-step procedures for specific domains
- **Domain expertise** - Technology-specific knowledge, patterns, best practices
- **Quality standards** - Validation rules and output requirements
- **Bundled resources** - Scripts, references, and templates for complex tasks

Agents load these skills and use them as system prompts when executing tasks assigned by the orchestrator.

---

## Directory Structure

```
aramb-skills/
├── README.md
├── frontend-planner/
│   └── SKILL.md
├── frontend-development/
│   └── SKILL.md
├── frontend-testing/
│   └── SKILL.md
├── frontend-critique/
│   └── SKILL.md
├── backend-planner/
│   └── SKILL.md
├── backend-development/
│   └── SKILL.md
├── backend-testing/
│   └── SKILL.md
├── backend-critique/
│   └── SKILL.md
└── skill-creator/
    └── SKILL.md
```

**Convention**: Each skill has its own directory with a `SKILL.md` file. Directory name must match the `name` field in frontmatter.

---

## SKILL.md Format

```markdown
---
name: skill-name
description: What this skill does and when to use it.
category: development
tags: [domain, technology, capability]
license: MIT
---

# Skill Title

## Responsibilities
- What the agent should do

## Constraints
- What the agent must NOT do

## Workflow
1. Step-by-step process

## Patterns
Code examples and best practices

## Validation
How to verify success
```

### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier (lowercase, hyphenated). Must match directory name. |
| `description` | Yes | What the skill does AND when to use it. Primary trigger mechanism. |
| `category` | Yes | Skill type: `planner`, `development`, `testing`, `critique`, `devops`, `data`, `meta` |
| `tags` | Yes | Array of domain, technology, and capability tags |
| `license` | Yes | License type (e.g., `MIT`, `Apache-2.0`) |

### Category Convention

| Category | Description | Examples |
|----------|-------------|----------|
| `planner` | Analyzes requirements and creates task plans | frontend-planner, backend-planner |
| `development` | Writes implementation code | frontend-development, backend-development |
| `testing` | Writes tests | frontend-testing, backend-testing |
| `critique` | Validates and reviews work | frontend-critique, backend-critique |
| `devops` | Infrastructure and deployment | docker-deploy, k8s-deploy |
| `data` | Data processing and analysis | data-pipeline, analytics |
| `meta` | Skills about skills | skill-creator |

### Tags Convention

- **Domain tags**: `frontend`, `backend`, `fullstack`, `api`, `database`, `infrastructure`
- **Technology tags**: `react`, `vue`, `typescript`, `golang`, `python`, `postgres`, `docker`
- **Capability tags**: `authentication`, `payments`, `realtime`, `testing`, `validation`

---

## Bundled Resources (Optional)

Skills can include additional resources:

```
skill-name/
├── SKILL.md              # Required: Frontmatter + instructions
├── scripts/              # Optional: Executable code
├── references/           # Optional: Documentation loaded as needed
└── assets/               # Optional: Templates, configs, examples
```

- **scripts/**: Code for deterministic, repeatable operations
- **references/**: Documentation loaded into context as needed
- **assets/**: Templates and files used in output (not loaded into context)

---

## Adding a New Skill

### Quick Start

```bash
mkdir my-skill
touch my-skill/SKILL.md
```

### Minimal SKILL.md

```markdown
---
name: my-skill
description: Brief description of what this skill does and when to use it.
category: development
tags: [relevant, tags, here]
license: MIT
---

# My Skill

## Responsibilities
- Primary responsibility
- Secondary responsibility

## Constraints
- What to avoid

## Workflow
1. First step
2. Second step

## Validation
- Success criteria
```

### Detailed Guidance

For comprehensive skill creation guidance, see [skill-creator/SKILL.md](skill-creator/SKILL.md).

---

## Integration with Agents

### How Skills Work

```
User Prompt → Planning Skill → Task Plan → [skill-1, skill-2, ...] → Execution → Critique
```

1. **Planning skill** analyzes the user prompt and generates a task plan
2. Each task is assigned a `skill_id` (e.g., `frontend-development`)
3. **aramb-agents** loads the corresponding `SKILL.md` from the skills registry
4. The skill's instructions are injected as the system prompt for the LLM
5. **Critique skill** validates the output against acceptance criteria

### Skill Loading

```python
# In aramb-agents
skill = skill_registry.get_skill("frontend-development")
# Loads /skills/frontend-development/SKILL.md
# Parses frontmatter + body
# Injects body as system prompt
```

### Updating Skills

Pull latest changes and restart agents:

```bash
cd aramb-skills
git pull origin main
# Restart agent workers
```

---

## Best Practices

1. **Keep it concise** - The context window is shared with conversation history and tool outputs
2. **Be specific about triggers** - The description should clearly indicate when to use the skill
3. **Use imperative form** - "Create", "Implement", "Validate" (not "You should create")
4. **Include concrete examples** - Show code snippets for common patterns
5. **Define validation criteria** - How does the agent know it succeeded?
6. **Stay under 500 lines** - Split large content into reference files

---

## Document Metadata

- **Version**: 2.0
- **Date**: 2025-01-23
- **Status**: Reference Documentation
- **Related**: aramb-agents (consumer), aramb-orchestrator (assigner)
