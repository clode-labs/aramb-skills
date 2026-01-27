---
name: frontend-planner
description: Plan complex frontend work by analyzing requirements and creating executable task sequences. Use this skill when breaking down UI features, component architectures, or frontend integrations into development and QA tasks with self-validation.
category: planner
tags: [frontend, react, typescript, planning, ui]
license: MIT
---

# Frontend Planning

Analyze complex frontend requirements and create executable task plans.

## Process

1. **Explore codebase** - Identify framework, patterns, conventions
2. **Design architecture** - Plan components, state, data flow (output as text summary)
3. **Search for skills** - Use `search_skills` MCP tool to find development and QA skills
4. **Create tasks via MCP** - Use `create_tasks_batch` to create all tasks with dependencies
5. **Confirm creation** - Verify the MCP tool successfully created the tasks

## Task Sequencing Principle

You have **two patterns** to choose from based on complexity:

### Pattern 1: Standard Tasks (Default)
Use when the work is relatively focused and sequential:

```
1. [development skill] → Build the feature (self-validates: compiles, runs, meets requirements)
2. [testing/critique skill] → QA against user expectations (self-validates: coverage, tests pass)
```

**The Correctness Loop:**
- Each task validates itself using its `validation_criteria`
- **Build task** validates: code compiles, runs without errors, meets functional requirements
- **QA task** validates: tests pass, coverage adequate, edge cases covered, tests meaningful
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
  ├── Sub-task 1: "Create [Foundation]"      ← Runs first
  ├── Sub-task 2: "Build [Core Feature]"     ← Waits for 1
  ├── Sub-task 3: "Add [Enhancement]"        ← Waits for 2
  └── Sub-task 4: "Polish and integrate"     ← Waits for 3

QA Task: "Test [Feature]"
  └── dependencies: [parent-task-id]
```

**When to use sub-tasks:**
- Complex feature that benefits from step-by-step decomposition
- Work where you'll discover scope as you go (investigation → fixes)
- You want checkpoints so partial progress survives failures
- Multi-step process with natural phases

**When NOT to use sub-tasks:**
- Simple, focused features that don't need decomposition
- Quick fixes or small enhancements
- Work that's already well-understood and atomic

**Why this simplified pattern:**
- **Build task self-validates**: Code compiles, runs, no errors - immediate feedback
- **QA task self-validates**: Tests written, pass, cover requirements
- **No separate critique tasks**: Eliminates redundant QA layers
- **Correctness loop**: QA failure triggers re-build with specific feedback

**Required skills to search for:**
1. A **development skill** (category: "development", tag: "frontend") - to build the feature
2. A **QA skill** (category: "testing" OR "critique", tag: "frontend") - to test/validate user expectations

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
    "description": "Build the components and logic",
    "task_order": 1,
    "inputs": {
      "requirements": "Specific requirements from original prompt",
      "files_to_create": ["src/components/Feature.tsx"],
      "files_to_modify": ["src/App.tsx"],
      "patterns_to_follow": "Reference to existing code patterns"
    },
    "validation_criteria": {
      "critical": ["TypeScript compiles without errors", "Component renders", "Core functionality works"],
      "expected": ["Loading states handled", "Error states handled", "Responsive design"],
      "nice_to_have": ["Animations", "Optimistic updates"]
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
        "User can do X",
        "User can see Y",
        "Z happens when..."
      ],
      "files_to_test": ["src/components/Feature.tsx"]
    },
    "validation_criteria": {
      "critical": ["Tests pass", "Critical user paths covered", "No broken functionality found"],
      "expected": ["Edge cases tested", "Error states tested"],
      "nice_to_have": ["High coverage", "Performance tested"]
    },
    "timeout_seconds": 3600
  }
])
```

**Logical Dependencies**: Use `uniqueId` (integer) to identify tasks within the batch, and `logicalDependencies` (array of integers) to reference other tasks by their uniqueId. The server validates for circular dependencies and missing references, returning a 400 error if validation fails.

## QA Task Construction

The QA task is responsible for:
1. **Writing tests** that validate user requirements
2. **Running tests** to verify implementation works
3. **Validating its own criteria**: coverage, edge cases, meaningful tests
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
    "expected": ["Edge cases covered"],
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

**IMPORTANT:** The `skill_id` must always be the `full_id` from search results (e.g., `"clode-labs/aramb-skills/frontend-development"`), NOT the short name.

## Example

**Input:** "Build a user profile page with avatar upload"

**Step 1: Search for skills**
```
search_skills(category: "development", tag: "frontend")
→ Returns: full_id: "acme/skills/frontend-dev" (use this)

search_skills(category: "testing", tag: "frontend")
→ Returns: full_id: "acme/skills/frontend-testing" (use this)
# OR
search_skills(category: "critique", tag: "frontend")
→ Returns: full_id: "acme/skills/frontend-critique" (use this)
```

**Step 2: Output architecture summary (text)**

> **Architecture**: Profile page with avatar upload using react-dropzone and API integration.
> - **Components**: ProfilePage (layout), AvatarUpload (drag-drop with preview), ProfileForm (edit fields)
> - **State**: React Query for server state, local state for form
> - **Data flow**: API → React Query → ProfilePage → Child components

**Step 3: Create tasks using MCP**
```
create_tasks_batch(tasks=[
  {
    "uniqueId": 1,
    "skill_id": "acme/skills/frontend-dev",
    "task_name": "Build profile page components",
    "description": "Create ProfilePage, AvatarUpload, and ProfileForm components",
    "task_order": 1,
    "inputs": {
      "requirements": "Profile page with editable fields and avatar upload",
      "files_to_create": ["src/pages/Profile/ProfilePage.tsx", "src/components/AvatarUpload.tsx", "src/components/ProfileForm.tsx"],
      "patterns_to_follow": "See existing pages in src/pages/"
    },
    "validation_criteria": {
      "critical": ["TypeScript compiles", "Page renders without errors", "Form submits", "Avatar upload works"],
      "expected": ["Loading states", "Error handling", "Responsive design"],
      "nice_to_have": ["Image cropping", "Drag feedback animation"]
    },
    "timeout_seconds": 3600
  },
  {
    "uniqueId": 2,
    "skill_id": "acme/skills/frontend-testing",
    "task_name": "QA: Test profile page",
    "description": "Write and run tests for profile page. Validate user can view profile, upload avatar, edit fields, and save changes. If implementation has issues, fail with detailed feedback for rebuild.",
    "task_order": 2,
    "logicalDependencies": [1],
    "inputs": {
      "critiques_tasks": [1],  // ← Triggers correctness loop if verdict=fail
      "original_prompt": "Build a user profile page with avatar upload",
      "preceding_task": {
        "task_order": 1,
        "skill_id": "acme/skills/frontend-dev",
        "task_name": "Build profile page components",
        "description": "Create ProfilePage, AvatarUpload, and ProfileForm components"
      },
      "user_expectations": [
        "User can view their profile",
        "User can upload an avatar image",
        "User can edit profile fields",
        "Changes are saved successfully"
      ],
      "files_to_test": ["src/pages/Profile/ProfilePage.tsx", "src/components/AvatarUpload.tsx"]
    },
    "validation_criteria": {
      "critical": ["All tests pass", "User requirements validated", "Avatar upload tested end-to-end"],
      "expected": ["Form submission tested", "Error states tested"],
      "nice_to_have": ["Edge cases covered", "Accessibility tested"]
    },
    "timeout_seconds": 3600
  }
])
```

**Step 4: Confirm task creation**
After the MCP tool returns, confirm the tasks were created successfully.

---

## Example 2: Using Sub-tasks for Complex Features

**Input:** "Build a multi-step checkout flow with cart review, shipping, payment, and confirmation pages"

This is a good candidate for sub-tasks because:
- 4 sequential steps that build on each other
- User benefits from seeing granular progress
- If step 3 fails, steps 1-2 are preserved as checkpoints
- Natural phases: foundation → each page → integration

**Step 1: Search for skills** (same as before)

**Step 2: Output architecture summary (text)**

> **Architecture**: Multi-step checkout flow with 4 pages using React Router and shared cart context.
> - **Pages**: CartReview, ShippingForm, PaymentForm, Confirmation
> - **Shared**: CheckoutContext (cart state), CheckoutLayout (progress indicator)
> - **Flow**: Cart → Shipping → Payment → Confirmation

**Step 3: Create parent task with sub-tasks, then QA task**

```
# First, create the parent task
create_task(
  skill_id: "acme/skills/frontend-dev",
  task_name: "Build checkout flow pages",
  description: "Create multi-step checkout with cart, shipping, payment, and confirmation",
  task_order: 1,
  inputs: {
    "requirements": "Multi-step checkout flow with 4 pages",
    "patterns_to_follow": "See existing pages in src/pages/"
  },
  validation_criteria: {
    "critical": ["All 4 pages render", "Navigation between steps works", "Cart state persists"],
    "expected": ["Form validation", "Loading states", "Error handling"],
    "nice_to_have": ["Progress indicator", "Back navigation"]
  }
)
→ Returns: parent_task_id

# Then create sub-tasks under the parent
create_subtask(parent_task_id, {
  skill_id: "acme/skills/frontend-dev",
  task_name: "Build CartReview page",
  description: "Create cart review page showing items, quantities, and totals",
  inputs: {
    "files_to_create": ["src/pages/Checkout/CartReview.tsx"],
    "requirements": "Display cart items with edit/remove, show totals"
  }
})

create_subtask(parent_task_id, {
  skill_id: "acme/skills/frontend-dev",
  task_name: "Build ShippingForm page",
  description: "Create shipping address form with validation",
  inputs: {
    "files_to_create": ["src/pages/Checkout/ShippingForm.tsx"],
    "requirements": "Address form with validation, save to context"
  }
})

create_subtask(parent_task_id, {
  skill_id: "acme/skills/frontend-dev",
  task_name: "Build PaymentForm page",
  description: "Create payment form with card input",
  inputs: {
    "files_to_create": ["src/pages/Checkout/PaymentForm.tsx"],
    "requirements": "Card input with validation, integrate payment provider"
  }
})

create_subtask(parent_task_id, {
  skill_id: "acme/skills/frontend-dev",
  task_name: "Build Confirmation page",
  description: "Create order confirmation with summary",
  inputs: {
    "files_to_create": ["src/pages/Checkout/Confirmation.tsx"],
    "requirements": "Show order summary, confirmation number, next steps"
  }
})

# Finally, create the QA task with dependency on parent
create_task(
  skill_id: "acme/skills/frontend-testing",
  task_name: "QA: Test checkout flow",
  description: "Write and run tests for complete checkout flow. If issues found, fail with feedback for rebuild.",
  task_order: 2,
  dependencies: [parent_task_id],
  inputs: {
    "original_prompt": "Build a multi-step checkout flow",
    "preceding_task": {
      "task_order": 1,
      "skill_id": "acme/skills/frontend-dev",
      "task_name": "Build checkout flow pages",
      "description": "Create multi-step checkout with cart, shipping, payment, and confirmation"
    },
    "user_expectations": [
      "User can review cart",
      "User can enter shipping address",
      "User can enter payment info",
      "User sees confirmation after purchase"
    ]
  },
  validation_criteria: {
    "critical": ["All tests pass", "Complete flow works end-to-end"],
    "expected": ["Form validation tested", "Error states tested"],
    "nice_to_have": ["Edge cases covered"]
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

**Input:** "Fix the broken form validation"

**Agent workflow:**
1. Create parent task: "Fix form validation issues"
2. Investigate the codebase...
3. Discover there are actually 3 separate issues
4. Create sub-tasks dynamically:

```
Parent Task: "Fix form validation issues"
  ├── Sub-task 1: "Fix email regex pattern" (created after investigation)
  ├── Sub-task 2: "Fix required field not triggering on blur" (created after investigation)
  └── Sub-task 3: "Fix error message not clearing on valid input" (created after investigation)
```

This pattern is powerful because:
- Agent doesn't need to know all the work upfront
- Each fix is a checkpoint - if fix 3 fails, fixes 1-2 are preserved
- User sees granular progress as issues are discovered and fixed

---

## Skill Discovery (REQUIRED)

Before creating tasks, search for **2 skills** to build the task plan:

```
# 1. Find a skill to BUILD the feature
search_skills(category: "development", tag: "frontend")
→ Use for Task 1: Implementation

# 2. Find a skill to QA/TEST the feature
search_skills(category: "testing", tag: "frontend")
→ Use for Task 2: QA
# OR
search_skills(category: "critique", tag: "frontend")
→ Use for Task 2: QA (if testing skill not found)
```

Use the `full_id` from search results in your task definitions. The full_id format is `owner/repo/skill-name`.

**Important**: The QA task validates the **user's original requirements** AND its own criteria (coverage, tests meaningful, edge cases). If implementation is broken, QA fails with `feedback_for_rebuild` to trigger the correctness loop.

## The Correctness Loop Explained

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  1. BUILD TASK runs                                             │
│     - Implements feature                                        │
│     - Self-validates: compiles, runs, no errors                 │
│     - Completes successfully                                    │
│                          ↓                                      │
│  2. QA TASK runs                                                │
│     - Writes tests for user requirements                        │
│     - Runs tests                                                 │
│     - Self-validates: tests pass, coverage good, meaningful     │
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
2. **Search for 2 skills**: development and testing/critique (for QA)
3. **Choose the right pattern**:
   - Standard 2-task pattern for focused features
   - Parent + sub-tasks pattern for complex work needing checkpoints or dynamic discovery
4. **Use the `full_id` from search results** in task `skill_id` fields - NEVER hardcode skill names
5. **Use MCP tools** to create tasks - do NOT output raw JSON
   - `create_tasks_batch` for standard pattern
   - `create_task` + `create_subtask` for sub-task pattern
6. Include file paths in task inputs
7. Reference existing patterns
8. **QA task validates user requirements** AND its own criteria (coverage, meaningfulness)
9. Sequential `task_order` starting from 1
10. Pass `preceding_task` to QA task so it knows what to validate
11. **Use `uniqueId` and `logicalDependencies`** to define task relationships within a batch:
    - `uniqueId`: Sequential integers (1, 2, ...) to identify tasks
    - `logicalDependencies`: Array of integers referencing other tasks' uniqueId
12. **Sub-tasks cannot have sub-tasks** - only one level of nesting allowed
13. **validation_criteria** defines what each task validates about itself:
    - Build: compiles, runs, meets functional requirements
    - QA: tests pass, coverage adequate, tests meaningful
