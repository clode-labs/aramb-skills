---
name: frontend-planner
description: Plan complex frontend work by analyzing requirements and creating executable task sequences. Use this skill when breaking down UI features, component architectures, or frontend integrations into development, testing, and validation tasks.
category: planner
tags: [frontend, react, typescript, planning, ui]
license: MIT
---

# Frontend Planning

Analyze complex frontend requirements and create executable task plans.

## Process

1. **Explore codebase** - Identify framework, patterns, conventions
2. **Design architecture** - Plan components, state, data flow
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
  "category": "frontend",
  "architecture": {
    "summary": "Solution overview",
    "components": [
      {
        "name": "ComponentName",
        "purpose": "What it does",
        "location": "src/components/path/",
        "dependencies": ["OtherComponent", "useHook"]
      }
    ],
    "state_management": "How state is managed",
    "data_flow": "How data flows through components"
  },
  "tasks": [
    {
      "task_name": "Implement [Feature]",
      "description": "Build the components and logic",
      "skill_id": "<implementation-skill-id>",
      "task_order": 1,
      "dependencies": [],
      "inputs": {
        "requirements": "Specific requirements from original prompt",
        "files_to_create": ["src/components/Feature.tsx"],
        "files_to_modify": ["src/App.tsx"],
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
      "skill_id": "frontend-critique",
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

**Input:** "Build a user profile page with avatar upload"

```json
{
  "status": "planned",
  "category": "frontend",
  "architecture": {
    "summary": "Profile page with avatar upload using react-dropzone and API integration",
    "components": [
      {"name": "ProfilePage", "purpose": "Layout and data orchestration", "location": "src/pages/Profile/", "dependencies": ["AvatarUpload", "ProfileForm"]},
      {"name": "AvatarUpload", "purpose": "Drag-drop avatar with preview", "location": "src/components/", "dependencies": ["react-dropzone"]},
      {"name": "ProfileForm", "purpose": "Edit profile fields", "location": "src/components/", "dependencies": ["react-hook-form"]}
    ],
    "state_management": "React Query for server state, local state for form",
    "data_flow": "API → React Query → ProfilePage → Child components"
  },
  "tasks": [
    {
      "task_name": "Build profile page components",
      "description": "Create ProfilePage, AvatarUpload, and ProfileForm components",
      "skill_id": "frontend-development",
      "task_order": 1,
      "dependencies": [],
      "inputs": {
        "requirements": "Profile page with editable fields and avatar upload",
        "files_to_create": ["src/pages/Profile/ProfilePage.tsx", "src/components/AvatarUpload.tsx", "src/components/ProfileForm.tsx"],
        "patterns_to_follow": "See existing pages in src/pages/"
      },
      "validation_criteria": {
        "critical": ["Page renders", "Form submits", "Avatar uploads"],
        "expected": ["Loading states", "Error handling", "Responsive"],
        "nice_to_have": ["Image cropping", "Drag feedback"]
      },
      "timeout_seconds": 3600
    },
    {
      "task_name": "QA: Validate profile page implementation",
      "description": "Review profile components against requirements",
      "skill_id": "frontend-critique",
      "task_order": 2,
      "dependencies": [1],
      "inputs": {
        "original_prompt": "Build a user profile page with avatar upload",
        "preceding_task": {
          "task_order": 1,
          "skill_id": "frontend-development",
          "task_name": "Build profile page components",
          "description": "Create ProfilePage, AvatarUpload, and ProfileForm components"
        },
        "validation_criteria": {
          "critical": ["Page renders", "Form submits", "Avatar uploads"],
          "expected": ["Loading states", "Error handling", "Responsive"],
          "nice_to_have": ["Image cropping", "Drag feedback"]
        }
      },
      "validation_criteria": {
        "critical": ["Returns structured verdict"],
        "expected": [],
        "nice_to_have": []
      },
      "timeout_seconds": 1800
    },
    {
      "task_name": "Write tests for profile page",
      "description": "Unit tests for components, integration test for upload flow",
      "skill_id": "frontend-testing",
      "task_order": 3,
      "dependencies": [2],
      "inputs": {
        "requirements": "Test profile page functionality",
        "files_to_test": ["src/pages/Profile/ProfilePage.tsx", "src/components/AvatarUpload.tsx"],
        "test_types": ["unit", "integration"]
      },
      "validation_criteria": {
        "critical": ["Tests pass", "Upload flow tested"],
        "expected": ["Form validation tested", "Error states tested"],
        "nice_to_have": []
      },
      "timeout_seconds": 3600
    },
    {
      "task_name": "QA: Validate profile page tests",
      "description": "Review test quality and coverage",
      "skill_id": "frontend-critique",
      "task_order": 4,
      "dependencies": [3],
      "inputs": {
        "original_prompt": "Build a user profile page with avatar upload",
        "preceding_task": {
          "task_order": 3,
          "skill_id": "frontend-testing",
          "task_name": "Write tests for profile page",
          "description": "Unit tests for components, integration test for upload flow"
        },
        "validation_criteria": {
          "critical": ["Tests pass", "Upload flow tested"],
          "expected": ["Form validation tested", "Error states tested"],
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
4. Reference existing patterns
5. Always include critique after each implementation task
6. Sequential `task_order` starting from 1
7. Pass `preceding_task` to critique tasks so they know what they're validating
8. Copy `validation_criteria` from implementation task to its corresponding critique task
