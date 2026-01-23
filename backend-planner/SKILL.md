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
2. **Design architecture** - Plan endpoints, models, services
3. **Create tasks** - Break down into sequenced, executable units with validation

## Task Sequencing Principle

For each unit of work, follow the **maker → checker** pattern:

```
[implementation skill] → [critique skill] → [next implementation] → [critique skill] → ...
```

The critique task always follows its corresponding implementation task and validates that specific work.

## Output Format

```json
{
  "status": "planned",
  "category": "backend",
  "architecture": {
    "summary": "Solution overview",
    "endpoints": [
      {"method": "POST", "path": "/api/v1/resource", "purpose": "What it does", "auth": "required | public"}
    ],
    "data_models": [
      {"name": "ModelName", "purpose": "What it represents", "table": "table_name", "key_fields": ["id", "created_at"]}
    ],
    "services": ["ServiceName - purpose"],
    "external_integrations": ["External services needed"]
  },
  "tasks": [
    {
      "task_name": "Implement [Feature]",
      "description": "Build the API and services",
      "skill_id": "<implementation-skill-id>",
      "task_order": 1,
      "dependencies": [],
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
      "task_name": "QA: Validate [Feature] implementation",
      "description": "Review the implementation against requirements",
      "skill_id": "backend-critique",
      "task_order": 2,
      "dependencies": [1],
      "inputs": {
        "original_prompt": "The user's original request",
        "preceding_task": {
          "task_order": 1,
          "skill_id": "<skill-id-from-task-1>",
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
  ]
}
```

## Critique Task Construction

When creating a critique task, include `preceding_task` in inputs:

```json
{
  "inputs": {
    "original_prompt": "User's original request",
    "preceding_task": {
      "task_order": <order of task being validated>,
      "skill_id": "<skill that produced the work>",
      "task_name": "<name of that task>",
      "description": "<what that task did>"
    },
    "validation_criteria": { ... }
  }
}
```

This tells the critique skill:
- **What skill produced the work** - so it knows the domain and can apply appropriate validation
- **What the task was supposed to do** - so it can verify the work matches intent
- **What criteria to check** - explicit validation requirements

## Example

**Input:** "Build subscription API with Stripe"

```json
{
  "status": "planned",
  "category": "backend",
  "architecture": {
    "summary": "Subscription API with Stripe integration and webhook handling",
    "endpoints": [
      {"method": "POST", "path": "/api/v1/subscriptions", "purpose": "Create subscription", "auth": "required"},
      {"method": "GET", "path": "/api/v1/subscriptions", "purpose": "Get status", "auth": "required"},
      {"method": "POST", "path": "/api/v1/webhooks/stripe", "purpose": "Handle Stripe events", "auth": "public"}
    ],
    "data_models": [
      {"name": "Subscription", "purpose": "Track subscription state", "table": "subscriptions", "key_fields": ["id", "user_id", "stripe_subscription_id", "status"]}
    ],
    "services": ["SubscriptionService - lifecycle management", "StripeService - API wrapper"],
    "external_integrations": ["Stripe API"]
  },
  "tasks": [
    {
      "task_name": "Build subscription service",
      "description": "Create migrations, models, services, and handlers",
      "skill_id": "backend-development",
      "task_order": 1,
      "dependencies": [],
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
      "task_name": "QA: Validate subscription API",
      "description": "Review subscription implementation for correctness and security",
      "skill_id": "backend-critique",
      "task_order": 2,
      "dependencies": [1],
      "inputs": {
        "original_prompt": "Build subscription API with Stripe",
        "preceding_task": {
          "task_order": 1,
          "skill_id": "backend-development",
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
      "task_name": "Write subscription tests",
      "description": "Integration tests with mocked Stripe",
      "skill_id": "backend-testing",
      "task_order": 3,
      "dependencies": [2],
      "inputs": {
        "requirements": "Test happy paths, errors, and webhook handling",
        "files_to_test": ["internal/handlers/subscription_handlers.go", "internal/services/stripe_service.go"],
        "test_types": ["unit", "integration"]
      },
      "validation_criteria": {
        "critical": ["Tests pass", "Core flows covered"],
        "expected": ["Error cases tested", "Webhook signature tested"],
        "nice_to_have": []
      },
      "timeout_seconds": 3600
    },
    {
      "task_name": "QA: Validate subscription tests",
      "description": "Review test quality and coverage",
      "skill_id": "backend-critique",
      "task_order": 4,
      "dependencies": [3],
      "inputs": {
        "original_prompt": "Build subscription API with Stripe",
        "preceding_task": {
          "task_order": 3,
          "skill_id": "backend-testing",
          "task_name": "Write subscription tests",
          "description": "Integration tests with mocked Stripe"
        },
        "validation_criteria": {
          "critical": ["Tests pass", "Core flows covered"],
          "expected": ["Error cases tested", "Webhook signature tested"],
          "nice_to_have": []
        }
      },
      "validation_criteria": {
        "critical": ["Returns structured verdict"],
        "expected": [],
        "nice_to_have": []
      },
      "timeout_seconds": 1800
    }
  ]
}
```

## Rules

1. Explore codebase before planning
2. Output valid JSON only
3. Include file paths in task inputs
4. Include security requirements for sensitive operations
5. Always include critique after each implementation task
6. Sequential `task_order` starting from 1
7. Pass `preceding_task` to critique tasks so they know what they're validating
8. Copy `validation_criteria` from implementation task to its corresponding critique task
