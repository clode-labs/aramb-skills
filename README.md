# aramb-skills

YAML-based skill definitions for LLM task execution in the aramb orchestrator system.

## Overview

This repository contains skill definitions that control how LLM agents execute specific types of tasks. Each skill defines:

- **System prompts** - Instructions for the LLM on how to approach the task
- **Tool configurations** - Which tools the LLM can use (file system, bash, browser, etc.)
- **LLM settings** - Provider preferences, model parameters, fallback strategies
- **Output structure** - Expected output format and validation rules

Agents load these skills at startup and use them to execute tasks assigned by the orchestrator.

---

## Directory Structure

```
aramb-skills/
├── README.md                  # This file
├── frontend/
│   └── skill.yaml            # Frontend development skill
├── qa/
│   └── skill.yaml            # Quality assurance skill
├── planning/
│   └── skill.yaml            # Task planning skill
├── backend/
│   └── skill.yaml            # Backend development skill
├── devops/
│   └── skill.yaml            # DevOps and infrastructure skill
└── research/
    └── skill.yaml            # Research and analysis skill
```

**Convention**: Each skill has its own directory with a `skill.yaml` file.

---

## Skill YAML Format

### Complete Schema

```yaml
# Unique identifier (must match directory name)
id: string

# Human-readable name
name: string

# Semantic version (e.g., "1.0.0")
version: string

# Brief description of what this skill does
description: string

# List of tools available to the LLM
tools:
  - string  # e.g., "bash", "read_file", "write_file", "browser"

# System prompt that defines the LLM's role and behavior
system_prompt: |
  Multi-line string with instructions for the LLM

# LLM configuration
llm_config:
  # Preferred provider (e.g., "claude-sonnet-4-5")
  preferred_provider: string

  # Fallback providers if preferred fails
  fallback_providers:
    - string

  # Model parameters
  parameters:
    max_tokens: int        # Maximum output tokens
    temperature: float     # 0.0-1.0 (lower = more deterministic)
    top_p: float          # Nucleus sampling threshold
    stop_sequences:       # Optional stop sequences
      - string

# Skill dependencies (optional)
dependencies:
  required_tools:
    - string              # Tools that must be available
  environment_variables:
    - string              # Environment variables that must be set

# Output validation rules (optional)
validation_rules:
  - string                # Validation rule descriptions

# Expected output structure (optional)
output_structure:
  type: string            # "json" | "text" | "files"
  schema: object          # JSON schema for structured outputs
```

---

## Example Skills

### 1. Frontend Development Skill

**File**: `frontend/skill.yaml`

```yaml
id: frontend
name: Frontend Development
version: 1.0.0
description: Build web applications with React, TypeScript, and modern frontend tools

tools:
  - bash
  - read_file
  - write_file
  - edit_file
  - glob
  - grep

system_prompt: |
  You are an expert frontend developer specializing in modern web development.

  Your primary technologies:
  - React 19 with TypeScript
  - Vite for build tooling
  - Tailwind CSS v4 for styling
  - shadcn/ui (Radix UI) for components
  - TanStack Query for data fetching
  - React Router for navigation

  Guidelines:
  1. Write type-safe TypeScript code with proper interfaces
  2. Follow React best practices (hooks, component composition)
  3. Use functional components with TypeScript
  4. Implement proper error boundaries and loading states
  5. Follow accessibility standards (ARIA, semantic HTML)
  6. Write clean, maintainable code with clear naming
  7. Add comments only when logic is complex
  8. Follow the existing project structure and patterns

  When creating components:
  - Use shadcn/ui components where applicable
  - Implement responsive design with Tailwind CSS
  - Handle loading and error states
  - Use proper TypeScript types

  When working with data:
  - Use TanStack Query for server state
  - Implement optimistic updates where appropriate
  - Handle errors gracefully with user feedback

  Output format:
  - List all files created or modified
  - Provide a brief summary of changes
  - Note any dependencies that need to be installed

llm_config:
  preferred_provider: claude-sonnet-4-5-20250929
  fallback_providers:
    - claude-sonnet-3-5-20241022
  parameters:
    max_tokens: 8192
    temperature: 0.7

dependencies:
  required_tools:
    - bash
    - read_file
    - write_file
  environment_variables: []

validation_rules:
  - Must include TypeScript types for all components
  - Must follow existing project structure
  - Must use existing UI component library (shadcn/ui)

output_structure:
  type: files
  schema:
    type: object
    properties:
      files_created:
        type: array
        items:
          type: string
      files_modified:
        type: array
        items:
          type: string
      summary:
        type: string
      dependencies_added:
        type: array
        items:
          type: string
```

### 2. Quality Assurance Skill

**File**: `qa/skill.yaml`

```yaml
id: qa
name: Quality Assurance
version: 1.0.0
description: Test applications, review code quality, and ensure reliability

tools:
  - bash
  - read_file
  - write_file
  - edit_file
  - glob
  - grep

system_prompt: |
  You are an expert QA engineer focused on ensuring software quality and reliability.

  Your responsibilities:
  1. Write comprehensive test suites (unit, integration, e2e)
  2. Review code for bugs, edge cases, and best practices
  3. Verify accessibility and performance
  4. Ensure error handling and edge case coverage
  5. Check type safety and validation

  Testing approach:
  - Frontend: Vitest for unit tests, Playwright for e2e
  - Backend: Go testing package, table-driven tests
  - Focus on critical paths and edge cases
  - Test both success and failure scenarios
  - Verify error messages are user-friendly

  Code review checklist:
  - Type safety (TypeScript/Go types)
  - Error handling (try/catch, error returns)
  - Input validation
  - Edge cases (null, empty, invalid data)
  - Performance considerations
  - Security vulnerabilities
  - Accessibility (ARIA, keyboard navigation)
  - Code duplication
  - Naming clarity

  Output format:
  - List issues found (categorized by severity: critical, high, medium, low)
  - Provide specific line numbers and file paths
  - Suggest fixes with code examples
  - For tests: list test files created and coverage achieved

llm_config:
  preferred_provider: claude-sonnet-4-5-20250929
  fallback_providers:
    - claude-sonnet-3-5-20241022
  parameters:
    max_tokens: 8192
    temperature: 0.5  # Lower temperature for more consistent analysis

dependencies:
  required_tools:
    - bash
    - read_file
    - grep
  environment_variables: []

validation_rules:
  - Must categorize issues by severity
  - Must provide specific file paths and line numbers
  - Must suggest actionable fixes

output_structure:
  type: json
  schema:
    type: object
    properties:
      issues:
        type: array
        items:
          type: object
          properties:
            severity:
              type: string
              enum: [critical, high, medium, low]
            category:
              type: string
            file_path:
              type: string
            line_number:
              type: integer
            description:
              type: string
            suggested_fix:
              type: string
      test_coverage:
        type: object
        properties:
          files_tested:
            type: integer
          coverage_percentage:
            type: number
          missing_coverage:
            type: array
            items:
              type: string
      summary:
        type: string
```

### 3. Planning Skill

**File**: `planning/skill.yaml`

```yaml
id: planning
name: Task Planning
version: 1.0.0
description: Break down complex tasks into actionable subtasks with dependencies

tools:
  - read_file
  - glob
  - grep

system_prompt: |
  You are an expert software architect and project planner.

  Your goal is to analyze a high-level task and break it down into:
  1. Clear, actionable subtasks
  2. Proper dependency ordering
  3. Skill assignments (frontend, backend, qa, devops, etc.)
  4. Input/output specifications for each subtask

  Planning approach:
  1. Read relevant files to understand the current codebase
  2. Identify what needs to be changed or created
  3. Break down into small, focused tasks
  4. Order tasks by dependencies (e.g., backend API before frontend integration)
  5. Assign appropriate skill to each task
  6. Specify inputs and expected outputs

  Task breakdown guidelines:
  - Each task should be independently testable
  - Tasks should be small enough to complete in one LLM session
  - Clearly specify dependencies (Task B depends on Task A's outputs)
  - Include testing and QA tasks
  - Consider edge cases and error handling

  Available skills to assign:
  - frontend: React/TypeScript UI development
  - backend: Go API development
  - qa: Testing and code review
  - devops: Infrastructure, deployment, CI/CD
  - research: Investigation, documentation, analysis

  Output format:
  Return a structured plan with tasks in dependency order.
  Each task must include:
  - Unique task name
  - Description
  - Assigned skill
  - Inputs (what data/files it needs)
  - Expected outputs
  - Dependencies (which tasks must complete first)

llm_config:
  preferred_provider: claude-sonnet-4-5-20250929
  fallback_providers:
    - claude-sonnet-3-5-20241022
  parameters:
    max_tokens: 8192
    temperature: 0.6

dependencies:
  required_tools:
    - read_file
    - glob
  environment_variables: []

validation_rules:
  - Must include at least one task
  - Each task must have a unique name
  - Each task must specify a skill
  - Tasks must be in valid dependency order (no circular dependencies)

output_structure:
  type: json
  schema:
    type: object
    properties:
      summary:
        type: string
        description: Brief overview of the plan
      tasks:
        type: array
        items:
          type: object
          required: [task_name, description, skill_id, inputs, outputs, dependencies]
          properties:
            task_name:
              type: string
            description:
              type: string
            skill_id:
              type: string
              enum: [frontend, backend, qa, devops, research, planning]
            inputs:
              type: object
              description: Expected inputs for this task
            outputs:
              type: object
              description: Expected outputs from this task
            dependencies:
              type: array
              items:
                type: string
              description: Task names that must complete before this one
            estimated_complexity:
              type: string
              enum: [low, medium, high]
```

---

## Adding a New Skill

### Step 1: Create Directory and File

```bash
cd aramb-skills
mkdir my-new-skill
touch my-new-skill/skill.yaml
```

### Step 2: Define the Skill

```yaml
id: my-new-skill
name: My New Skill
version: 1.0.0
description: Brief description of what this skill does

tools:
  - bash
  - read_file
  - write_file

system_prompt: |
  You are an expert in [domain].

  Your responsibilities:
  1. [Primary responsibility]
  2. [Secondary responsibility]

  Guidelines:
  - [Guideline 1]
  - [Guideline 2]

llm_config:
  preferred_provider: claude-sonnet-4-5-20250929
  fallback_providers:
    - claude-sonnet-3-5-20241022
  parameters:
    max_tokens: 4096
    temperature: 0.7

dependencies:
  required_tools:
    - bash
  environment_variables: []

validation_rules:
  - Must follow [requirement]

output_structure:
  type: text  # or "json" or "files"
```

### Step 3: Test the Skill

```bash
# Validate YAML syntax
python -c "import yaml; yaml.safe_load(open('my-new-skill/skill.yaml'))"

# Test with an agent
cd ../aramb-agents
python -m agent.worker
```

### Step 4: Commit and Push

```bash
git add my-new-skill/
git commit -m "Add my-new-skill for [purpose]"
git push origin main
```

---

## Integration with Agents

### How Agents Load Skills

The `aramb-agents` worker loads all skills at startup:

```python
# In agent/worker.py
skill_registry = SkillRegistry(config.skills_repo_path)
skill_registry.load_skills()  # Loads all skill.yaml files
```

### Skill Selection

When a task is assigned to an agent:

1. Orchestrator assigns `skill_id` to the task (e.g., `skill_id: "frontend"`)
2. Agent looks up the skill: `skill = skill_registry.get_skill(task['skill_id'])`
3. Agent executes task using skill's system prompt and LLM config

### Updating Skills

To update skills without restarting agents:

**Option 1: Auto-pull (if enabled)**
```bash
# In agent .env
SKILLS_AUTO_PULL=true
```

**Option 2: Manual restart**
```bash
# Pull latest skills
cd aramb-skills
git pull origin main

# Restart agent workers
cd ../aramb-agents
# Kill and restart worker processes
```

---

## Best Practices

### System Prompts

1. **Be specific**: Clearly define the LLM's role and responsibilities
2. **Include examples**: Show expected input/output formats
3. **Set constraints**: Define what to avoid or limitations
4. **Reference standards**: Mention frameworks, libraries, conventions to follow

### Tool Selection

Only include tools the skill actually needs:

- `bash`: Execute commands (npm, git, etc.)
- `read_file`: Read file contents
- `write_file`: Create new files
- `edit_file`: Modify existing files
- `glob`: Find files by pattern
- `grep`: Search file contents
- `browser`: Web scraping, research

### LLM Parameters

- **max_tokens**: Set based on expected output size
  - Simple tasks: 2048-4096
  - Complex tasks: 8192-16384
- **temperature**:
  - 0.3-0.5: Deterministic tasks (QA, testing)
  - 0.6-0.7: Creative tasks (development, planning)
  - 0.8-1.0: Highly creative tasks (brainstorming)

### Validation Rules

Define clear success criteria:

```yaml
validation_rules:
  - All TypeScript files must have proper type annotations
  - Generated code must pass existing linter rules
  - Must include error handling for all external calls
  - Must follow project naming conventions
```

### Output Structures

Use structured outputs for machine-readable results:

```yaml
output_structure:
  type: json
  schema:
    type: object
    properties:
      success:
        type: boolean
      result:
        type: string
      files_affected:
        type: array
        items:
          type: string
```

---

## Versioning

Skills follow semantic versioning (MAJOR.MINOR.PATCH):

- **MAJOR**: Breaking changes to skill interface or behavior
- **MINOR**: New features, backward-compatible
- **PATCH**: Bug fixes, clarifications

When updating a skill version:

```yaml
version: 2.0.0  # Update version
```

Agents automatically pick up the latest version on restart.

---

## Troubleshooting

### "Skill not found" error

**Problem**: Agent can't find skill definition

**Solutions**:
1. Check `SKILLS_REPO_PATH` in agent `.env`
2. Verify `skill.yaml` exists in skill directory
3. Ensure `id` in YAML matches directory name
4. Run `git pull` in aramb-skills

### YAML syntax errors

**Problem**: Skill fails to load

**Solutions**:
1. Validate YAML syntax:
   ```bash
   python -c "import yaml; yaml.safe_load(open('skill.yaml'))"
   ```
2. Check indentation (use spaces, not tabs)
3. Ensure multi-line strings use `|` or `>`

### Skill not using correct tools

**Problem**: Task fails because tool is unavailable

**Solutions**:
1. Add tool to `tools` list in skill.yaml
2. Verify tool is implemented in agent
3. Check `required_tools` in dependencies

---

## Document Metadata

- **Version**: 1.0
- **Date**: 2025-12-30
- **Status**: Reference Documentation
- **Related**: aramb-agents (consumer), aramb-orchestrator (assigner)
