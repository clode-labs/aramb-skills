---
name: create-agent
description: >
  Create new agents with tailored workspace files (IDENTITY.md, SOUL.md, AGENTS.md),
  custom skills, and CLI registration. Use when: (1) setting up a new isolated agent for a
  specific role (coder, tester, deployer, researcher, etc.), (2) scaffolding an agent workspace
  with role-specific persona and instructions, (3) registering an agent via `{{CLI_CREATE}}`.
  NOT for: editing existing agent files (just edit them directly), or creating skills without
  an agent (write SKILL.md files directly).
---

# Create Agent

Create agents with role-specific personas, instructions, and skills.

## What Is an Agent?

An agent is an isolated brain with its own:
- **Workspace** — `workspace-<name>/` containing `IDENTITY.md`, `SOUL.md`, `AGENTS.md`, `skills/`
- **Runtime dir** — `agents/<name>/` containing `memory.db`, `sessions/`
- **Config entry** — model, backend, thinking level in `config.yaml`

All paths are relative to `BENJI_HOME` (default `~/.benji/`).

## Agent Spec (Required Input)

Every agent creation request MUST provide this spec:

```yaml
name: lowercase-hyphen-format        # required — e.g., backend-tester
role: what this agent does            # required — one-line purpose
skills:                               # required — list of skills
  - brahmi                            # string = copy existing skill from master's workspace
  - juno                              # always include — cross-session context memory
  - name: frontend-testing            # object = create new skill
    purpose: "Playwright-based UI testing against locally running stack"
context: |                            # optional — domain knowledge, environment details
  Runs in Docker with Node.js,
  podman, Playwright, xvfb.
```

Do NOT ask the end user for this information. The caller (e.g., master agent) provides the complete spec. If any required field is missing, fail with an error describing what's missing.

## Workflow

**CRITICAL RULE:** Writing files to disk does NOT create an agent. An agent only exists when it is registered in the agent registry. **Step 1 is non-negotiable and MUST be the first bash command you run** — before writing IDENTITY.md, before copying skills, before anything else. If you skip Step 1 and go straight to writing files, you have produced a useless directory that the runtime knows nothing about. The task is failed.

### 1. Register the Agent (FIRST — MANDATORY)

Run this command **before doing anything else**:

```bash
{{CLI_CREATE}} <name> --model claude-opus-4-6 --backend claude-sdk --thinking medium
```

- Use the `{{CLI}}` binary directly — it is on `PATH` in the runtime environment. Do NOT try to invoke the CLI via its source entrypoint; your working directory is the agent workspace, not the source tree, and that form will fail.
- The `{{CLI_CREATE}}` command writes a new entry to `$BENJI_HOME/config.yaml` AND creates default IDENTITY.md/SOUL.md/AGENTS.md in `$BENJI_HOME/workspace-<name>/`. You will overwrite those defaults in Step 3 — that is expected.
- If the command reports `agent already exists`, that is a HARD FAILURE for a fresh creation. Do not continue. Report the conflict so the caller can delete the old agent first. (`{{CLI_DELETE}} <name>` moves it to `.trash/`.)
- After this command succeeds, verify registration by running `{{CLI_LIST}}` and confirming `<name>` appears. If it does not appear, STOP — file writes will not fix this.

### 2. Resolve Skills

Skills live in a **shared build dir** — `{{SKILLS_SOURCE}}/` — not in your own workspace. Your workspace (`workspace-master/skills/`) only contains the subset of skills YOU need to orchestrate. Sub-agents often need skills you don't have (e.g., `backend-testing`, `aramb-toml`, `frontend-testing`). Always resolve from `{{SKILLS_SOURCE}}/`, never from your own workspace.

For each skill in the spec:
- **String** (e.g., `brahmi`, `juno`, `backend-testing`) — copy the skill directory from `{{SKILLS_SOURCE}}/<name>/` to `{{WORKSPACE_ROOT}}/workspace-<agent-name>/skills/<name>/`. Copy the whole directory tree (SKILL.md + any `references/` files). Error if `{{SKILLS_SOURCE}}/<name>/SKILL.md` does not exist.
- **Object** with `name` + `purpose` — create a new skill directory at `{{WORKSPACE_ROOT}}/workspace-<agent-name>/skills/<name>/` with a `SKILL.md` containing YAML frontmatter (`name`, `description`) and body content tailored to the purpose. Do NOT write to `{{SKILLS_SOURCE}}` — that is read-only shared state.

**Default skills (MANDATORY, non-negotiable):** Every agent you create MUST have `brahmi` and `juno` in its skills dir, even if the caller doesn't list them. `brahmi` is how the agent receives tasks, reports status, and sends messages to main chat — without it the agent is deaf and mute. `juno` is how the agent stores and retrieves cross-session context memory — without it every session starts from zero. If these two skills are not present in the new agent's workspace after copy, you have failed the task.

**Verify after copy:** For each skill, confirm `{{WORKSPACE_ROOT}}/workspace-<agent-name>/skills/<skill-name>/SKILL.md` exists and is non-empty. If verification fails, retry the copy once, then error out.

### 3. Write Workspace Files

Write all three files to `workspace-<name>/` with role-specific content. **Never leave templates unfilled.**

#### IDENTITY.md

```markdown
# IDENTITY.md

- **Name:** <agent-name>
- **Creature:** <what it is — e.g., "build daemon", "test harness spirit", "deployment sentinel">
- **Vibe:** <personality — e.g., "precise and methodical", "fast and scrappy">
- **Emoji:** <signature emoji>
```

#### SOUL.md

Tailor to the agent's domain. Include:
- Core purpose and operating philosophy
- How to approach tasks in this domain
- Boundaries specific to the role
- Communication style

See `references/agent-template.md` for the full template structure.

**Key rule:** A tester's soul is different from a deployer's soul. Be specific. Include domain knowledge, priorities, and failure modes the agent should care about.

#### AGENTS.md

Operating instructions for the agent. Include:
- Session startup checklist (read SOUL.md, memory, check Juno context, check pending tasks)
- Task protocol (receive via brahmi → execute → report via `aramb_tasks.update` with the explicit `task_id` from the dispatch prompt)
- Memory conventions (daily logs, what to persist, Juno for cross-session persistence)
- Tools & skills available to this agent
- Safety rules relevant to the domain

### 4. Verify (MANDATORY)

```bash
{{CLI_LIST}}
ls -la $BENJI_HOME/workspace-<name>/
ls -la $BENJI_HOME/workspace-<name>/skills/
```

All three checks must pass:
1. `{{CLI_LIST}}` MUST show `<name>` as a registered agent. If it is missing, Step 1 silently failed — you must re-run it and re-verify. File writes are meaningless without registration.
2. IDENTITY.md, SOUL.md, AGENTS.md must all exist and be non-empty.
3. Every required skill (including the mandatory `brahmi` and `juno`) must have a `SKILL.md` file under `skills/`.

## Quality Checklist

Before finishing, verify ALL of these. If any is unchecked, the task is NOT done:
- [ ] **Agent is registered via `{{CLI_CREATE}}` AND appears in `{{CLI_LIST}}`** (this is the primary success criterion — without it, the agent does not exist)
- [ ] IDENTITY.md is fully filled in (no template placeholders)
- [ ] SOUL.md is role-specific (not generic "be helpful" boilerplate)
- [ ] AGENTS.md includes actionable operating instructions with brahmi task protocol
- [ ] Skills copied or created in `workspace-<name>/skills/`, including mandatory `brahmi` and `juno`
- [ ] Name is lowercase-hyphen format

## References

- `references/agent-template.md` — full workspace file templates with examples
- `references/skill-best-practices.md` — condensed skill creation guidelines
