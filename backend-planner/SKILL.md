---
name: backend-planner
description: Plan complex backend work by analyzing requirements and creating executable task sequences. Use this skill when breaking down API features, service architectures, database changes, or backend integrations into development and QA tasks with self-validation.
category: planner
tags: [backend, api, golang, python, planning, server]
license: MIT
---

# Backend Planning

Analyze complex backend requirements and create executable task plans.

## Process

1. **Explore codebase** - Identify language, framework, conventions
2. **Design architecture** - Plan endpoints, models, services (output as text summary)
3. **Search for skills** - Use `search_skills` MCP tool to find development and QA skills
4. **Create tasks via MCP** - Use `create_tasks_batch` to create all tasks with dependencies
5. **Confirm creation** - Verify the MCP tool successfully created the tasks

## Task Sequencing Principle

You have **two patterns** to choose from based on complexity:

### Pattern 1: Standard Tasks (Default)
Use when the work is relatively focused and sequential:

```
1. [development skill] → Build the feature (self-validates: compiles, runs, migrations work)
2. [testing/critique skill] → QA against user expectations (self-validates: tests pass, coverage good)
3. [metadata skill] → Create/update aramb.toml (self-validates: TOML syntax, services detected)
```

**The Correctness Loop:**
- Each task validates itself using its `validation_criteria`
- **Build task** validates: code compiles, runs without errors, migrations succeed, endpoints work
- **QA task** validates: tests pass, coverage adequate, edge cases covered, security tested
- If QA finds implementation issues → QA fails with detailed `feedback_for_rebuild`
- System re-triggers the build task with the QA feedback
- Loop continues until QA passes

### Pattern 2: Parent Task with Sub-tasks
Use when complex work benefits from **sequential decomposition with checkpoints**:
- **Dynamic discovery** - Create sub-tasks as you learn what needs to be done
- **Resumability** - If sub-task 3 fails, sub-tasks 1 and 2 are preserved
- **Granular progress** - Users see incremental completion
- **Mid-work insertion** - Add a sub-task between existing ones when you discover a dependency

Sub-tasks execute **sequentially** - each waits for the previous to complete.

```
Parent Task: "Build [Feature]"
  ├── Sub-task 1: "Create [Database Schema]"   ← Runs first
  ├── Sub-task 2: "Build [Core Service]"       ← Waits for 1
  ├── Sub-task 3: "Add [Handlers]"             ← Waits for 2
  └── Sub-task 4: "Wire up routes"             ← Waits for 3

QA Task: "Test [Feature]"
  └── dependencies: [parent-task-id]

Metadata Task: "Create/update aramb.toml"
  └── dependencies: [qa-task-id]
```

**When to use sub-tasks:**
- Complex feature that benefits from step-by-step decomposition
- Work where you'll discover scope as you go (investigation → fixes)
- You want checkpoints so partial progress survives failures
- Multi-step process with natural phases (schema → service → handlers → routes)

**When NOT to use sub-tasks:**
- Simple, focused features that don't need decomposition
- Quick fixes or small enhancements
- Work that's already well-understood and atomic

**Why this simplified pattern:**
- **Build task self-validates**: Code compiles, runs, migrations work - immediate feedback
- **QA task self-validates**: Tests written, pass, cover requirements
- **No separate critique tasks**: Eliminates redundant QA layers
- **Correctness loop**: QA failure triggers re-build with specific feedback

**Required skills to search for:**
1. A **development skill** (category: "development", tag: "backend") - to build the feature
2. A **QA skill** (category: "testing" OR "critique", tag: "backend") - to test/validate user expectations
3. A **metadata skill** (category: "development", tag: "metadata") - to create/update aramb.toml configuration

## Task Creation with MCP

After exploring the codebase, designing the architecture, and searching for skills, use the `create_tasks_batch` MCP tool to create all tasks at once.

**Architecture Summary**: Before creating tasks, output a brief text summary of your planned architecture. This provides context for the tasks.

**Task Creation**: Use `create_tasks_batch` with `uniqueId` and `logicalDependencies` to define task relationships:

```
create_tasks_batch(tasks=[
  {
    "uniqueId": 1,
    "skill_id": "<development-full_id from search>",
    "task_name": "Implement [Feature]",
    "description": "Build the API and services",
    "task_order": 1,
    "inputs": {
      "requirements": "Specific requirements from original prompt",
      "files_to_create": ["internal/handlers/resource.go"],
      "files_to_modify": ["internal/routes/routes.go"],
      "patterns_to_follow": "Reference to existing code patterns"
    },
    "validation_criteria": {
      "critical": ["Code compiles", "Migrations run successfully", "Endpoints respond correctly"],
      "expected": ["Auth enforced", "Input validation", "Error handling"],
      "nice_to_have": ["Logging", "Metrics"]
    },
    "timeout_seconds": 3600
  },
  {
    "uniqueId": 2,
    "skill_id": "<testing-or-critique-full_id from search>",
    "task_name": "QA: Test [Feature]",
    "description": "Write and run tests validating user requirements. If implementation has issues, fail with detailed feedback.",
    "task_order": 2,
    "logicalDependencies": [1],
    "inputs": {
      "critiques_tasks": [1],  // ← CRITICAL: References uniqueId of task(s) this QA validates
      "original_prompt": "The user's original request",
      "preceding_task": {
        "task_order": 1,
        "skill_id": "<development-full_id>",
        "task_name": "<task-name-from-task-1>",
        "description": "<description-from-task-1>"
      },
      "user_expectations": [
        "User can do X via API",
        "Y is returned when...",
        "Z error is returned when..."
      ],
      "files_to_test": ["internal/handlers/resource.go", "internal/services/resource_service.go"]
    },
    "validation_criteria": {
      "critical": ["Tests pass", "Critical API paths covered", "No broken functionality found"],
      "expected": ["Error cases tested", "Auth tested"],
      "nice_to_have": ["High coverage", "Performance tested"]
    },
    "timeout_seconds": 3600
  },
  {
    "uniqueId": 3,
    "skill_id": "<metadata-full_id from search>",
    "task_name": "Create/update aramb.toml",
    "description": "Generate or update aramb.toml configuration by analyzing project structure, docker-compose, and codebase",
    "task_order": 3,
    "logicalDependencies": [2],
    "inputs": {
      "requirements": "Analyze project and create/update aramb.toml with service configurations",
      "project_path": "."
    },
    "validation_criteria": {
      "critical": ["TOML syntax valid", "Services detected", "Service types valid"],
      "expected": ["Dependencies mapped", "Environment vars extracted"],
      "nice_to_have": ["Service references configured"]
    },
    "timeout_seconds": 1800
  }
])
```

**Logical Dependencies**: Use `uniqueId` (integer) to identify tasks within the batch, and `logicalDependencies` (array of integers) to reference other tasks by their uniqueId. The server validates for circular dependencies and missing references, returning a 400 error if validation fails.

## QA Task Construction

The QA task is responsible for:
1. **Writing tests** that validate user requirements
2. **Running tests** to verify implementation works
3. **Validating its own criteria**: coverage, edge cases, security tests
4. **Outputting verdict** with `feedback_for_rebuild` if implementation has issues

**CRITICAL:** Include `critiques_tasks` in inputs - this tells brahmi which task(s) to retry if QA fails:

```json
{
  "inputs": {
    "critiques_tasks": [1],  // ← REQUIRED: uniqueId(s) of task(s) this QA validates
    "original_prompt": "User's original request",
    "preceding_task": {
      "task_order": 1,
      "skill_id": "<full_id of the skill that built the feature>",
      "task_name": "<name of that task>",
      "description": "<what that task did>"
    },
    "user_expectations": ["List of what user expects to work"]
  },
  "validation_criteria": {
    "critical": ["Tests pass", "User requirements validated"],
    "expected": ["Security tested", "Error cases covered"],
    "nice_to_have": ["High coverage"]
  }
}
```

**How the correctness loop works:**
1. QA task completes with `verdict: fail` and `feedback_for_rebuild` in outputs
2. Brahmi reads `critiques_tasks` from QA task inputs
3. Brahmi retries those task(s) with the feedback injected into their inputs
4. QA task resets to "planned" (waiting for dependency)
5. After retried task completes, QA runs again
6. Loop continues until `verdict: pass` or max retries exceeded

**IMPORTANT:** The `skill_id` must always be the `full_id` from search results (e.g., `"clode-labs/aramb-skills/backend-development"`), NOT the short name.

## Example

**Input:** "Build subscription API with Stripe"

**Step 1: Search for skills**
```
search_skills(category: "development", tag: "backend")
→ Returns: full_id: "acme/skills/backend-dev" (use this)

search_skills(category: "testing", tag: "backend")
→ Returns: full_id: "acme/skills/backend-testing" (use this)
# OR
search_skills(category: "critique", tag: "backend")
→ Returns: full_id: "acme/skills/backend-critique" (use this)

search_skills(category: "development", tag: "metadata")
→ Returns: full_id: "acme/skills/aramb-metadata" (use this)
```

**Step 2: Output architecture summary (text)**

> **Architecture**: Subscription API with Stripe integration and webhook handling.
> - **Endpoints**: POST /api/v1/subscriptions (create), GET /api/v1/subscriptions (status), POST /api/v1/webhooks/stripe (events)
> - **Models**: Subscription (id, user_id, stripe_subscription_id, status)
> - **Services**: SubscriptionService (lifecycle), StripeService (API wrapper)
> - **External**: Stripe API

**Step 3: Create tasks using MCP**
```
create_tasks_batch(tasks=[
  {
    "uniqueId": 1,
    "skill_id": "acme/skills/backend-dev",
    "task_name": "Build subscription service",
    "description": "Create migrations, models, services, and handlers for Stripe subscription API",
    "task_order": 1,
    "inputs": {
      "requirements": "Subscription API with Stripe integration, migrations, handlers",
      "files_to_create": [
        "migrations/00X_create_subscriptions.sql",
        "internal/services/stripe_service.go",
        "internal/handlers/subscription_handlers.go"
      ],
      "files_to_modify": ["internal/routes/routes.go"]
    },
    "validation_criteria": {
      "critical": ["Code compiles", "Migration runs", "Endpoints respond", "Webhook signature verified"],
      "expected": ["Auth enforced", "Input validation", "Error handling"],
      "nice_to_have": ["Logging", "Idempotency keys"]
    },
    "timeout_seconds": 3600
  },
  {
    "uniqueId": 2,
    "skill_id": "acme/skills/backend-testing",
    "task_name": "QA: Test subscription API",
    "description": "Write and run tests for subscription API. Validate create, status check, and webhook handling work. If implementation has issues, fail with detailed feedback for rebuild.",
    "task_order": 2,
    "logicalDependencies": [1],
    "inputs": {
      "critiques_tasks": [1],  // ← Triggers correctness loop if verdict=fail
      "original_prompt": "Build subscription API with Stripe",
      "preceding_task": {
        "task_order": 1,
        "skill_id": "acme/skills/backend-dev",
        "task_name": "Build subscription service",
        "description": "Create migrations, models, services, and handlers"
      },
      "user_expectations": [
        "User can create a subscription",
        "User can check subscription status",
        "Stripe webhooks are handled correctly",
        "Subscription state is persisted"
      ],
      "files_to_test": ["internal/handlers/subscription_handlers.go", "internal/services/stripe_service.go"]
    },
    "validation_criteria": {
      "critical": ["All tests pass", "User requirements validated", "Stripe integration tested"],
      "expected": ["Error cases tested", "Webhook signature verified in tests"],
      "nice_to_have": ["High coverage", "Idempotency tested"]
    },
    "timeout_seconds": 3600
  },
  {
    "uniqueId": 3,
    "skill_id": "acme/skills/aramb-metadata",
    "task_name": "Create/update aramb.toml",
    "description": "Generate aramb.toml with project services and configuration",
    "task_order": 3,
    "logicalDependencies": [2],
    "inputs": {
      "requirements": "Analyze project structure and create/update aramb.toml",
      "project_path": "."
    },
    "validation_criteria": {
      "critical": ["TOML syntax valid", "Services detected", "Backend and database services configured"],
      "expected": ["Environment vars extracted", "Dependencies mapped"],
      "nice_to_have": ["Service references configured"]
    },
    "timeout_seconds": 1800
  }
])
```

**Step 4: Confirm task creation**
After the MCP tool returns, confirm the tasks were created successfully.

---

## Example 2: Using Sub-tasks for Complex Features

**Input:** "Build a complete e-commerce order management API with orders, inventory, payments, and notifications"

This is a good candidate for sub-tasks because:
- 4 sequential services that build on each other
- User benefits from seeing granular progress
- If service 3 fails, services 1-2 are preserved as checkpoints
- Natural phases: orders (foundation) → inventory → payments → notifications

**Step 1: Search for skills** (same as before)

**Step 2: Output architecture summary (text)**

> **Architecture**: Order management API with 4 services following domain-driven design.
> - **Services**: OrderService, InventoryService, PaymentService, NotificationService
> - **Handlers**: orders.go, inventory.go, payments.go, notifications.go
> - **Models**: Order, OrderItem, InventoryItem, Payment, Notification
> - **Flow**: Order created → Inventory reserved → Payment processed → Notification sent

**Step 3: Create parent task with sub-tasks, then QA task**

```
# First, create the parent task
create_task(
  skill_id: "acme/skills/backend-dev",
  task_name: "Build order management services",
  description: "Create order management API with orders, inventory, payments, and notifications",
  task_order: 1,
  inputs: {
    "requirements": "Complete e-commerce order management API",
    "patterns_to_follow": "See existing services in internal/services/"
  },
  validation_criteria: {
    "critical": ["All services compile", "Migrations run", "Endpoints respond correctly"],
    "expected": ["Auth enforced", "Input validation", "Error handling"],
    "nice_to_have": ["Logging", "Metrics"]
  }
)
→ Returns: parent_task_id

# Then create sub-tasks under the parent
create_subtask(parent_task_id, {
  skill_id: "acme/skills/backend-dev",
  task_name: "Build OrderService",
  description: "Create order service with CRUD operations and order lifecycle management",
  inputs: {
    "files_to_create": ["internal/services/order_service.go", "internal/handlers/orders.go", "migrations/00X_create_orders.sql"],
    "requirements": "Order creation, status updates, history tracking"
  }
})

create_subtask(parent_task_id, {
  skill_id: "acme/skills/backend-dev",
  task_name: "Build InventoryService",
  description: "Create inventory service with stock management and reservation",
  inputs: {
    "files_to_create": ["internal/services/inventory_service.go", "internal/handlers/inventory.go", "migrations/00X_create_inventory.sql"],
    "requirements": "Stock levels, reservations, availability checks"
  }
})

create_subtask(parent_task_id, {
  skill_id: "acme/skills/backend-dev",
  task_name: "Build PaymentService",
  description: "Create payment service with Stripe integration",
  inputs: {
    "files_to_create": ["internal/services/payment_service.go", "internal/handlers/payments.go"],
    "requirements": "Payment processing, refunds, webhook handling"
  }
})

create_subtask(parent_task_id, {
  skill_id: "acme/skills/backend-dev",
  task_name: "Build NotificationService",
  description: "Create notification service for order updates",
  inputs: {
    "files_to_create": ["internal/services/notification_service.go", "internal/handlers/notifications.go"],
    "requirements": "Email notifications, webhook callbacks"
  }
})

# Finally, create the QA task with dependency on parent
create_task(
  skill_id: "acme/skills/backend-testing",
  task_name: "QA: Test order management API",
  description: "Write and run tests for complete order flow. If issues found, fail with feedback for rebuild.",
  task_order: 2,
  dependencies: [parent_task_id],
  inputs: {
    "original_prompt": "Build a complete e-commerce order management API",
    "preceding_task": {
      "task_order": 1,
      "skill_id": "acme/skills/backend-dev",
      "task_name": "Build order management services",
      "description": "Create order management API with orders, inventory, payments, and notifications"
    },
    "user_expectations": [
      "User can create orders",
      "Inventory is reserved on order",
      "Payment is processed",
      "Notifications are sent"
    ]
  },
  validation_criteria: {
    "critical": ["All tests pass", "Complete order flow works end-to-end"],
    "expected": ["Error cases tested", "Concurrent access handled"],
    "nice_to_have": ["High coverage", "Performance tested"]
  }
)
```

**Key differences with sub-tasks:**
- Parent task is created first, then sub-tasks are added to it
- Sub-tasks execute **sequentially** in order (each waits for the previous)
- Sub-tasks inherit context (project_id, user_id, etc.) from parent
- QA task depends on the parent task, not individual sub-tasks
- Parent's `subtasks_completed` flag auto-updates when all sub-tasks complete
- If sub-task 3 fails, sub-tasks 1-2 remain completed (checkpoints)

---

## Example 3: Dynamic Discovery with Sub-tasks

Sub-tasks are also useful when you **don't know the full scope upfront**. The agent can create sub-tasks as it discovers what needs to be done.

**Input:** "Fix the API rate limiting issues"

**Agent workflow:**
1. Create parent task: "Fix rate limiting issues"
2. Investigate the codebase...
3. Discover there are actually 3 separate issues
4. Create sub-tasks dynamically:

```
Parent Task: "Fix rate limiting issues"
  ├── Sub-task 1: "Fix Redis connection pool exhaustion" (created after investigation)
  ├── Sub-task 2: "Fix rate limit not resetting after window" (created after investigation)
  └── Sub-task 3: "Fix missing rate limit headers in response" (created after investigation)
```

This pattern is powerful because:
- Agent doesn't need to know all the work upfront
- Each fix is a checkpoint - if fix 3 fails, fixes 1-2 are preserved
- User sees granular progress as issues are discovered and fixed

---

## Skill Discovery (REQUIRED)

Before creating tasks, search for **3 skills** to build the task plan:

```
# 1. Find a skill to BUILD the feature
search_skills(category: "development", tag: "backend")
→ Use for Task 1: Implementation

# 2. Find a skill to QA/TEST the feature
search_skills(category: "testing", tag: "backend")
→ Use for Task 2: QA
# OR
search_skills(category: "critique", tag: "backend")
→ Use for Task 2: QA (if testing skill not found)

# 3. Find a skill to CREATE/UPDATE metadata
search_skills(category: "development", tag: "metadata")
→ Use for Task 3: Metadata generation
```

Use the `full_id` from search results in your task definitions. The full_id format is `owner/repo/skill-name`.

**Important**: The QA task validates the **user's original requirements** AND its own criteria (coverage, tests meaningful, security). If implementation is broken, QA fails with `feedback_for_rebuild` to trigger the correctness loop.

## The Correctness Loop Explained

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  1. BUILD TASK runs                                             │
│     - Implements feature                                        │
│     - Self-validates: compiles, runs, migrations work           │
│     - Completes successfully                                    │
│                          ↓                                      │
│  2. QA TASK runs                                                │
│     - Writes tests for user requirements                        │
│     - Runs tests                                                 │
│     - Self-validates: tests pass, coverage good, secure         │
│                          ↓                                      │
│  3. QA VERDICT                                                  │
│     ├─ PASS → Done! Feature complete with tests                 │
│     └─ FAIL → Provides `feedback_for_rebuild`                   │
│                          ↓                                      │
│  4. SYSTEM re-triggers BUILD TASK                               │
│     - Build receives QA feedback in inputs                      │
│     - Fixes the issues identified by QA                         │
│     - Loop back to step 1                                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Key points:**
- No separate critique tasks - reduces overhead
- Each task validates itself using `validation_criteria`
- QA task failure triggers rebuild with specific feedback
- Loop continues until QA passes (or max retries exceeded)

## Rules

1. Explore codebase before planning
2. **Search for 3 skills**: development, testing/critique (for QA), and metadata (for aramb.toml)
3. **Choose the right pattern**:
   - Standard 2-task pattern for focused features
   - Parent + sub-tasks pattern for complex work needing checkpoints or dynamic discovery
4. **Use the `full_id` from search results** in task `skill_id` fields - NEVER hardcode skill names
5. **Use MCP tools** to create tasks - do NOT output raw JSON
   - `create_tasks_batch` for standard pattern
   - `create_task` + `create_subtask` for sub-task pattern
6. Include file paths in task inputs
7. Include security requirements for sensitive operations
8. **QA task validates user requirements** AND its own criteria (coverage, security)
9. Sequential `task_order` starting from 1
10. Pass `preceding_task` to QA task so it knows what to validate
11. **Use `uniqueId` and `logicalDependencies`** to define task relationships within a batch:
    - `uniqueId`: Sequential integers (1, 2, ...) to identify tasks
    - `logicalDependencies`: Array of integers referencing other tasks' uniqueId
12. **Sub-tasks cannot have sub-tasks** - only one level of nesting allowed
13. **validation_criteria** defines what each task validates about itself:
    - Build: compiles, runs, migrations work, endpoints respond
    - QA: tests pass, coverage adequate, security tested
