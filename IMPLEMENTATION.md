# aramb-skills Implementation Guide

## 1. Overview

The `aramb-skills` repository is a **centralized library of skill definitions** that define how LLM agents execute different types of tasks. Each skill is a YAML configuration file that specifies:

- Which LLM provider to use
- System prompts and instructions
- Required tools and capabilities
- Input/output structure
- Validation rules

**Key Concepts**:
- **Skill**: A reusable template for executing a specific type of task (e.g., "frontend development", "code review", "testing")
- **Skill Definition**: YAML file with configuration, prompts, and metadata
- **Skill Registry**: Agent component that loads and manages skills
- **Extensibility**: New skills can be added without modifying agent code

**Technology**: YAML, Git (version control for skills)

---

## 2. Directory Structure

```
aramb-skills/
├── frontend/
│   ├── skill.yaml
│   └── templates/
│       └── react-component.yaml
├── backend/
│   ├── skill.yaml
│   └── templates/
│       ├── rest-api.yaml
│       └── database-migration.yaml
├── testing/
│   ├── skill.yaml
│   └── templates/
│       ├── unit-tests.yaml
│       └── e2e-tests.yaml
├── code-review/
│   └── skill.yaml
├── documentation/
│   └── skill.yaml
├── refactoring/
│   └── skill.yaml
├── bugfix/
│   └── skill.yaml
├── deployment/
│   └── skill.yaml
├── schemas/
│   └── skill-schema.json        # JSON Schema for validation
├── examples/
│   └── example-skill.yaml
└── README.md
```

**Organization Principles**:
- One directory per skill
- Each skill directory contains a `skill.yaml` file
- Optional `templates/` subdirectory for sub-task templates
- Shared schemas in `schemas/` directory

---

## 3. Skill YAML Schema

### 3.1 Core Structure

**File**: `schemas/skill-schema.json`

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["id", "name", "version", "description", "llm_config"],
  "properties": {
    "id": {
      "type": "string",
      "pattern": "^[a-z0-9-]+$",
      "description": "Unique identifier for the skill"
    },
    "name": {
      "type": "string",
      "description": "Human-readable name"
    },
    "version": {
      "type": "string",
      "pattern": "^\\d+\\.\\d+\\.\\d+$",
      "description": "Semantic version (e.g., 1.0.0)"
    },
    "description": {
      "type": "string",
      "description": "What this skill does"
    },
    "category": {
      "type": "string",
      "enum": ["development", "testing", "review", "documentation", "deployment", "analysis"],
      "description": "Skill category"
    },
    "tools": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Tools available to the agent (e.g., file_edit, bash, search)"
    },
    "system_prompt": {
      "type": "string",
      "description": "System-level instructions for the LLM"
    },
    "llm_config": {
      "type": "object",
      "required": ["preferred_provider"],
      "properties": {
        "preferred_provider": {
          "type": "string",
          "description": "Primary LLM provider (e.g., anthropic, openai, gemini)"
        },
        "fallback_providers": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Backup providers if primary fails"
        },
        "parameters": {
          "type": "object",
          "properties": {
            "model": { "type": "string" },
            "max_tokens": { "type": "integer" },
            "temperature": { "type": "number" }
          }
        }
      }
    },
    "dependencies": {
      "type": "object",
      "properties": {
        "runtime": {
          "type": "array",
          "items": { "type": "string" }
        },
        "packages": {
          "type": "array",
          "items": { "type": "string" }
        }
      }
    },
    "validation_rules": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Post-execution validation checks"
    },
    "output_structure": {
      "type": "object",
      "description": "Expected output format"
    },
    "timeout_seconds": {
      "type": "integer",
      "default": 3600,
      "description": "Maximum execution time"
    },
    "metadata": {
      "type": "object",
      "description": "Additional metadata"
    }
  }
}
```

### 3.2 Example Skill Definition

**File**: `frontend/skill.yaml`

```yaml
# Skill Identity
id: frontend
name: Frontend Development
version: 1.0.0
description: Build modern frontend applications using React, Vue, or vanilla JavaScript

# Categorization
category: development
tags:
  - javascript
  - typescript
  - react
  - vue
  - ui/ux

# Tools available to agent
tools:
  - file_edit          # Create/modify files
  - file_read          # Read existing files
  - bash               # Run commands (npm, build, etc.)
  - search_code        # Search codebase
  - web_search         # Search docs/Stack Overflow

# System prompt for LLM
system_prompt: |
  You are an expert frontend developer specializing in modern web technologies.

  **Your responsibilities**:
  - Build React/Vue components following best practices
  - Write clean, maintainable, accessible code
  - Implement responsive designs using Tailwind CSS or CSS modules
  - Follow the project's existing code style and patterns
  - Write self-documenting code with TypeScript types
  - Consider performance, accessibility (a11y), and SEO

  **Constraints**:
  - Always use functional components and hooks (React)
  - Prefer composition over inheritance
  - Keep components small and focused (single responsibility)
  - Use semantic HTML elements
  - Ensure mobile-first responsive design
  - Never use deprecated APIs or libraries

  **Output requirements**:
  - Working, tested code
  - Proper error handling
  - Loading states for async operations
  - Accessibility attributes (ARIA labels, roles)

  When implementing a task:
  1. Read existing code to understand patterns
  2. Plan component structure
  3. Implement with proper types
  4. Test in browser if possible
  5. Document complex logic

# LLM Configuration
llm_config:
  preferred_provider: anthropic
  fallback_providers:
    - openai
    - gemini
  parameters:
    model: claude-sonnet-4-5-20250929
    max_tokens: 8192
    temperature: 0.7

# Runtime dependencies
dependencies:
  runtime:
    - node >= 18.0.0
    - npm >= 9.0.0
  packages:
    - react
    - typescript
    - vite
    - tailwindcss

# Validation rules (run after task completion)
validation_rules:
  - "TypeScript compilation succeeds (npm run build)"
  - "No ESLint errors"
  - "Components are properly exported"
  - "No console.log statements in production code"

# Expected output structure
output_structure:
  files_created:
    type: array
    description: List of new files created
    items:
      type: string
  files_modified:
    type: array
    description: List of files modified
    items:
      type: string
  components_added:
    type: array
    description: New React/Vue components
    items:
      type: object
      properties:
        name:
          type: string
        path:
          type: string
        description:
          type: string
  build_success:
    type: boolean
    description: Whether npm run build succeeded
  preview_url:
    type: string
    description: Local dev server URL (optional)

# Timeout configuration
timeout_seconds: 3600  # 1 hour for complex UIs

# Metadata
metadata:
  author: aramb-team
  created_at: "2025-12-30"
  last_updated: "2025-12-30"
  documentation_url: https://github.com/yourorg/aramb-skills/blob/main/frontend/README.md
  examples:
    - "Build a calculator component with React and Tailwind"
    - "Create a responsive navigation bar with mobile menu"
    - "Implement a form with validation using React Hook Form"
```

---

## 4. Skill Categories

### 4.1 Frontend Skills

**Examples**:
- `frontend` - General React/Vue development
- `frontend-react` - React-specific (hooks, context, etc.)
- `frontend-vue` - Vue-specific (composition API, Pinia)
- `ui-design` - Design system components
- `css-styling` - Advanced CSS/animations

### 4.2 Backend Skills

**Examples**:
- `backend` - General backend development
- `rest-api` - RESTful API implementation
- `graphql-api` - GraphQL schema and resolvers
- `database` - Database design and migrations
- `microservices` - Distributed system design

### 4.3 Testing Skills

**Examples**:
- `testing-unit` - Unit tests (Jest, Vitest)
- `testing-e2e` - End-to-end tests (Playwright, Cypress)
- `testing-integration` - Integration tests
- `testing-performance` - Load testing, benchmarks

### 4.4 DevOps Skills

**Examples**:
- `deployment` - CI/CD, containerization
- `infrastructure` - Terraform, Kubernetes
- `monitoring` - Logging, metrics, alerts

### 4.5 Analysis Skills

**Examples**:
- `code-review` - Review code quality and security
- `documentation` - Generate/update docs
- `refactoring` - Improve code structure
- `bugfix` - Debug and fix issues

---

## 5. Creating New Skills

### 5.1 Skill Creation Checklist

1. **Define the skill scope**
   - What type of tasks does it handle?
   - What are the inputs and expected outputs?
   - What tools does the agent need?

2. **Choose skill ID and category**
   - Use lowercase with hyphens (e.g., `frontend-react`)
   - Select appropriate category

3. **Write system prompt**
   - Be specific about responsibilities
   - Include constraints and best practices
   - Define output requirements
   - Provide step-by-step guidance

4. **Configure LLM provider**
   - Choose best model for the task
   - Set appropriate max_tokens and temperature
   - Add fallback providers

5. **Define validation rules**
   - How to verify task success?
   - What tests should run?
   - What quality checks are needed?

6. **Document output structure**
   - What files are created/modified?
   - What metrics are tracked?
   - What artifacts are produced?

7. **Test the skill**
   - Create sample tasks
   - Run through agent execution
   - Verify outputs match expectations

### 5.2 Skill Development Template

**File**: `examples/example-skill.yaml`

```yaml
# Skill Identity
id: my-new-skill
name: My New Skill
version: 1.0.0
description: Brief description of what this skill does

# Categorization
category: development  # or testing, review, documentation, deployment, analysis
tags:
  - tag1
  - tag2

# Tools
tools:
  - file_edit
  - bash

# System Prompt
system_prompt: |
  You are an expert in [domain].

  **Responsibilities**:
  - [What the agent should do]

  **Constraints**:
  - [Limitations and rules]

  **Output requirements**:
  - [What the agent must produce]

  **Process**:
  1. [Step 1]
  2. [Step 2]
  3. [Step 3]

# LLM Config
llm_config:
  preferred_provider: anthropic
  parameters:
    model: claude-sonnet-4-5-20250929
    max_tokens: 4096
    temperature: 0.7

# Dependencies
dependencies:
  runtime: []
  packages: []

# Validation
validation_rules:
  - "Validation check 1"
  - "Validation check 2"

# Output Structure
output_structure:
  files_created:
    type: array
  success:
    type: boolean

# Timeout
timeout_seconds: 1800

# Metadata
metadata:
  author: your-name
  created_at: "2025-12-30"
```

---

## 6. More Skill Examples

### 6.1 Backend REST API Skill

**File**: `backend/templates/rest-api.yaml`

```yaml
id: backend-rest-api
name: Backend REST API Development
version: 1.0.0
description: Build RESTful APIs with Go, Node.js, or Python

category: development
tags:
  - api
  - rest
  - backend
  - go
  - node
  - python

tools:
  - file_edit
  - file_read
  - bash
  - search_code

system_prompt: |
  You are an expert backend developer specializing in RESTful API design.

  **Responsibilities**:
  - Design clean, RESTful API endpoints
  - Implement CRUD operations with proper HTTP methods
  - Add input validation and error handling
  - Follow REST best practices (status codes, headers, versioning)
  - Write OpenAPI/Swagger documentation
  - Implement authentication/authorization if required

  **Constraints**:
  - Use framework conventions (Fiber for Go, Express for Node, FastAPI for Python)
  - Always validate input data
  - Return proper HTTP status codes (200, 201, 400, 404, 500)
  - Use JSON for request/response bodies
  - Include error messages in responses
  - Follow project's existing patterns

  **Output requirements**:
  - Working API endpoints
  - Input validation
  - Error handling
  - API documentation (comments or OpenAPI spec)
  - Tests for critical paths

  **Process**:
  1. Read existing API code to understand patterns
  2. Design endpoint paths and methods (GET, POST, PUT, DELETE)
  3. Implement handlers with validation
  4. Add error handling
  5. Document endpoints
  6. Write basic tests

llm_config:
  preferred_provider: anthropic
  parameters:
    model: claude-sonnet-4-5-20250929
    max_tokens: 8192
    temperature: 0.6

dependencies:
  runtime:
    - go >= 1.21 || node >= 18 || python >= 3.11
  packages:
    - fiber || express || fastapi

validation_rules:
  - "Code compiles/runs without errors"
  - "All endpoints return valid JSON"
  - "400 status for invalid input"
  - "404 status for not found"
  - "500 status for server errors"

output_structure:
  endpoints_created:
    type: array
    items:
      type: object
      properties:
        method:
          type: string
          enum: [GET, POST, PUT, DELETE, PATCH]
        path:
          type: string
        description:
          type: string
  files_modified:
    type: array
  tests_added:
    type: boolean

timeout_seconds: 2400

metadata:
  author: aramb-team
  created_at: "2025-12-30"
```

### 6.2 Code Review Skill

**File**: `code-review/skill.yaml`

```yaml
id: code-review
name: Code Review
version: 1.0.0
description: Review code for quality, security, performance, and best practices

category: review
tags:
  - code-review
  - quality
  - security
  - best-practices

tools:
  - file_read
  - search_code
  - bash  # For running linters

system_prompt: |
  You are an expert code reviewer with deep knowledge of software engineering best practices.

  **Responsibilities**:
  - Review code for correctness, clarity, and maintainability
  - Identify security vulnerabilities
  - Suggest performance improvements
  - Check adherence to coding standards
  - Provide constructive feedback

  **Review checklist**:
  - [ ] Code correctness (does it work as intended?)
  - [ ] Code clarity (is it easy to understand?)
  - [ ] Edge cases handled (nulls, errors, boundaries)
  - [ ] Security issues (injection, XSS, auth bypasses)
  - [ ] Performance concerns (N+1 queries, memory leaks)
  - [ ] Test coverage (are critical paths tested?)
  - [ ] Documentation (are complex parts explained?)
  - [ ] Naming conventions (clear variable/function names)
  - [ ] DRY principle (no unnecessary duplication)
  - [ ] SOLID principles (single responsibility, etc.)

  **Output format**:
  - Summary of findings
  - List of issues by severity (critical, major, minor)
  - Specific file locations and line numbers
  - Suggested fixes with code examples
  - Positive feedback (what's done well)

  **Tone**:
  - Be constructive and respectful
  - Explain the "why" behind suggestions
  - Provide examples of better approaches
  - Balance criticism with praise

llm_config:
  preferred_provider: anthropic
  parameters:
    model: claude-sonnet-4-5-20250929
    max_tokens: 16384  # Long reviews need more tokens
    temperature: 0.5   # More deterministic for consistency

dependencies:
  runtime: []
  packages: []

validation_rules:
  - "Review covers all modified files"
  - "Issues include file paths and line numbers"
  - "At least one positive comment"

output_structure:
  summary:
    type: string
    description: High-level overview of the review
  issues:
    type: array
    items:
      type: object
      properties:
        severity:
          type: string
          enum: [critical, major, minor, suggestion]
        category:
          type: string
          enum: [security, performance, correctness, style, documentation]
        file:
          type: string
        line:
          type: integer
        description:
          type: string
        suggestion:
          type: string
  positive_feedback:
    type: array
    items:
      type: string
  overall_rating:
    type: string
    enum: [excellent, good, needs-improvement, major-issues]

timeout_seconds: 1800

metadata:
  author: aramb-team
  created_at: "2025-12-30"
```

### 6.3 Testing Skill

**File**: `testing/skill.yaml`

```yaml
id: testing-unit
name: Unit Testing
version: 1.0.0
description: Write comprehensive unit tests for code

category: testing
tags:
  - testing
  - unit-tests
  - jest
  - vitest
  - pytest

tools:
  - file_edit
  - file_read
  - bash
  - search_code

system_prompt: |
  You are an expert in writing unit tests that ensure code quality and prevent regressions.

  **Responsibilities**:
  - Write comprehensive unit tests for functions and components
  - Cover happy paths, edge cases, and error scenarios
  - Use appropriate testing frameworks (Jest, Vitest, pytest, etc.)
  - Mock external dependencies
  - Ensure tests are fast, isolated, and deterministic

  **Test structure**:
  - Arrange: Set up test data and mocks
  - Act: Execute the code being tested
  - Assert: Verify expected outcomes

  **Best practices**:
  - One assertion per test (or closely related assertions)
  - Clear test names describing what is being tested
  - Test behavior, not implementation details
  - Use descriptive variable names in tests
  - Group related tests with describe/context blocks
  - Clean up after tests (reset mocks, clear state)

  **Coverage requirements**:
  - All public functions/methods
  - Edge cases (empty arrays, null values, boundaries)
  - Error paths (exceptions, validation failures)
  - Conditional logic (if/else branches)

  **Process**:
  1. Read the code to be tested
  2. Identify test scenarios (happy path + edge cases)
  3. Write test setup and mocks
  4. Implement test cases
  5. Run tests to verify they pass
  6. Check coverage and add missing tests

llm_config:
  preferred_provider: anthropic
  parameters:
    model: claude-sonnet-4-5-20250929
    max_tokens: 8192
    temperature: 0.6

dependencies:
  runtime:
    - node >= 18 || python >= 3.11
  packages:
    - jest || vitest || pytest

validation_rules:
  - "All tests pass"
  - "No skipped tests (unless intentional)"
  - "Tests are isolated (no shared state)"
  - "Coverage meets project standards"

output_structure:
  test_files_created:
    type: array
  tests_count:
    type: integer
  coverage_percentage:
    type: number
  tests_passed:
    type: boolean

timeout_seconds: 1800

metadata:
  author: aramb-team
  created_at: "2025-12-30"
```

---

## 7. Best Practices

### 7.1 System Prompt Design

**DO**:
- Be specific about what the agent should do
- Include constraints and rules
- Provide step-by-step process
- Give examples of good vs bad approaches
- Define success criteria
- Use clear, imperative language

**DON'T**:
- Be vague or ambiguous
- Assume the agent knows project-specific patterns
- Skip error handling instructions
- Forget to mention output requirements

### 7.2 Tool Selection

**Common tools**:
- `file_edit` - Create or modify files
- `file_read` - Read existing code
- `bash` - Run shell commands (build, test, lint)
- `search_code` - Find patterns in codebase
- `web_search` - Look up documentation

**When to add tools**:
- Only include tools the skill actually needs
- More tools = more complexity for the agent
- Consider security implications (bash access)

### 7.3 Validation Rules

**Good validation rules**:
- "TypeScript compilation succeeds"
- "All tests pass"
- "No ESLint errors"
- "API returns 200 status"
- "Coverage >= 80%"

**Bad validation rules**:
- "Code is good" (too vague)
- "No bugs" (untestable)
- "Fast performance" (no specific metric)

### 7.4 Version Management

**Semantic versioning**:
- `1.0.0` - Initial stable release
- `1.1.0` - New features (backward compatible)
- `1.0.1` - Bug fixes
- `2.0.0` - Breaking changes

**When to bump versions**:
- Major: System prompt completely rewritten, breaking changes
- Minor: New tools added, prompt improvements
- Patch: Bug fixes, typo corrections

### 7.5 Testing Skills

**Before committing a new skill**:
1. Create sample tasks that use the skill
2. Run through agent execution manually
3. Verify outputs match `output_structure`
4. Check validation rules actually run
5. Test fallback providers (if configured)
6. Review system prompt for clarity

---

## 8. Skill Loading by Agents

Agents load skills using the `SkillRegistry` component:

```python
# From aramb-agents IMPLEMENTATION.md
skill_registry = SkillRegistry(config.skills_repo_path)
skill_registry.load_skills()

# Get skill by ID
skill = skill_registry.get_skill("frontend")

# Use in task execution
result = await llm_provider.execute_task(task, skill, heartbeat_callback)
```

**Loading process**:
1. Agent starts and reads `SKILLS_REPO_PATH` env variable
2. Recursively searches for `skill.yaml` files
3. Validates YAML against schema
4. Loads into in-memory registry
5. Tasks reference skills by `skill_id`

---

## 9. Skill Repository Maintenance

### 9.1 Git Workflow

```bash
# Clone repository
git clone https://github.com/yourorg/aramb-skills.git
cd aramb-skills

# Create feature branch for new skill
git checkout -b feature/add-database-skill

# Add skill files
mkdir database
# ... create skill.yaml ...

# Commit and push
git add database/
git commit -m "Add database migration skill"
git push origin feature/add-database-skill

# Create pull request
```

### 9.2 Pull Request Checklist

- [ ] Skill ID is unique
- [ ] YAML is valid (run schema validation)
- [ ] System prompt is clear and complete
- [ ] Tools are appropriate for the task
- [ ] Validation rules are testable
- [ ] Output structure is documented
- [ ] Version follows semver
- [ ] Metadata is complete
- [ ] Tested with sample tasks

### 9.3 Auto-Pull Skills (Agent Feature)

Agents can auto-update skills:

```env
# .env for aramb-agents
SKILLS_REPO_PATH=../aramb-skills
SKILLS_AUTO_PULL=true  # Git pull before loading skills
```

**How it works**:
1. Agent starts
2. If `SKILLS_AUTO_PULL=true`, runs `git pull` in skills repo
3. Loads latest skill definitions
4. Ensures agents always use up-to-date skills

---

## 10. Future Enhancements

### 10.1 Skill Composition

Allow skills to reference other skills as sub-tasks:

```yaml
id: full-stack
name: Full-Stack Development
version: 1.0.0
description: Build both frontend and backend

# Reference other skills
sub_skills:
  - skill_id: frontend
    when: frontend_required
  - skill_id: backend-rest-api
    when: api_required
  - skill_id: testing-unit
    when: always
```

### 10.2 Skill Marketplace

- Public registry of community-contributed skills
- Versioned skill packages
- Skill ratings and reviews
- Dependency management

### 10.3 Dynamic Skill Selection

Allow planner to choose skills based on prompt analysis:

```yaml
# Planner analyzes prompt and selects best skill
prompt: "Build a React calculator app"
# → Planner chooses: frontend-react

prompt: "Create a user authentication API"
# → Planner chooses: backend-rest-api
```

### 10.4 Skill Analytics

Track skill performance:
- Success rate per skill
- Average tokens used
- Common failure patterns
- Execution time metrics

---

## 11. Troubleshooting

### Common Issues

**1. "Skill not found" error**
- Check `SKILLS_REPO_PATH` points to correct directory
- Verify `skill.yaml` exists in skill directory
- Ensure skill ID matches task's `skill_id`

**2. "Invalid YAML" error**
- Run YAML validation: `yamllint skill.yaml`
- Check for syntax errors (indentation, quotes)
- Validate against schema

**3. "Tool not available" error**
- Agent doesn't support the tool listed in `tools`
- Check agent's tool registry
- Use only supported tools

**4. Agent uses wrong LLM**
- Check `llm_config.preferred_provider` is set
- Ensure API key is configured in agent
- Verify provider is available

---

## Document Metadata

- **Version**: 1.0.0
- **Date**: 2025-12-30
- **Status**: Implementation Guide
- **Related**: aramb-agents/IMPLEMENTATION.md
- **Schema Version**: 1.0.0
- **Cross-Module Reference**: See `/CROSS_MODULE_REFERENCE.md` for skill loading, validation, and error handling
