---
name: aramb-skills
description: >
  Search, inspect, and download skills from the Skills Registry using the aramb-skills CLI.
  Available natively at /usr/local/bin/aramb-skills inside all agent runtime containers — no install needed.
  Use when: discovering available skills before creating agents, checking if a skill exists in the registry,
  downloading a skill into an agent workspace, or listing skills by category or tag.
---

# aramb-skills CLI

The `aramb-skills` binary is pre-installed at `/usr/local/bin/aramb-skills` in every agent runtime container. No installation step is needed.

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `ARAMB_API_TOKEN` | — | Bearer token for authenticated access. Required for private skills. |
| `SKILLS_REGISTRY_BASE_URL` | `https://api.clode.space/skills-registry` | Override for local or staging environments. |

Both can also be passed as per-command flags (`--token`, `--base-url`), which take precedence over env vars.

---

## Commands

### `search` — find skills by text, category, or tag

At least one of query text, `--category`, or `--tag` is required.

```bash
# Text search
aramb-skills search "planning"

# Filter by category
aramb-skills search --category planner --limit 5

# Filter by tag with text
aramb-skills search --tag automation "summarize"

# Combined filters, JSON output
aramb-skills search --category planner --tag planning --json
```

Output columns: SKILL (`owner/repo/name`), CATEGORY, AUTHOR, STARS, DL

**Flags:** `--category` (slug), `--tag` (slug), `--limit` (default 20), `--page` (default 1), `--json`

---

### `list` — list all skills with optional filters

```bash
aramb-skills list
aramb-skills list --status approved --limit 10
aramb-skills list --category automation --json
```

**Flags:** `--category`, `--status` (`draft`/`approved`/`pending`), `--limit`, `--page`, `--json`

---

### `featured` — list featured skills

```bash
aramb-skills featured
aramb-skills featured --limit 5 --json
```

---

### `get` — inspect a single skill by full ID

Full ID format: `owner/repo/name`

```bash
aramb-skills get clode-labs/skills-registry/planner
aramb-skills get clode-labs/skills-registry/planner --json
```

Outputs: name, description, category, author, license, compatibility, status, tags, popularity, updated date.

JSON output example:
```json
{
  "success": true,
  "data": {
    "full_id": "clode-labs/skills-registry/planner",
    "name": "Planner",
    "category": "planner",
    "status": "approved",
    "tags": ["planning", "agent"],
    "author_name": "clode-labs"
  }
}
```

---

### `download` — download a skill's files as ZIP and extract to a directory

```bash
# Extract into current directory
aramb-skills download clode-labs/skills-registry/planner

# Extract into a specific directory (created if it doesn't exist)
aramb-skills download clode-labs/skills-registry/planner --output /tmp/skill

# Machine-readable result (stdout) with progress on stderr
aramb-skills download clode-labs/skills-registry/planner --output /tmp/skill --json

# Private skill
ARAMB_API_TOKEN=eyJ... aramb-skills download my-org/private-repo/my-skill --output ./skill
```

JSON stdout on success: `{"success":true,"output":"/tmp/skill"}`

Progress goes to stderr during extraction:
```
Downloading clode-labs/skills-registry/planner...
  SKILL.md
  main.ts
Extracted to /tmp/skill
```

---

### `version` — print binary version

```bash
aramb-skills version
```

---

## Auth Behaviour

| Condition | Endpoint | Access |
|---|---|---|
| No token | `/api/v1/skills/...` | Public skills only |
| `ARAMB_API_TOKEN` set | `/api/v1/me/skills/...` | Public + caller's private skills |

---

## Exit Codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | Error (invalid args, HTTP error, extraction failure) |

---

## Typical Workflow: Download a Skill into an Agent Workspace

Use this when a skill is needed in an agent workspace and not already present in `{{SKILLS_SOURCE}}/`.

```bash
# 1. Search the registry to find the right skill
aramb-skills search --category planner

# 2. Inspect the skill before downloading
aramb-skills get clode-labs/skills-registry/planner

# 3. Download into the agent's skills directory
SKILL_DIR="${DESTINATION}/skills/planner"
aramb-skills download clode-labs/skills-registry/planner --output "$SKILL_DIR" --json

# 4. Verify the download succeeded
[ -f "$SKILL_DIR/SKILL.md" ] || { echo "ERROR: Skill download failed — SKILL.md missing"; exit 1; }
echo "Skill installed at: $SKILL_DIR"
```

## Checking Before Copying

Before copying a skill from `{{SKILLS_SOURCE}}/`, verify it exists there first. If not, fall back to downloading from the registry:

```bash
SKILL_NAME="planner"
SOURCE_DIR="{{SKILLS_SOURCE}}/${SKILL_NAME}"
DEST_DIR="${DESTINATION}/skills/${SKILL_NAME}"

if [ -d "$SOURCE_DIR" ]; then
  cp -r "$SOURCE_DIR" "$DEST_DIR"
  echo "Copied $SKILL_NAME from local source"
else
  echo "$SKILL_NAME not in local source — downloading from registry..."
  aramb-skills search "$SKILL_NAME" --limit 3
  # Inspect and confirm the right skill, then download:
  aramb-skills download clode-labs/skills-registry/"$SKILL_NAME" --output "$DEST_DIR" --json
  [ -f "$DEST_DIR/SKILL.md" ] || { echo "ERROR: Download failed"; exit 1; }
fi
```
