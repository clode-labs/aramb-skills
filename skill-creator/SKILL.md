---
name: skill-creator
description: Guide for creating effective aramb skills. Use this skill when users want to create a new skill or update an existing skill that extends agent capabilities with specialized knowledge, workflows, or domain expertise for the aramb orchestration system.
category: meta
tags: [skill-creation, authoring, documentation, workflow]
license: MIT
---

# Aramb Skill Creator

This skill provides guidance for creating effective skills in the aramb ecosystem.

## About Aramb Skills

Skills are modular, self-contained packages that extend agent capabilities by providing specialized knowledge, workflows, and domain expertise. They transform a general-purpose LLM agent into a specialized agent equipped with procedural knowledge for specific tasks.

### How Skills Work in Aramb

```
User Prompt → Planning Skill → Task Plan → [skill-1, skill-2, ...] → Execution → Critique
```

1. **Planning skill** analyzes the user prompt and generates a task plan
2. Each task is assigned a `skill_id` (e.g., `frontend`, `backend`)
3. **aramb-agents** loads the corresponding `SKILL.md` from the skills registry
4. The skill's instructions are injected as the system prompt for the LLM
5. **Critique skill** validates the output against acceptance criteria

### What Skills Provide

- **Specialized workflows** - Multi-step procedures for specific domains
- **Domain expertise** - Technology-specific knowledge, patterns, best practices
- **Quality standards** - Validation rules and output requirements
- **Bundled resources** - Scripts, references, and templates for complex tasks

## Core Principles

### Concise is Key

The context window is shared with conversation history, tool outputs, and user requests. Only add context the model doesn't already have.

**Default assumption: The model is already smart.** Challenge each piece of information:
- "Does the model really need this explanation?"
- "Does this paragraph justify its token cost?"

Prefer concise examples over verbose explanations.

### Match Freedom to Task Fragility

**High freedom** (text-based instructions): When multiple approaches are valid and context determines the best choice.

**Medium freedom** (patterns with parameters): When a preferred pattern exists but some variation is acceptable.

**Low freedom** (specific scripts/commands): When operations are fragile, consistency is critical, or exact sequences matter.

## Skill Structure

Every skill consists of a required `SKILL.md` file and optional bundled resources:

```
skill-name/
├── SKILL.md              # Required: Frontmatter + instructions
├── scripts/              # Optional: Executable code
├── references/           # Optional: Documentation loaded as needed
└── assets/               # Optional: Templates, icons, etc.
```

### SKILL.md Format

```markdown
---
name: skill-name
description: What this skill does and when to use it. Be specific about triggers.
license: MIT
---

# Skill Title

Instructions for the agent...
```

#### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier (lowercase, hyphenated). Must match directory name. |
| `description` | Yes | What the skill does AND when to use it. This is the primary trigger mechanism. |
| `category` | Yes | Skill type - what the skill does. See Category Convention below. |
| `tags` | Yes | Array of domain, technology, and capability tags. See Tags Convention below. |
| `license` | Yes | License type (e.g., `MIT`, `Apache-2.0`) |

#### Category Convention

Category describes the **type of work** the skill performs. Use these categories:

| Category | Description | Examples |
|----------|-------------|----------|
| `planner` | Analyzes requirements and creates task plans | frontend-planner, backend-planner |
| `development` | Writes implementation code | frontend-development, backend-development |
| `testing` | Writes tests | frontend-testing, backend-testing |
| `critique` | Validates and reviews work | frontend-critique, backend-critique |
| `devops` | Infrastructure and deployment | docker-deploy, k8s-deploy |
| `data` | Data processing and analysis | data-pipeline, analytics |
| `meta` | Skills about skills | skill-creator |

#### Tags Convention

Tags describe the **domain**, **technologies**, and **capabilities**. Use multiple tags:

- **Domain tags**: `frontend`, `backend`, `fullstack`, `api`, `database`, `infrastructure`
- **Technology tags**: `react`, `vue`, `typescript`, `golang`, `python`, `postgres`, `docker`
- **Capability tags**: `authentication`, `payments`, `realtime`, `testing`, `validation`

**Example:**
```yaml
name: frontend-development
category: development
tags: [frontend, react, typescript, components, ui, accessibility]
```

Agents search the registry using category (prefix match) and tags (exact match), combined with AND:
- `category=development&tag=frontend` finds frontend development skills
- `category=testing&tag=react` finds React testing skills

#### Body Structure

The markdown body should include:

1. **Role Statement** - Who/what the agent becomes
2. **Responsibilities** - What the agent should do
3. **Constraints** - What the agent must NOT do
4. **Output Requirements** - Expected deliverables
5. **Workflow** - Step-by-step implementation process
6. **Best Practices** - Patterns, examples, anti-patterns
7. **Validation Rules** - How to verify success

### Bundled Resources

#### Scripts (`scripts/`)

Executable code for deterministic, repeatable operations.

```
scripts/
├── validate_output.py    # Validation script
├── generate_boilerplate.sh
└── run_tests.sh
```

**When to include**: Same code rewritten repeatedly, deterministic reliability needed.

#### References (`references/`)

Documentation loaded into context as needed.

```
references/
├── api-schema.md         # API specifications
├── patterns.md           # Design patterns
└── troubleshooting.md    # Common issues
```

**When to include**: Large documentation the model should reference while working.

#### Assets (`assets/`)

Files used in output (not loaded into context).

```
assets/
├── templates/            # Boilerplate code
├── configs/              # Configuration files
└── examples/             # Sample outputs
```

**When to include**: Templates, boilerplate, sample files that get copied or modified.

## Writing Effective Skills

### Description Writing

The description is the **primary trigger mechanism**. Include:

1. What the skill does
2. Specific triggers/contexts for when to use it
3. Example user requests that should trigger this skill

**Good description:**
```yaml
description: Build modern frontend applications using React, Vue, or vanilla JavaScript. Use this skill for creating UI components, pages, forms, and interactive web interfaces with proper styling, accessibility, and responsive design.
```

**Bad description:**
```yaml
description: Frontend development skill.
```

### Instruction Writing Guidelines

1. **Use imperative form**: "Create", "Implement", "Validate" (not "You should create")
2. **Be specific about technologies**: List exact frameworks, libraries, versions
3. **Include concrete examples**: Show code snippets for common patterns
4. **Define validation criteria**: How does the agent know it succeeded?
5. **Avoid redundancy**: Don't explain things the model already knows

### Progressive Disclosure

Keep `SKILL.md` under 500 lines. Split content into reference files when approaching this limit.

**Pattern: High-level guide with references**
```markdown
# Database Migrations

## Quick start
[essential workflow]

## Advanced features
- **Rollbacks**: See [references/rollbacks.md](references/rollbacks.md)
- **Schema validation**: See [references/validation.md](references/validation.md)
```

**Pattern: Domain-specific organization**
```
cloud-deploy/
├── SKILL.md (workflow + provider selection)
└── references/
    ├── aws.md
    ├── gcp.md
    └── azure.md
```

## Skill Creation Process

### Step 1: Understand the Domain

Ask clarifying questions:
- What functionality should this skill support?
- What are concrete examples of how it will be used?
- What would a user say that should trigger this skill?
- What technologies/frameworks are involved?

### Step 2: Plan Reusable Resources

For each example, identify:
- **Scripts**: Code that's rewritten repeatedly
- **References**: Documentation needed during execution
- **Assets**: Templates or files used in output

### Step 3: Create the Skill Directory

```bash
mkdir -p skill-name/{scripts,references,assets}
touch skill-name/SKILL.md
```

### Step 4: Write SKILL.md

1. Start with frontmatter (`name`, `description`, `license`)
2. Write the role statement
3. Define responsibilities and constraints
4. Document the workflow
5. Add best practices with examples
6. Specify validation rules

### Step 5: Test the Skill

1. Use the skill on real tasks
2. Identify struggles or inefficiencies
3. Update instructions based on observed behavior
4. Iterate until the skill performs well

## Integration with Aramb System

### Maker → Checker Pattern

Planners should create tasks in pairs: an implementation task followed by a critique task.

```
[implementation skill] → [critique skill] → [next implementation] → [critique skill]
```

When creating critique tasks, include `preceding_task` in inputs so the critique skill knows what it's validating:

```json
{
  "skill_id": "frontend-critique",
  "inputs": {
    "original_prompt": "User's original request",
    "preceding_task": {
      "task_order": 1,
      "skill_id": "frontend-development",
      "task_name": "Build login form",
      "description": "Create login form component with validation"
    },
    "validation_criteria": {
      "critical": ["Form renders", "Validation works"],
      "expected": ["Accessible", "Responsive"],
      "nice_to_have": []
    }
  }
}
```

The critique skill reads `preceding_task.skill_id` to understand what type of work to validate (development code vs tests vs migrations, etc.) and adapts its validation approach accordingly.

### Adding a New Skill

1. Create skill directory: `aramb-skills/<skill-name>/`
2. Write `SKILL.md` following this guide
3. Update planning skill to include new `skill_id` in its output schema
4. Register skill in aramb-agents' skill registry

### Skill Loading Flow

```
aramb-agents polls task queue
    ↓
Receives task with skill_id="frontend"
    ↓
SkillRegistry.get_skill("frontend")
    ↓
Loads /skills/frontend/SKILL.md
    ↓
Parses frontmatter + body
    ↓
Injects body as system prompt for LLM
    ↓
LLM executes task with skill context
```

## Example: Creating a "testing" Skill

### Step 1: Understand the Domain

Testing skill should handle:
- Unit tests (Jest, Vitest, pytest)
- Integration tests
- E2E tests (Playwright, Cypress)
- Test coverage requirements

### Step 2: Plan Resources

- `references/frameworks.md` - Framework-specific patterns
- `scripts/run_coverage.sh` - Coverage reporting script

### Step 3: Write SKILL.md

```markdown
---
name: testing
description: Write comprehensive tests for frontend and backend code. Use this skill for unit tests, integration tests, and e2e tests using Jest, Vitest, pytest, Playwright, or Cypress.
license: MIT
---

# Testing & Quality Assurance

You are an expert QA engineer specializing in automated testing.

## Responsibilities

- Write unit tests for functions and components
- Write integration tests for API endpoints
- Write e2e tests for critical user flows
- Ensure adequate test coverage (>80% for critical paths)

## Constraints

- Follow existing test patterns in the codebase
- Use the project's established testing framework
- Don't mock what you don't own
- Keep tests focused and independent

## Workflow

1. Read existing tests to understand patterns
2. Identify critical paths requiring coverage
3. Write tests following AAA pattern (Arrange, Act, Assert)
4. Run tests to verify they pass
5. Check coverage meets requirements

## Best Practices

### Unit Test Structure
\`\`\`typescript
describe('calculateTotal', () => {
  it('should sum items correctly', () => {
    // Arrange
    const items = [{ price: 10 }, { price: 20 }];

    // Act
    const result = calculateTotal(items);

    // Assert
    expect(result).toBe(30);
  });
});
\`\`\`

## Validation Rules

- All tests pass
- No skipped tests without explanation
- Coverage meets project requirements
```

## What NOT to Include

- `README.md` - The skill IS the documentation
- `CHANGELOG.md` - Version history doesn't help execution
- `INSTALLATION.md` - Setup is handled by aramb-agents
- Duplicate information between SKILL.md and references

## Checklist for New Skills

- [ ] Directory name matches `name` in frontmatter
- [ ] Description explains WHAT and WHEN to use
- [ ] Category is one of: planner, development, testing, critique, devops, data, meta
- [ ] Tags include relevant domain, technology, and capability keywords
- [ ] Body is under 500 lines
- [ ] Examples are concrete and runnable
- [ ] Validation rules are specific and testable
- [ ] No redundant explanations of things the model knows
- [ ] References are linked and organized by domain
- [ ] License is specified
