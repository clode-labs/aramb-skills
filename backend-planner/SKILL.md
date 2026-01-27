---
name: backend-planner
description: Plan complex backend work by analyzing requirements and creating executable task sequences. Use this skill when breaking down API features, service architectures, database changes, or backend integrations into development, testing, and validation tasks.
category: planner
tags: [backend, api, golang, python, planning, server]
license: MIT
---

# Backend Planning

Analyze complex backend requirements and create executable task plans.

## Process

1. **Explore codebase** - Identify language, framework, conventions
2. **Design architecture** - Plan endpoints, models, services (output as text summary)
3. **Search for skills** - Use `search_skills` MCP tool to find development, testing, and critique skills
4. **Create tasks via MCP** - Use `create_tasks_batch` to create all tasks with dependencies
5. **Confirm creation** - Verify the MCP tool successfully created the tasks

## Task Sequencing Principle

You have **two patterns** to choose from based on complexity:

### Pattern 1: Standard Tasks (Default)
Use when the work is relatively focused and sequential:

```
1. [implementation skill] → Build the feature
2. [critique skill]       → Review the implementation
3. [testing skill]        → Test against user expectations
4. [critique skill]       → Review the test coverage
```

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

Separate Review Task: "Validate [Feature] Implementation"
  └── dependencies: [parent-task-id]
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

**Why this pattern:**
- **Implementation + Critique**: Ensures the code is correct, follows patterns, and meets requirements
- **Testing + Critique**: Ensures tests actually validate what the user asked for, not just what was built

**Required skills to search for:**
1. A **development skill** (category: "development", tag: "backend") - to build the feature
2. A **critique skill** (category: "critique", tag: "backend") - to review work (used twice)
3. A **testing skill** (category: "testing", tag: "backend") - to write tests validating user expectations

## Task Creation with MCP

After exploring the codebase, designing the architecture, and searching for skills, use the `create_tasks_batch` MCP tool to create all tasks at once.

**Architecture Summary**: Before creating tasks, output a brief text summary of your planned architecture. This provides context for the tasks.

**Task Creation**: Use `create_tasks_batch` with dependency placeholders (`$1`, `$2`, etc.) to reference tasks by their position in the batch:

```
create_tasks_batch(tasks=[
  {
    "skill_id": "<full_id from search>",
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
      "critical": ["Must-pass criteria for this task"],
      "expected": ["Should-pass criteria"],
      "nice_to_have": ["Optional improvements"]
    },
    "timeout_seconds": 3600
  },
  {
    "skill_id": "<critique-full_id from search>",
    "task_name": "QA: Validate [Feature] implementation",
    "description": "Review the implementation against requirements",
    "task_order": 2,
    "dependencies": ["$1"],
    "inputs": {
      "original_prompt": "The user's original request",
      "preceding_task": {
        "task_order": 1,
        "skill_id": "<full_id-from-task-1>",
        "task_name": "<task-name-from-task-1>",
        "description": "<description-from-task-1>"
      },
      "validation_criteria": {
        "critical": ["Same criteria passed to task 1"],
        "expected": ["Same criteria"],
        "nice_to_have": ["Same criteria"]
      }
    },
    "validation_criteria": {
      "critical": ["Returns structured verdict with actionable feedback"],
      "expected": [],
      "nice_to_have": []
    },
    "timeout_seconds": 1800
  }
])
```

**Dependency Placeholders**: Use `$1`, `$2`, etc. to reference tasks by their position in the batch (1-indexed). The system resolves these to actual task IDs after creation.

## Critique Task Construction

When creating a critique task, include `preceding_task` in inputs:

```json
{
  "inputs": {
    "original_prompt": "User's original request",
    "preceding_task": {
      "task_order": <order of task being validated>,
      "skill_id": "<full_id of the skill that produced the work>",
      "task_name": "<name of that task>",
      "description": "<what that task did>"
    },
    "validation_criteria": { ... }
  }
}
```

**IMPORTANT:** The `skill_id` must always be the `full_id` from search results (e.g., `"clode-labs/aramb-skills/backend-development"`), NOT the short name.

This tells the critique skill:
- **What skill produced the work** - so it knows the domain and can apply appropriate validation
- **What the task was supposed to do** - so it can verify the work matches intent
- **What criteria to check** - explicit validation requirements

## Example

**Input:** "Build subscription API with Stripe"

**Step 1: Search for skills**
```
search_skills(category: "development", tag: "backend")
→ Returns: full_id: "acme/skills/backend-dev" (use this)

search_skills(category: "critique", tag: "backend")
→ Returns: full_id: "acme/skills/backend-critique" (use this)

search_skills(category: "testing", tag: "backend")
→ Returns: full_id: "acme/skills/backend-testing" (use this)
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
    "skill_id": "acme/skills/backend-dev",
    "task_name": "Build subscription service",
    "description": "Create migrations, models, services, and handlers",
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
      "critical": ["Migration runs", "Endpoints work", "Webhook signature verification"],
      "expected": ["Auth enforced", "Input validation", "Error handling"],
      "nice_to_have": ["Logging"]
    },
    "timeout_seconds": 3600
  },
  {
    "skill_id": "acme/skills/backend-critique",
    "task_name": "QA: Validate subscription API",
    "description": "Review subscription implementation for correctness and security",
    "task_order": 2,
    "dependencies": ["$1"],
    "inputs": {
      "original_prompt": "Build subscription API with Stripe",
      "preceding_task": {
        "task_order": 1,
        "skill_id": "acme/skills/backend-dev",
        "task_name": "Build subscription service",
        "description": "Create migrations, models, services, and handlers"
      },
      "validation_criteria": {
        "critical": ["Migration runs", "Endpoints work", "Webhook signature verification"],
        "expected": ["Auth enforced", "Input validation", "Error handling"],
        "nice_to_have": ["Logging"]
      }
    },
    "validation_criteria": {
      "critical": ["Returns structured verdict", "Security issues identified"],
      "expected": [],
      "nice_to_have": []
    },
    "timeout_seconds": 1800
  },
  {
    "skill_id": "acme/skills/backend-testing",
    "task_name": "Test subscription API against user requirements",
    "description": "Write tests that validate the USER's original request: subscription API with Stripe. Tests should prove the feature works as the user expects.",
    "task_order": 3,
    "dependencies": ["$2"],
    "inputs": {
      "original_prompt": "Build subscription API with Stripe",
      "user_expectations": [
        "User can create a subscription",
        "User can check subscription status",
        "Stripe webhooks are handled correctly",
        "Subscription state is persisted"
      ],
      "files_to_test": ["internal/handlers/subscription_handlers.go", "internal/services/stripe_service.go"],
      "test_types": ["unit", "integration"]
    },
    "validation_criteria": {
      "critical": ["Tests validate user requirements", "Stripe integration works end-to-end"],
      "expected": ["Error cases tested", "Webhook signature verified"],
      "nice_to_have": ["Edge cases covered"]
    },
    "timeout_seconds": 3600
  },
  {
    "skill_id": "acme/skills/backend-critique",
    "task_name": "QA: Validate tests cover user requirements",
    "description": "Review that tests actually validate what the user asked for, not just implementation details",
    "task_order": 4,
    "dependencies": ["$3"],
    "inputs": {
      "original_prompt": "Build subscription API with Stripe",
      "preceding_task": {
        "task_order": 3,
        "skill_id": "acme/skills/backend-testing",
        "task_name": "Test subscription API against user requirements",
        "description": "Write tests that validate the USER's original request"
      },
      "validation_criteria": {
        "critical": ["Tests validate user requirements", "Stripe integration works end-to-end"],
        "expected": ["Error cases tested", "Webhook signature verified"],
        "nice_to_have": ["Edge cases covered"]
      },
      "focus": "Do the tests prove the user got what they asked for?"
    },
    "validation_criteria": {
      "critical": ["Tests cover user's actual requirements", "Not just implementation smoke tests"],
      "expected": [],
      "nice_to_have": []
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

**Step 3: Create parent task with sub-tasks, then review task**

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
    "critical": ["All services implemented", "Database migrations work", "Endpoints respond correctly"],
    "expected": ["Authentication enforced", "Input validation", "Error handling"],
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

# Finally, create the review task with dependency on parent
create_task(
  skill_id: "acme/skills/backend-critique",
  task_name: "QA: Validate order management API",
  description: "Review the complete order management implementation",
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
    "validation_criteria": {
      "critical": ["All services implemented", "Database migrations work", "Endpoints respond correctly"],
      "expected": ["Authentication enforced", "Input validation", "Error handling"],
      "nice_to_have": ["Logging", "Metrics"]
    }
  }
)
```

**Key differences with sub-tasks:**
- Parent task is created first, then sub-tasks are added to it
- Sub-tasks execute **sequentially** in order (each waits for the previous)
- Sub-tasks inherit context (project_id, user_id, etc.) from parent
- Review task depends on the parent task, not individual sub-tasks
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

Before creating tasks, search for exactly **3 skills** to build the 4-task plan:

```
# 1. Find a skill to BUILD the feature
search_skills(category: "development", tag: "backend")
→ Use for Task 1: Implementation

# 2. Find a skill to REVIEW work
search_skills(category: "critique", tag: "backend")
→ Use for Task 2: Review implementation
→ Use for Task 4: Review tests

# 3. Find a skill to TEST against user expectations
search_skills(category: "testing", tag: "backend")
→ Use for Task 3: Write tests that validate what the USER asked for
```

Use the `full_id` from search results in your task definitions. The full_id format is `owner/repo/skill-name`.

**Important**: The testing task should validate the **user's original requirements**, not just test that the implementation works. The tests prove the user got what they asked for.

## Rules

1. Explore codebase before planning
2. **Search for 3 skills**: development, critique, and testing
3. **Choose the right pattern**:
   - Standard 4-task pattern for focused features
   - Parent + sub-tasks pattern for complex work needing checkpoints or dynamic discovery
4. **Use the `full_id` from search results** in task `skill_id` fields - NEVER hardcode skill names
5. **Use MCP tools** to create tasks - do NOT output raw JSON
   - `create_tasks_batch` for standard pattern
   - `create_task` + `create_subtask` for sub-task pattern
6. Include file paths in task inputs
7. Include security requirements for sensitive operations
8. **Testing task must validate USER requirements** - not just test that code runs
9. Sequential `task_order` starting from 1
10. Pass `preceding_task` to critique tasks so they know what they're validating
11. Copy `validation_criteria` from implementation task to its corresponding critique task
12. Use dependency placeholders (`$1`, `$2`, etc.) to reference tasks within the batch
13. **Sub-tasks cannot have sub-tasks** - only one level of nesting allowed
