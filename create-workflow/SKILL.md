---
name: create-workflow
description: >
  Author a brand-new workflow definition (no workflow exists yet). Two dispatch
  channels: (1) task dispatch — the master consolidates the application's user
  tasks into a reusable workflow; (2) chat dispatch — author from the user's
  explicit description or the work done so far in this conversation (the master in
  team mode, or the solo agent in solo mode). Each node gets an agent for its role
  the SAME way in solo and team — reuse an existing agent, or author the sub-agent's
  full spec INLINE on the workflow via `agent_specs`; mode affects only close-out
  (chat vs tasks), never how nodes get their agents.
  Use when: asked to create a workflow from prior tasks, "build a workflow
  that…", "create a workflow based on the work done so far in this chat", or told
  to use the create-workflow skill. NOT for: editing an existing workflow (use
  update-workflow), polishing a template import (use import-workflow), executing
  or scheduling workflows.
---

# Create Workflow

Construct a brand-new workflow and save it with `aramb_workflows.create`. **The
workflow does NOT exist yet** — brahmi creates the row + nodes atomically on that
one call. Don't ask for a `workflow_id`; you don't have one and don't need one.
The response tells you the id brahmi assigned.

> **If asked to UPDATE an existing workflow, use the `update-workflow` skill. If
> polishing a template-import draft, use `import-workflow`.** This skill only
> handles first-time creation.

## Non-negotiables — read these before you call `aramb_workflows.create`

0. **The workflow belongs to exactly ONE agent — either create it with `agent_id`, or
   attach it to an agent once the agent exists.** A workflow is an integral part of a
   single agent: discoverable and runnable ONLY by that agent, never a standalone,
   reusable-across-agents asset. **Two equally-valid orderings** get you there:
   - **Agent-first (default):** the agent already exists (or you create it first), so
     pass `agent_id="<that agent's id>"` on `aramb_workflows.create`. That one call
     creates the workflow AND stamps the ownership edge (create-and-link in one step).
   - **Workflow-first:** the builder wants to design and TEST the workflow before
     committing to an agent. That's fine — build it, iterate and Preview it on its own,
     then when they create (or pick) the agent, link it with
     `aramb_agents.attach_workflow` (the `agent_id` gets stamped and the workflow is
     re-filed under the agent's template project). Attach and create-with-`agent_id`
     **converge on the same end state** — owned by and filed under the agent.
   If a workflow is **meant for a specific agent**, don't leave it permanently unattached —
   bind it via `agent_id` at create time, or `aramb_agents.attach_workflow` once the agent
   exists. A workflow that is **not** tied to a particular agent is fine to leave standalone;
   binding is only for the ones that belong to an agent.

1. **Every `create` is a NEW, separate workflow. NEVER replace an existing one.**
   A project can hold many workflows side by side — `aramb_workflows.create` always
   adds a new one; it never touches what's already there. If the user says "create
   a workflow" and one already exists, you still **create a new one** — do NOT fall
   back to `aramb_workflows.update`, and do NOT overwrite the existing workflow's
   definition. The ONLY time you modify an existing workflow is when the user
   explicitly asks to *change/edit* that specific one — and then you use the
   `update-workflow` skill, never this one. Silently replacing a user's workflow is
   a serious failure.

2. **The workflow is part of the agent you're building, and stays a DRAFT — do NOT
   publish it as a build step.** `aramb_workflows.create` files the workflow under the
   agent (via `agent_id`, see #0) and leaves it a **draft** — it is NOT auto-published.
   The builder TESTS the draft via Preview (`aramb_workflows.run` works on the draft —
   see the `aramb-workflows` run section), and the workflow freezes into its live
   version **automatically when the AGENT is published** (`aramb_agents.publish`).
   There is **no separate "publish this workflow" step** for you to perform — never
   call a workflow-publish tool as part of building, and never tell the user to
   "publish from the Workflows tab" (that step does not exist in this model).
   Toolkit connections matter in **two** ways. (a) For a *run* to succeed — verify every
   external system up front with `aramb_toolkits.check_connection` and tell the user
   plainly which to connect. (b) **For the workflow to go LIVE at publish** — when the
   agent is published, a workflow whose steps require third-party toolkits is published
   ONLY if those toolkits are **CONNECTED**; otherwise it stays a draft and the publish
   response reports it as blocked, naming the missing toolkits. So when a workflow you
   built needs a toolkit, tell the builder which toolkits it requires and that they must
   be CONNECTED for it to go live: "The workflow ships when you publish the agent — but
   only once its toolkits are connected. Connect them on the **Integrations** page, then
   click Publish." Never call a toolkit-using workflow "live" before its toolkits are
   connected **and** the agent is published.

3. **Never claim a workflow ran unless the run tool said so.** When the user asks to
   run a workflow, call `aramb_workflows.run` and read its result. If it returns an
   error (e.g. "not published", wrong id), report THAT — do not say "it's running",
   and never substitute a different workflow to make the action appear to succeed.
   Run exactly the workflow the user named; if you can't, say why. **And once a run
   starts, hand off to it — brahmi posts real progress and the final result to the
   conversation automatically, so never narrate fabricated progress ("4/382 scored,
   working through the rest…") you can't verify.** The conversation thread is the
   source of truth for run progress; `aramb_workflows.get` / `list` report only the
   workflow's definition/lifecycle state, not per-step run progress. See the
   `aramb-workflows` skill's run section.

## Two things to figure out first — read this before anything else

There are **two independent axes**. Do NOT conflate them — confusing them is what
makes workflows come out wrong. The crucial correction: **mode (team vs solo)
does NOT decide a node's persona. The WORK each node does decides it.**

### Axis 1 — Are you the MASTER (team) or the SOLO agent? → decides only the dispatch channel, NOT personas

Check your own tool list:
- **You HAVE the `aramb_tasks.*` tools → you are the MASTER (team mode).** You route
  work through tasks and close via `aramb_tasks.update`.
- **You do NOT have `aramb_tasks.*` → you are the SOLO agent (solo mode).** You do
  the work directly in-session and close out in chat.

**That is the ONLY difference between the modes** — close-out channel (tasks vs
chat). Both modes have the full MCP surface (toolkits, triggers, browser) and
author per-role sub-agents the same way — INLINE on the workflow via `agent_specs`.
**Assigning a node's agent works IDENTICALLY in both modes** — solo vs team does
not enter into the persona decision at all. See "Per-node persona — decided by the
work" below.

### Axis 2 — Task dispatch or chat dispatch? → decides spec source + close-out

- **Task dispatch:** brahmi gave you a "Your task id" block (`application_id`,
  `project_id`, `task_id`). Spec source = the application's **user tasks**
  (`aramb_tasks.list`, ALL statuses — see step 1); each node may carry a
  `source_task_id`. Close out via `aramb_tasks.update`. (Only the master is ever
  task-dispatched.)
- **Chat dispatch:** no `task_id` — an ordinary chat turn. Spec source = the
  user's explicit description, or the work done so far in THIS conversation. Close
  out by **replying in chat** (brahmi persists your final assistant text).

**The axes cross.** The **master can be in chat dispatch** — you just chatted
"build a workflow" to it; that's still team mode (you route through tasks and
close via `aramb_tasks.update`). (The brahmi `task_id` is NOT Claude's built-in
`TaskCreate` — unrelated; a `TaskCreate` entry does not make this a task
dispatch.)

### Per-node persona — decided by the work (both modes)

**Every node gets an agent suited to that node's role — and this is decided
IDENTICALLY whether you are solo or master. Mode does NOT affect this at all.** A
workflow node is a distinct unit of work; give it an agent that owns that work.

For each node, assign an agent for its role in ONE of two ways:

- **Reuse an existing agent if one already fits the role** — e.g. a roster
  persona that's already provisioned (`developer` for code / clone / implement,
  `backend-tester` / `frontend-tester` / `integration-tester` / `checker` for
  verify / review, `aramb-deployer` / `local-deployer` for deploys). Set the
  node's `assigned_agent` to that agent's name.
- **Otherwise author the sub-agent's FULL spec INLINE in the workflow's
  `agent_specs` array** and reference it by `name` from the node's
  `assigned_agent`. Name it for its role (`issue-triager`, `fix-implementer`,
  `qa-tester`, `pr-author`) and write it to the **template-grade bar**: a real
  `identity` / `soul` / `agentsDoc` — who it is, how it thinks, its operating
  playbook with tool routing, failure modes, and an explicit output schema — not a
  one-line persona. The `TemplateAgent` shape is
  `name` / `displayName` / `identity` / `soul` / `agentsDoc` / `skills` /
  `defaultModel` / `defaultBackend` / `defaultThinking` (see the `aramb-workflows`
  skill's `agent_specs` field + "Multi-agent workflow" example for the full
  contract).

**The specs travel WITH the workflow.** They ride on the same `aramb_workflows.create`
(or `update`) call — one `agent_specs` array alongside `nodes` + `edges` — and brahmi
provisions them **deterministically at claim/run**. You do NOT route bespoke node
agents through a separate agent-creation flow: the Architect never uses the
benji-CLI `create-agent` runtime path, and this skill does not either. A node whose
`assigned_agent` names neither an existing roster agent nor an `agent_specs` entry
**falls back to the main agent** — so only mint a spec for a role that is genuinely
distinct.

**Do NOT branch this decision on solo vs team.** Solo is NOT limited to a bare
`"solo"` persona — that was the old, wrong behavior. Both modes author specs the
same way; the *only* thing solo vs team changes is close-out (solo replies in chat,
master creates/closes tasks). The reuse-if-exists step naturally means master
often reuses roster personas while solo authors fresh inline specs — but that's an
artifact of which agents already exist, not a rule keyed on mode.

**An empty `agent_specs` (all nodes → the main agent) is the EXCEPTION for a
single-role workflow** — a trivial single-node workflow, or one whose nodes are all
the same pure-glue / orchestration role. A multi-step workflow where each node does
distinct work (triage → implement → test → PR) gets a **distinct spec per role**
in `agent_specs`, each referenced by a node's `assigned_agent` — never collapse
every node onto one shared agent.

Everything else — node schema, `required_toolkits`, per-step `toolkit`, the
closing-instruction template, `default_node_settings`, the no-placeholders /
no-`env_variables` rules, and the one-shot `aramb_workflows.create` rule — is
identical across every combination.

## MUST rules — read before anything else

1. **Every node in `aramb_workflows.create` MUST carry `required_toolkits`.** Copy the array from each source task's `required_toolkits` (task dispatch) or infer it from the action the node performs (chat dispatch). Use `[]` (not omitted) when the node touches no third-party service.
   - **Failure mode:** Omitting `required_toolkits` means workflow Evaluate cannot flag missing connections at publish time, and the Required-toolkits row in the FE node panel renders empty. Empty array `[]` is correct when the node touches no third-party service — never omit the field.
   - **Declaring is the whole job — you do not connect the accounts.** As the workflow's author you never start OAuth, never mint or paste an authorization link, and never claim a toolkit is connected. The **user** connects each account in the console (agent **Tools** page / Integrations), on their own runtime project — the only project execution resolves against; an account authorized through the builder would land on a project that never runs. A workflow whose toolkits aren't connected yet is a perfectly good deliverable: it simply stays gated until the user connects them, which is exactly what the declaration is for. (This is about toolkit *accounts* only — it is no reason to avoid authoring a workflow when the job genuinely needs one.)
2. **Every node that touches a third-party service MUST carry a singular `toolkit`** — its *primary* toolkit slug, used for trigger-binding. The invariant brahmi enforces: **`toolkit` MUST be a member of that node's `required_toolkits`.** A Gmail-fetch node is `toolkit:"GMAIL", required_toolkits:["GMAIL"]`; a node that reads Drive then writes Sheets is `toolkit:"GOOGLESHEETS", required_toolkits:["GOOGLEDRIVE","GOOGLESHEETS"]` (pick the one the trigger would bind to — usually the action the workflow is "about"). Omit `toolkit` (or pass `null`) only when `required_toolkits` is `[]`. The brahmi MCP schema rejects a `toolkit` that isn't in `required_toolkits`.
3. **Ground every toolkit + trigger slug in the real catalog — never hallucinate.** Before drafting, call `aramb_toolkits.list_toolkits` to confirm the exact uppercase slugs (and, when the workflow will be event-triggered, `aramb_toolkits.list_triggers("<TOOLKIT>")` for trigger slugs). Do NOT infer slugs from prose. See "Ground the slugs" below. **Never invent a toolkit binding, and never bind a platform-internal/hidden toolkit** (`composio`, `composio_search`, `browser_tool`, `slackbot`, `discord`, `discordbot`, `microsoft_teams`) — `aramb_workflows.create` rejects those. For Slack/Discord/Teams messaging deliverables, deliver via chil `chat.send_dm` (no toolkit). See the `aramb-workflows` skill.
4. **No placeholder syntax in any node `prompt`.** No `{{env.KEY}}`, no `{{input.KEY}}`, no template substitution of any kind. There is no substitution layer — a literal `{{env.FOO}}` reaches the agent as the literal string `{{env.FOO}}`. The brahmi MCP schema **rejects** any prompt matching `{{ env.… }}`. Write what the agent should do with the context that arrives in `<run_input>` instead (see "Run input — the only per-run channel" below).
5. **Do NOT declare `env_variables`.** Omit the field from the `aramb_workflows.create` call entirely. The column has no runtime path in v2 — declaring entries reads as "I wired up your API_KEY" when nothing consumes it. The brahmi MCP schema rejects a non-empty `env_variables` map. Secrets/credentials are connected through the Composio account, not declared on the workflow.
6. **Every node's `prompt` MUST end with the workflow-step closing instruction** so the executing agent calls `aramb_workflows.update_step` (with the explicit `step_id` rendered into its dispatch) at the end of its run. See "Closing instruction per node" below for the exact template.
   - **Failure mode:** Without the closing instruction, the agent finishes its LLM session and brahmi's safety net auto-closes the step, but `outputs` stays NULL. The downstream step's `## Upstream context` preamble then shows "(no summary)" instead of the real hand-off — the chain works visually but with zero context flowing between steps. Outputs are load-bearing.
7. **Call `aramb_workflows.create` exactly once.** Success or failure — never retry.
8. **Close out cleanly.** Task dispatch: always close with `aramb_tasks.update` (`status=done` on success, `status=failed` on any error) — never leave the task `in_progress`. Chat dispatch: confirm in your reply text (success or failure). There is no task to close in chat dispatch.
9. **Speak to the user in plain product language — never leak internals.** The person reading your chat is a customer, not an engineer. Do NOT mention MCP tool names (`aramb_workflows.create`, `aramb_triggers.create`), raw upstream errors (`toolkit-proxy 502`, `ConfigInvalid`), CLI names, internal toolkit/slug strings, or phrases like "the tool isn't in my surface." You DO have these tools — call them. If something genuinely fails, say it in human terms ("I couldn't set up the trigger — the GitHub connection looks unavailable") and stop. Internal mechanics stay in your reasoning, never in the reply.

## Run input — the only per-run channel

A workflow run receives ALL of its per-run context in a single `<run_input>`
block that brahmi renders into the **first step's** prompt at dispatch. It holds
either the user's free-form instruction (manual run) or the trigger payload JSON
(trigger run) — same slot either way. There are no declared input variables, no
typed form, no substitution. The agent reads `<run_input>` and figures out what
to do.

This shapes how you write prompts:

- **Don't parameterize inputs with placeholders.** Where you'd once have written
  `Fix the issue at {{env.ISSUE_URL}}`, now write: *"The user's instruction or the
  trigger payload arrives in `<run_input>`. Extract the issue URL, repo, and any
  details from it, then open a PR that fixes the issue."* Trust the agent to parse
  JSON or free text.
- **Step 1 is the funnel.** `<run_input>` renders on the FIRST step only.
  Downstream steps see only their parent's `outputs.summary` + `outputs.files`.
  So **step 1's prompt MUST instruct the agent to distill the relevant input into
  its `outputs.summary`** — e.g. *"Pull the issue number, title, and repo out of
  `<run_input>` and state them in your summary so later steps can act on them."*
  If step 1 doesn't propagate it, step N never sees it.
- **Fail late, gracefully.** If `<run_input>` is empty (a manual run with no text),
  the step should fail with a clear *"I don't have anything to work on — give me an
  issue URL / instruction"* rather than guess. Don't add pre-flight gates; the
  agent surfaces the failure in the run history. Write step-1 prompts that say so.

## Ground the slugs — call aramb_toolkits before drafting

The slugs you stamp on `toolkit` / `required_toolkits` (and any trigger you wire)
MUST be real catalog values. Don't infer them from prose. Look them up:

```bash
# Confirm toolkit slugs (uppercase, exactly as the catalog reports them)
npx mcporter call aramb_toolkits.list_toolkits

# When the workflow is meant to fire on an event, read the trigger catalog for
# that toolkit so you ground the trigger slug too (the configure-trigger skill
# does the actual wiring — you just confirm the slug exists):
npx mcporter call aramb_toolkits.list_triggers toolkit="GITHUB"
```

`aramb_toolkits.*` returns toolkit + trigger slugs already normalized to uppercase —
use them verbatim. A `toolkit` or `required_toolkits` entry that isn't a real
catalog slug fails pre-flight (no connected account) and the run never starts.

## 1. Get the spec

### Task dispatch — fetch the user tasks (ALL statuses)

Append a "Reading the application's tasks" `## Progress` bullet to the task
description, then:

```bash
npx mcporter call aramb_tasks.list \
  application_id="<application_id>"
```

**Do NOT filter by `status="done"`.** The spec source is *what the user is trying
to do in this chat*, and task success is irrelevant to that intent — a `failed` or
`in_progress` task tells you just as much about the desired workflow as a `done`
one. Read the whole user-task corpus.

The result is a JSON array of task objects, each with: `task_id`, `name`,
`description`, `acceptance_criteria`, `assigned_agent`, `status`, `depends_on`,
`required_toolkits` (Composio toolkit slugs the task used), `outputs`.

**Read `required_toolkits` on every task you fetch.** You copy these into the
corresponding workflow node in step 3 — losing them here loses them forever.

Ignore tasks where `task_kind == "system"` — those are internal bookkeeping
(including the very task you're running). Read intent from `task_kind == "user"`
tasks. The list is NOT in your prompt by design — fetching it yourself keeps the
dispatch small and gives you full task detail.

**If the task corpus doesn't cohere into a single workflow** (the tasks are
unrelated, or there are too many to make sense of), don't emit a garbage graph:
**select the relevant subset and merge/split** into a sensible workflow, and if it
genuinely won't form a coherent one, say so to the user in plain language and ask
what they'd like the workflow to do.

### Chat dispatch — classify the message, then gather

First **classify the user's message**:

- *Explicit description* (e.g. "build a workflow that fetches today's emails…"): the spec **is** the message. Don't analyze conversation history. Skip ahead to step 2.
- *History-derived* (e.g. "create a workflow based on the work done so far", "based on what we just did, build a workflow", or any phrasing that points at the conversation as the evidence): consolidate from your own session. This is the same role the task-dispatch path plays — but the evidence is your conversation history, not completed tasks.

For history-derived intent, walk back through the conversation and produce, in your reasoning:

(a) ordered list of meaningful steps you/the user took,
(b) the explicit and implicit data hand-offs between them,
(c) the Composio toolkit slugs you actually called (Gmail, Sheets, Slack, etc. — be honest, infer from real tool calls),
(d) any constants or specific values that should NOT be re-parameterized (recipe baked-in vs. genuine env-vars).

**Generalize, don't transcribe.** A workflow is a *learned recipe* that should run again. If you fetched yesterday's emails as a one-off, the node should be "fetch the most recent day's emails", not "fetch emails dated 2026-05-04". Same for sheet ranges, time windows, recipient lists — bake the *shape*, not the *specifics* of this one run.

If under-specified (either path), ask **1–2** specific clarifying questions via `aramb_chat.ask_question` BEFORE designing; pick sensible defaults for the rest and tell the user what you picked. Common reasons to clarify: identity (which account / inbox / sheet / channel), notification target, cadence vs trigger (if they want a schedule, capture the cron phrase verbatim — you'll wire it in via `aramb_workflows.set_schedule` after save).

```bash
npx mcporter call aramb_chat.ask_question \
  project_id="<PROJECT_ID>" \
  application_id="<APPLICATION_ID>" \
  question="Which Gmail account should the workflow read from — the one connected to this app, or a different one?"
```

## 1.5 Pre-build checklist — confirm-then-build (one concise round)

Before you construct nodes, confirm the few things that **materially change the
build**. The failure this prevents: building the whole workflow on silent
assumptions, then leaking the gaps as broken runs and contradictory status (e.g.
guessing a Proceed threshold the user never set, never noticing Sheets/GitHub
weren't connected, never warning that a 300-item job is long and costly).

Do it as **confirm-then-build, not interrogation**: **one** concise round of **2–4
questions** total, covering only the items below that actually apply and aren't
already specified. If everything is clear, skip straight to building — don't
manufacture questions. Verify the things you CAN verify yourself (toolkit
connections) rather than asking. Ask via `aramb_chat.ask_question` (chat dispatch)
or fold into your progress narration / a single batched question (task dispatch).
Pick sensible defaults where you can and state what you picked.

- **Scoring / decision params not clearly specified.** If the workflow makes a
  judgement (a Proceed/Reject threshold, rubric weights, a pass mark, a ranking
  cutoff), confirm the value — don't guess one. A wrong threshold silently mis-sorts
  every item.
- **Toolkit connectivity — verify, don't assume.** For **every** external system the
  workflow will touch (Sheets, GitHub, Gmail, Slack, …), check the connection
  yourself with `aramb_toolkits.check_connection toolkit="<SLUG>"`. If any is not
  connected, tell the user plainly which one(s) to connect **now** — before the
  build — rather than discovering it mid-run. (The authoritative check is the
  publish/run eval gate, which can still reject on scopes/expiry; this up-front
  check just catches the common "not connected at all" case early.)
- **Scale / cost heads-up.** If the input set is large (hundreds of items, a big
  repo list, a long candidate sheet), state the rough scale and expected time/cost
  up front, and **offer a small pilot first** (e.g. "run the first 10 to validate
  the rubric, then the full set?"). Don't quietly kick off a multi-hour job.
- **Source accessibility.** Confirm the links / repos / sheets the workflow reads
  are reachable the way the run will reach them — **public vs needs auth**. A
  private repo or a permissioned sheet that looked fine in your browser will fail
  in the run. If something needs auth, say what's required (toolkit connection,
  repo link, browser login) before building.

Keep it to the items that apply. The goal is to surface the handful of unknowns
that would otherwise become failed runs — then build with confidence, not to
interrogate the user.

## Progress reports — do this throughout

**Task dispatch.** The user sees your task card in the chat sidebar. If you don't
update the task description they stare at a spinner. Append a short `## Progress`
bullet before each major step — before fetching, before designing, before saving.
Three updates is usually right; don't spam. Preserve the original description text
(append, don't replace).

```bash
npx mcporter call aramb_tasks.update \
  task_id="<your task_id>" \
  description="<full current description, including any Progress so far>
## Progress
- Read 5 user tasks
- Analyzing dependencies and agent assignments"
```

**Chat dispatch.** The user sees chat, not a task card. Write short progress
narration in your reply text at three checkpoints (brahmi saves your final
assistant text as the chat row — no MCP call needed):
1. Restate the workflow you're about to build **and which evidence source you're using** ("Building from your description: 3-step Gmail → Sheet → email digest" / "Consolidating from the work we did earlier in this chat: 3 steps — fetch, write, notify").
2. When you start designing nodes ("Designing 3 nodes — Gmail fetch → Sheet append → notify").
3. Just before save ("Saving workflow…").

## 2. Analyze the spec

Study the spec (the user tasks, the explicit description, or the conversation
work). Understand: what each step accomplishes, how steps depend on each other,
**which agent each node needs (by its role — decided identically in solo and team:
reuse a fitting existing agent, else author a bespoke sub-agent spec INLINE in the
workflow's `agent_specs`; see "Per-node persona — decided by the work")**, and what
inputs/outputs flow between steps.

For chat dispatch this is also the **merge / generalize / split** pass: combine
adjacent same-agent calls into one node where it makes the workflow cleaner;
split steps that mixed responsibilities; rename concrete one-off artefacts ("the
email about Q3 review") into the recurring shape they represent.

## 3. Design the workflow

Update progress: "Designing workflow graph — N nodes, M levels".

- **Merge or split** steps where it makes the workflow cleaner. Not every source task becomes a node.
- **Concrete prompts** — each node's `prompt` carries the real business context baked in. This is a learned recipe, not a blank template. Distill what actually worked but keep the concrete subject matter.
- **Preserve dependencies** — give each node a sequential `unique_id` (integers starting at 1), then express dependencies as a separate top-level `edges` array: `{ "source": <upstream unique_id>, "target": <downstream unique_id> }`. Do NOT put `dependencies`, `depends_on`, or `dependsOn` on node objects — brahmi rejects that shape.
- **`assigned_agent` per node** — one agent per role, decided IDENTICALLY in solo and team (see "Per-node persona — decided by the work"). For each node: reuse an existing agent that fits the role (a roster persona — `developer` / `*-tester` / `checker` / `*-deployer`), otherwise **author a bespoke sub-agent spec INLINE in the workflow's `agent_specs`** named for its role (`issue-triager`, `fix-implementer`, `qa-tester`, `pr-author`, …) to the template-grade bar, and set the node's `assigned_agent` to that spec's `name`. In task dispatch, you may default to the source task's persona. A single-role workflow keeps `agent_specs` empty (all nodes → the main agent) — only for a trivial single-node / pure-glue workflow. Do NOT branch on solo vs team.
- **Do NOT pick a different model per node.** Model/effort/thinking come from the single workflow-wide `default_node_settings` (or, for an inline sub-agent, its `defaultModel`); per-node `settings` stays `{}` (inherit). Never stamp `model` on individual nodes — no per-step Haiku/Opus/Sonnet juggling.
- **Carry `required_toolkits` per node — MANDATORY, never omit.** List the Composio toolkit slugs that node will call (`["GMAIL"]`, `["GOOGLESHEETS","GOOGLEDRIVE"]`, etc.). Task dispatch: source from each task's `required_toolkits` field (primary) and the tool calls you observe in outputs (cross-check). Chat dispatch: infer from the action — Gmail action → `["GMAIL"]`, Sheets append → `["GOOGLESHEETS"]`, Slack DM → `["SLACK"]`. Empty array (`[]`) when a node only writes files / orchestrates — `[]` is REQUIRED, not optional. Slugs are uppercase and **grounded via `aramb_toolkits.list_toolkits`** (see "Ground the slugs"), not guessed from prose. Brahmi snapshots this list onto every run step at trigger time and the Evaluate step uses it to surface missing-connection warnings before publish.
- **Carry a singular `toolkit` per node that has any toolkits — MANDATORY when `required_toolkits` is non-empty.** It is the node's *primary* toolkit (the one a trigger would bind to). Invariant: `toolkit ∈ required_toolkits`. Single-toolkit node → `toolkit` equals the one slug. Multi-toolkit node → pick the slug the node's job is "about" (the action it exists to perform, not an incidental read). Omit `toolkit` (or `null`) only when `required_toolkits` is `[]`. Brahmi rejects a `toolkit` that isn't in `required_toolkits`.
- **Per-node toolkit CHOICE — Composio connection vs `aramb-browser`.** For each node that touches an external surface, decide *how* it acts: does the **Composio toolkit** cover the action, or do you need **`aramb-browser`** (drive a logged-in website directly)? Composio is the default when it has the action; reach for `aramb-browser` when Composio's coverage of that service is limited (e.g. Composio LinkedIn is read-thin → a "post to LinkedIn" or "comment on a profile" node needs `aramb-browser`, and trips the browser-login pre-check below). **Shortcut: if the work was already performed** (you can see it in the session or the task outputs), reuse whatever actually served the purpose — the user already chose the path that worked; don't second-guess it.
- **Write prompts against `<run_input>`, never placeholders.** Each node's `prompt` describes what to do with the context it receives — for step 1 that context is the `<run_input>` block (see "Run input — the only per-run channel"); for later steps it's the parent's `outputs.summary`. No `{{env.KEY}}` / `{{input.KEY}}` anywhere. Step 1's prompt must explicitly tell the agent to distill the relevant input into its `outputs.summary` for downstream steps.
- **Set `default_node_settings` on the workflow.** Always emit a sensible defaults block — see "Default node settings — workflow-level". Don't leave it empty: the FE renders the settings tray off these values.
- **Per-node `settings` typically stays empty (`{}`)** — defaults inherit from the workflow. Exception: if a node does something destructive or externally visible (posts to Linear, sends email, writes to a customer DB, deletes files), set that one node's `settings.approval_mode = "manual"`. Use sparingly — over-gating turns every run into a clickfest.
- **Per-node attachments** only when the user explicitly mentioned files in chat. Never invent attachments — empty `input_attachments` is the default.
- **End every node `prompt` with the closing-instruction template** (next section). The agent has no other path to populate `outputs`.

## Closing instruction per node — MANDATORY

Every node's `prompt` MUST end with this exact block, with `<summary>` and `<files>` substituted to match what the node will actually produce. Treat it the way the task-description template treats the closing `aramb_tasks.update` call — non-negotiable, baked into every prompt at authoring time.

Append this to every node's `prompt`:

```
When done — record your output for the next step:
  npx mcporter call aramb_workflows.update_step \
    project_id="<your Project ID from User Message>" \
    step_id="<your Workflow Run Step ID from User Message>" \
    status="done" \
    outputs='{"summary":"<one-paragraph hand-off, under 500 chars>","files":["relative/path/to/output.json"]}'

If you can't complete the step:
  npx mcporter call aramb_workflows.update_step \
    project_id="<your Project ID from User Message>" \
    step_id="<your Workflow Run Step ID from User Message>" \
    status="failed" \
    error="<concise reason + any partial progress>"
```

Why both `summary` and `files`:
- `summary` is a paragraph the next agent reads as preamble — the hand-off vocabulary that makes the chain coherent. Keep it under 500 chars; focus on what's useful downstream, not how the work was done.
- `files` is a list of paths (relative to the workspace working directory) the next agent reads to dig deeper. Empty array `[]` is correct when the node only sends a message / posts to an external service and produces no files.

Notes:
- The agent reads its `project_id` and `step_id` from the User Message under "## Current Context" (`Project ID:` and `Workflow Run Step ID:` lines) at dispatch time. Brahmi rejects cross-step writes (`context_drift`), so the agent MUST copy these UUIDs verbatim into the close call.
- Do NOT instruct the agent to call `aramb_tasks.update` from a workflow-step prompt — that targets the tasks domain (different DB rows) and the run will stall on the safety net. Only `aramb_workflows.update_step` closes a workflow run step.

## Git operations — route through aramb_toolkits + native git/gh

**When to emit this block:** any node whose described work involves anything on
github — clone, fetch, checkout, push, branch, commit, PRs, issues, releases,
comments. Everything github goes through the same surface (no API-vs-protocol
split anymore): `aramb_toolkits.get_github_credential` → `GH_TOKEN` → native
`git` / `gh` CLI.

**Why it matters:** github is NOT a Composio toolkit on this platform —
`composio execute GITHUB_*` is hard-blocked at the proxy with `403`. The
credential broker is the only way to get a usable github token from the
agent's container.

**Append this block verbatim** to the END of any node prompt that involves
github work (after the closing-instruction template):

```
### Tool routing for github operations on this step
1. Confirm the user has connected github:
   `aramb_toolkits.check_connection toolkit="GITHUB"`
   - If `connected: false` — call
     `aramb_toolkits.connect_toolkit toolkit="github"` and share the
     returned `redirect_url` with the user via your reply or
     `aramb_chat.alert_user`. Close the step with `status="blocked"` until
     they finish OAuth; do not retry without confirmation.
2. Mint a token:
   `aramb_toolkits.get_github_credential` (returns `{ token, username,
   account_ref, ... }`).
   - If the org has multiple github accounts in scope and the response is
     `409 ambiguous_connection`, call
     `aramb_toolkits.list_connections toolkit="GITHUB"`, pick the right
     `account_ref`, then re-call with `account_ref="ca_..."`.
3. Export and use native CLI for everything:
   `export GH_TOKEN="<token>"`
   `git clone https://x-access-token:$GH_TOKEN@github.com/<owner>/<repo>.git`
   `git push`, `gh pr create`, `gh issue list`, `gh release create`, etc.
4. On `401` from `git` / `gh` (~8h token lifetime), re-call
   `aramb_toolkits.get_github_credential` for a fresh token. Cheap, no rate
   concerns.
5. NEVER use `composio execute GITHUB_*` — those slugs are hard-blocked at
   the proxy with `403`. Also do NOT use `aramb_chat.list_linked_repos`,
   `aramb_chat.clone_repo`, or `aramb_chat.git_token` — those don't exist
   on this surface anymore.
```

Emit this block on every node that touches github — there is no "API-only"
exemption anymore since both API and protocol ops go through the same
native-CLI path.

## Durable-output nodes — foreground + append-only

**When to emit this block:** any node that builds up a durable output file or
sheet over a long task — scoring/ranking many submissions into a `results.csv`,
walking a candidate list into a sheet, batch-evaluating a repo set into a report.
These are the long nodes that may hand off mid-run (a continuation picks up where
the previous attempt left off), so how the agent treats its output file decides
whether the work converges or thrashes.

**Why it matters:** a long durable-output node can be re-entered — on a
continuation handoff or a stranded-step recovery a fresh session resumes against
the same working directory and the same partially-written file. Two failure modes
seen in the wild: (1) the agent **backgrounds** the scoring loop (`run2.sh &`) and
the session closes while the child keeps running, so the next session spawns
another loop and N orphaned processes race on the same file; (2) the agent
**truncates or rewrites** the results file each run (recreate, in-place dedup,
"clean up and re-emit"), so progress oscillates and never converges instead of
growing monotonically. Foreground + append-only is what makes a resumed run safe.

**Append this block verbatim** to the END of any durable-output node prompt
(after the closing-instruction template), substituting `<output file>` with the
node's actual results path:

```
### Building your durable output (foreground + append-only)
This step writes `<output file>` incrementally over a long run, and may be
resumed by a fresh session against the same working directory. Treat the file
as a growing ledger, never a scratchpad:
1. FOREGROUND ONLY. Run the core loop in the foreground — do the scoring/work
   inline, turn by turn. NEVER background it (`script &`, `nohup`, `&` of any
   kind, detached `run.sh`). A backgrounded loop keeps running after the session
   closes and a later session will spawn a second loop that races it on the file.
2. APPEND-ONLY. Treat `<output file>` as strictly append-only. Append each new
   row as you produce it. NEVER truncate, recreate, overwrite, reorder, or do an
   in-place dedup/rewrite of the file — those destroy committed progress and make
   the output oscillate instead of converge. Write the header once, only if the
   file does not yet exist.
3. ON RESUME, re-read then append. If `<output file>` already exists when you
   start, READ it first, treat every row already in it as DONE, and continue from
   where it left off — append only the rows not yet present, skip the ones that
   are. Do NOT restart the task from scratch, re-run prior work, or relaunch any
   script/background process a previous attempt may have started; pick up and add
   only the remaining work.
```

Do NOT emit this block on nodes that produce a single small output in one pass
(send a message, write one summary file, post a digest). It is noise there — the
append-only ledger discipline only matters when output accumulates across a long,
potentially-resumed run.

## Default node settings — workflow-level

Every workflow carries a `default_node_settings` JSONB block on the workflow itself. The FE renders the workflow settings tray from these values, and brahmi merges them per-step at dispatch time (workflow defaults ⊕ node overrides). Always emit it — leaving it `{}` makes the FE render blanks and the runtime fall back to coarse defaults.

Sensible default block to emit unless the user said otherwise:

```json
{
  "model": "claude-sonnet-4-6",
  "effort": "medium",
  "thinking": "adaptive",
  "max_turns": 35,
  "admin": false,
  "budget_usd": 25.0,
  "approval_mode": "auto",
  "instructions": ""
}
```

Field-by-field guidance:

- `model` — workflow-wide model. Sonnet 4.6 is the everyday default; promote to `claude-opus-4-7` only if the user said "use Opus", or the work obviously needs heavier reasoning. Demote to `claude-haiku-4-5` only on explicit user request.
- `effort` — `medium` is the default. Bump to `high` if the user emphasized care / depth, drop to `low` for trivially mechanical workflows.
- `thinking` — `adaptive` is the default; only flip if the user said something specific ("turn extended thinking off", "always think hard").
- `max_turns` — `35` is the default per step. Raise (60–80) only for steps the user explicitly described as long / iterative.
- `admin` — `false`. Don't enable graph-edit privilege without an explicit user ask.
- `budget_usd` — `25.0` is the workflow-wide ceiling. Increase only when the user named a higher number.
- `approval_mode` — `auto` workflow-wide. Manual gating belongs on individual node `settings`, not the workflow default.
- `instructions` — usually `""`. Fill from chat if the user expressed a *cross-workflow* style preference ("respond in IST", "use markdown for replies", "always cite sources"). The string is appended to every step's prompt at dispatch, so it should be voice / format / locale guidance — never task-specific content.

Per-node `settings` overrides only fire when the user asked for variation. Common patterns:
- "the synth step should use Opus" → that one node's `settings.model = "claude-opus-4-7"`.
- a destructive / external-effect step → that node's `settings.approval_mode = "manual"`.
- a step the user said is bigger → that node's `settings.max_turns = 80`.

Otherwise leave each node's `settings: {}`.

## 4. Bake context into prompts — do NOT declare env_variables

The workflow is a *learned recipe*. Bake business context, topic, tone, target
audience, identity, endpoints — every concrete value the recipe needs — directly
into the relevant node's prompt. There is no `env_variables` channel in v2:

- **Omit `env_variables` from the `aramb_workflows.create` call entirely.** The
  column has no runtime path — nothing reads it. Declaring entries misleads the
  user ("I added your API_KEY" — but nothing consumes it). The brahmi MCP schema
  rejects a non-empty `env_variables` map.
- **Secrets / credentials are NOT declared here.** Third-party auth (API keys,
  OAuth tokens) is supplied through the Composio connected account for the
  node's `toolkit` — that's what `required_toolkits` + the pre-flight connection
  check are for. The workflow definition never carries a secret.
- **Per-run inputs are NOT declared here either.** Anything that varies per run
  (the issue to fix, the recipient, the date window) arrives in `<run_input>` at
  run time — the agent reads it from there. See "Run input — the only per-run
  channel". Do NOT invent placeholders for these.

So: constant recipe values → bake into the prompt. Per-run values → read from
`<run_input>`. Secrets → Composio connection. Nothing goes in `env_variables`.

## 4.5 Recommend a trigger — recommend-and-add, NOT a save gate

`trigger_choice` is **optional**. The trigger is a recommend-and-approve tail step,
not a save gate — `aramb_workflows.create` saves fine without one. Don't block the
save on it; recommend a sensible firing condition and add it on the user's
approval.

1. **Ground the options.** Read the entry node's `toolkit` (the node with no
   incoming edge). If it has one, list real event candidates:
   `npx mcporter call aramb_toolkits.list_triggers toolkit="<TOOLKIT>"`. No
   toolkit (pure-LLM workflow) → offer only cron + manual.
2. **Recommend via one question** through `aramb_chat.ask_question` with structured
   `options` — NOT a free-text wall of "decisions I need." Lead with the event
   trigger that best fits the user's intent (first option = your recommendation),
   then "On a schedule", then "No trigger / run manually". Keep labels
   plain-English; put raw catalog slugs in the `description`, never in the label.
   This is a recommendation, not a demand — if the user picks manual or skips it,
   that's fine; save anyway.
3. **Record the pick (optional metadata):** event → `trigger_choice="toolkit_event"`
   (keep the catalog `slug`); schedule → `"cron"` (keep the cadence); manual /
   declined → omit `trigger_choice` (or pass `"manual"` if they explicitly chose
   it). Passing the field is optional — the save no longer depends on it.
4. **If the user approved an event or schedule, wire it after `aramb_workflows.create`
   succeeds, in the same turn:**
   - `toolkit_event` → hand to the `configure-trigger` skill with the `workflow_id`
     + `slug`. It reads the trigger's `config_schema` and passes `trigger_config`
     (e.g. GitHub triggers need `{owner, repo}`). Don't tell the user it's firing
     until it reports `active` (registration is async upstream).
   - `cron` → `aramb_workflows.set_schedule` with the cadence.
   - `manual` / declined → nothing to wire.

## 4.6 Run-status callback — optional, only if asked

If the user wants an external system notified when this workflow runs ("POST to my
endpoint when it starts/finishes", "send run status to this URL"), set a
workflow-level callback after `aramb_workflows.create` succeeds:

```bash
npx mcporter call aramb_workflows.set_callback \
  workflow_id="<workflow_id>" \
  callback_url="https://example.com/hooks/run-status"
```

The response returns a **signing secret once** — surface it to the user verbatim
and tell them it won't be shown again (they verify `Webhook-Signature` with it).
brahmi then POSTs a signed status payload on every real run, on start (`running`)
and on terminal (`completed`/`failed`/`cancelled`). It's workflow-level config —
see the `aramb-workflows` skill for the full payload contract. Don't set one
unless the user asked.

## Browser-login pre-check — required before save

If a node uses `aramb-browser` to act on a logged-in site, that login must already
exist or the workflow fails silently at run time. **Hard gate — no "save anyway."**

1. For each node whose `required_toolkits` includes `aramb-browser` AND whose
   prompt names a known-login site (`linkedin.com`, `github.com`,
   `twitter.com`/`x.com`, `gmail.com`/`mail.google.com`, `reddit.com`, `notion.so`,
   `slack.com`, `discord.com`, `instagram.com`), the expected context is
   `<site>-login` (e.g. `linkedin-login`). Public/no-login surfaces don't trip this.
2. Check what exists: `npx mcporter call aramb-browser.browser_context_list`.
3. **Present** → proceed; tell the user plainly you'll reuse their `<site>` login.
   **Missing** → do NOT call `aramb_workflows.create`. Tell the user, in plain
   language, that the workflow needs them to log in to `<site>` once in a separate
   browser chat — cite the aramb-browser flow (`browser_context_create
   context_name=<site>-login` → log in → `browser_save_context ...
   context_name=<site>-login`) — then STOP until the slot exists. List all missing
   sites in one message.

## 5. Save the workflow

Update progress: "Saving workflow to brahmi".

Call `aramb_workflows.create` with `agent_id` (the agent this workflow belongs to)
+ `project_id` (both in your session metadata / dispatch block; `application_id` is
optional/legacy). Brahmi creates the workflow row + nodes atomically in a single
transaction, filed under the owning agent as a **draft** — no publish step.

**Do not reach this step if the browser-login pre-check found a missing
`<site>-login` slot** — that gate is a hard stop, not advisory.

**Pre-flight checklist — verify before calling `aramb_workflows.create`.** For every node:

- `unique_id` — sequential integer starting at 1
- `name` — short label
- `prompt` — concrete instruction with business context baked in **AND ending with the closing-instruction template**
- `assigned_agent` — one agent per role, decided identically in solo and team: reuse a fitting existing roster agent, else set it to the `name` of a bespoke sub-agent spec you author INLINE in the workflow's `agent_specs`. Never `null` or empty, and never collapse a multi-step workflow onto one agent. (A node whose `assigned_agent` matches no roster agent and no spec falls back to the main agent — fine for a single-role workflow with empty `agent_specs`, wrong when the role is genuinely distinct.)
- `acceptance_criteria` — how to know the step succeeded
- **`required_toolkits`** — grounded via `aramb_toolkits.list_toolkits`; copied from the source task (task dispatch) or inferred-then-grounded (chat dispatch). `[]` for orchestration / file-only nodes; never omit.
- **`toolkit`** — the node's primary toolkit slug; MUST be a member of `required_toolkits`. Omit (or `null`) only when `required_toolkits` is `[]`.
- **`prompt`** — no `{{env.…}}` / `{{input.…}}` placeholders anywhere; step 1's prompt instructs the agent to read `<run_input>` and distill the relevant bits into its `outputs.summary`.
- **`source_task_id`** — **task dispatch only:** the `task_id` of the originating user task from `aramb_tasks.list`. Required whenever the node consolidates from one user task; omit only for glue / orchestration nodes you invented. Powers the FE "show me the task that produced this node" link and cost reconciliation. **Chat dispatch:** omit the field entirely (or pass `null`) — solo has no source tasks. Brahmi accepts both.
- **`settings`** — JSONB; usually `{}`. Set keys only when this node deviates from the workflow defaults.

And on the call itself:

- **`agent_id`** — the id of the agent this workflow belongs to. Pass it in the **agent-first** flow — it creates-and-links the workflow to that agent in one call. Omit it only in the deliberate **workflow-first** flow (build/test standalone, then `aramb_agents.attach_workflow` links it once the agent exists). Either way the workflow must end up owned by an agent — don't leave it *permanently* orphaned.
- **`agent_specs`** — the top-level inline sub-agent array (one `TemplateAgent` per genuinely-distinct role a node references via `assigned_agent`). Pass it in the SAME call as `nodes`/`edges` when the workflow is multi-role; pass `'[]'` (or omit) for a single-role workflow where every node runs as the main agent. Each spec: `name` (unique, matched by a node's `assigned_agent`) + `identity`/`soul`/`agentsDoc` to the template-grade bar + optional `skills`/`defaultModel`/`defaultBackend`/`defaultThinking`. See the `aramb-workflows` skill's `agent_specs` field.
- **`default_node_settings`** — the workflow-wide defaults block. Emit it; don't leave it empty.
- **`trigger_choice`** — OPTIONAL (`toolkit_event` | `cron` | `manual`). Pass it only if the user picked a firing condition in Section 4.5; omit it otherwise. The save does NOT depend on it.
- **No `env_variables`** — omit the field entirely (the schema rejects a non-empty map).

Bugs that silently break downstream behaviour — fix the payload before calling:
1. Missing `required_toolkits` — kills Evaluate's missing-connection warnings.
2. `toolkit` not in `required_toolkits` (or missing on a toolkit-using node) — brahmi rejects the call.
3. A `{{env.KEY}}` / `{{input.KEY}}` placeholder in any prompt — brahmi rejects the call.
4. An out-of-enum `trigger_choice` value — brahmi rejects it; omit the field unless the user picked toolkit_event/cron/manual.
5. Missing `source_task_id` (task dispatch) — once saved, the link to the originating user task is gone for good.
6. Missing closing instruction in `prompt` — `outputs` stays NULL, downstream sees "(no summary)" preamble.

**Each node's `prompt` should look like this (markdown, multi-line) before you JSON-encode it.** This is step 1, so it reads `<run_input>` and distills it for downstream:

```
Read `<run_input>` — it carries the user's instruction (or a trigger payload)
for this run. Extract the target day / calendar from it (default to the primary
calendar and today if it's empty; if there's nothing usable, stop and report
"I don't have anything to work on"). Fetch that day's events and save them as
JSON to .planning/calendar.json. In your summary, state the day and event count
so the next step doesn't have to re-read the input.

When done — record your output for the next step:
  npx mcporter call aramb_workflows.update_step \
    project_id="<your Project ID from User Message>" \
    step_id="<your Workflow Run Step ID from User Message>" \
    status="done" \
    outputs='{"summary":"Fetched N calendar events for today; saved JSON.","files":[".planning/calendar.json"]}'

If you can't complete the step:
  npx mcporter call aramb_workflows.update_step \
    project_id="<your Project ID from User Message>" \
    step_id="<your Workflow Run Step ID from User Message>" \
    status="failed" \
    error="<concise reason>"
```

The instruction body (top paragraph) is per-node business context. The `When done` / `If you can't complete` blocks are the closing template — identical structure across every node, only the `summary` / `files` content differs. Compose both halves, then JSON-encode the full string into the node's `prompt`.

**`aramb_workflows.create` skeleton — team mode** (task dispatch; each node carries a real team persona + `source_task_id`):

```bash
npx mcporter call aramb_workflows.create \
  agent_id="<agent_id>" \
  project_id="<project_id>" \
  name="Descriptive Workflow Name" \
  description="What this workflow does in 1-2 sentences" \
  trigger_choice="toolkit_event" \  # OPTIONAL — include only if the user approved an event/cron in 4.5; omit otherwise
  default_node_settings='{"model":"claude-sonnet-4-6","effort":"medium","thinking":"adaptive","max_turns":35,"admin":false,"budget_usd":25.0,"approval_mode":"auto","instructions":""}' \
  nodes='[
    {"unique_id": 1, "name": "Fetch calendar events", "prompt": "<reads <run_input> + closing template>", "assigned_agent": "developer", "acceptance_criteria": "events array fetched and logged", "required_toolkits": ["GOOGLECALENDAR"], "toolkit": "GOOGLECALENDAR", "source_task_id": "<task_id from aramb_tasks.list>", "settings": {}},
    {"unique_id": 2, "name": "Summarize",             "prompt": "<body + closing template>",            "assigned_agent": "developer", "acceptance_criteria": "summary text produced",          "required_toolkits": [],                "source_task_id": "<task_id from aramb_tasks.list>", "settings": {}},
    {"unique_id": 3, "name": "Email the summary",     "prompt": "<body + closing template>",            "assigned_agent": "developer", "acceptance_criteria": "Gmail returned a message id",  "required_toolkits": ["GMAIL"],         "toolkit": "GMAIL", "source_task_id": "<task_id from aramb_tasks.list>", "settings": {"approval_mode":"manual"}}
  ]' \
  edges='[
    {"source": 1, "target": 2},
    {"source": 2, "target": 3}
  ]'
```

**Solo mode** differs only in close-out (chat, not `aramb_tasks.update`) and
`source_task_id` being omitted. **Each node still gets an agent for its role — for
roles with no fitting roster agent, author the sub-agent's full spec INLINE in the
`agent_specs` array on this SAME `aramb_workflows.create` call**, then set each
node's `assigned_agent` to the matching spec `name`. No separate provisioning step,
no `create-agent` — the specs travel with the workflow:

```bash
  nodes='[
    {"unique_id": 1, "name": "Fetch calendar events", "prompt": "<reads <run_input> + closing template>", "assigned_agent": "calendar-fetcher",  "acceptance_criteria": "events array fetched and logged", "required_toolkits": ["GOOGLECALENDAR"], "toolkit": "GOOGLECALENDAR", "settings": {}},
    {"unique_id": 2, "name": "Summarize",             "prompt": "<body + closing template>",            "assigned_agent": "agenda-summarizer", "acceptance_criteria": "summary text produced",          "required_toolkits": [],                "settings": {}},
    {"unique_id": 3, "name": "Email the summary",     "prompt": "<body + closing template>",            "assigned_agent": "digest-emailer",    "acceptance_criteria": "Gmail returned a message id",  "required_toolkits": ["GMAIL"],         "toolkit": "GMAIL", "settings": {"approval_mode":"manual"}}
  ]' \
  agent_specs='[
    {"name":"calendar-fetcher","displayName":"Calendar Fetcher","identity":"<who this sub-agent is>","soul":"<how it thinks/behaves>","agentsDoc":"<its operating playbook — tool routing, failure modes, output schema>","skills":[],"defaultModel":"","defaultBackend":"claude-sdk","defaultThinking":"medium"},
    {"name":"agenda-summarizer","displayName":"Agenda Summarizer","identity":"<...>","soul":"<...>","agentsDoc":"<...>","skills":[],"defaultModel":"","defaultBackend":"claude-sdk","defaultThinking":"medium"},
    {"name":"digest-emailer","displayName":"Digest Emailer","identity":"<...>","soul":"<...>","agentsDoc":"<...>","skills":[],"defaultModel":"","defaultBackend":"claude-sdk","defaultThinking":"medium"}
  ]'
```

Author each spec's `identity` / `soul` / `agentsDoc` to the template-grade bar (see the `aramb-workflows` skill's "Multi-agent workflow" example for a fully-written spec). An **empty `agent_specs` (`'[]'`)** would only be right for a trivial **single-node / single-role** workflow, where every node runs as the main agent. A multi-step workflow whose nodes are distinct roles gets a distinct inline spec per role — the same way team mode reuses a distinct roster persona per node.

In both examples, node 3 carries `settings.approval_mode = "manual"` because it sends an external-facing message — exactly the per-node manual-approval heuristic. Nodes 1 and 2 keep `settings: {}` and inherit the workflow defaults.

Node objects carry ONLY the node fields. Dependencies live in the separate top-level `edges` array — each edge is `{source: <unique_id>, target: <unique_id>}`, "target depends on source." A cycle fails the save. For a linear 3-step workflow: `[{"source":1,"target":2},{"source":2,"target":3}]`. Fan-out where 1 feeds both 2 and 3: `[{"source":1,"target":2},{"source":1,"target":3}]`. Single node: omit `edges` (or pass `'[]'`).

The response includes `workflow_id` and `node_count`. If `node_count` matches the number of nodes you sent, the save succeeded.

**Never retry `aramb_workflows.create`.** If the first call succeeds you're done — calling again fails with "workflow already exists for this application". If the first call errors (bad payload, cycle in deps), do NOT retry with a modified payload — close out as failed (task dispatch) or tell the user the concise reason and what they could change (chat dispatch). The user can click Create Workflow again for a fresh attempt.

## 6. Close out

### Task dispatch — close the task

On success, use the `workflow_id` brahmi returned:

```bash
npx mcporter call aramb_tasks.update \
  task_id="<your task_id>" \
  status="done" \
  outputs='{"workflow_id":"<workflow_id from aramb_workflows.create response>","node_count":<number>,"summary":"Consolidated N tasks into M nodes across L levels."}'
```

**Trigger wiring.** If the user approved an event/cron in the Section 4.5
recommend step, you wired it right after `aramb_workflows.create` in 4.5 step 4,
in this same turn, so the trigger row / cron slot already exists. If they declined
or picked manual, there's nothing wired — that's fine, the workflow saved anyway.
Record whatever you wired (or "no trigger") in the close-out `summary` so it's
auditable:

```bash
outputs='{"workflow_id":"<id>","node_count":<n>,"summary":"Consolidated N tasks into M nodes; trigger: fires on GITHUB_NEW_ISSUE (active)."}'
```

If the inline `configure-trigger` / `set_schedule` call could not complete within
this turn (e.g. the async activation poll outran the budget), say so explicitly in
the summary and add a `trigger_hint` / `schedule_hint` so a follow-up turn
finishes the wiring — never report the workflow as fully triggered when it isn't:

```bash
outputs='{"workflow_id":"<id>","node_count":<n>,"summary":"...trigger NOT yet active","trigger_hint":"Finish wiring: run configure-trigger with workflow_id=<id>, slug=GITHUB_NEW_ISSUE."}'
```

On failure (aramb_tasks.list error, aramb_workflows.create error, cycle detected, …):

```bash
npx mcporter call aramb_tasks.update \
  task_id="<your task_id>" \
  status="failed" \
  rejection_reason="<concise one-line reason>"
```

**CRITICAL: After calling `aramb_tasks.update`, STOP. Do not send any follow-up messages.**

### Chat dispatch — confirm in chat

If the user approved an event/cron in Section 4.5, you wired it in 4.5 step 4
right after `aramb_workflows.create` returned, so the confirmation reflects what's
already in place. If they declined, the workflow is saved with no trigger (runs
manually) — say so plainly. Bundle the trigger result into the one-line
confirmation:

```
Workflow created — "<name>" (<workflow_id>) — <n> steps, fires when a GitHub issue is created. View it in the Workflows tab.
# or:  …— <n> steps, scheduled for 8am IST every weekday.
# or:  …— <n> steps, manual run only (just ask me to run it, or run it from the Workflows tab).
```

Reminders for the 4.5 step-4 wiring (only if the user approved a trigger):
- `cron` → you called `aramb_workflows.set_schedule` yourself (it's not gated; the
  `schedule-workflow` skill has cron-format guidance). Example:
  ```bash
  npx mcporter call aramb_workflows.set_schedule \
    workflow_id="<workflow_id>" cron_expression="0 8 * * *" \
    cron_timezone="Asia/Kolkata" enabled=true
  ```
  If the user also wants the fire time staggered (not landing on a robotic exact
  minute), add the optional cron-only args `random_delay_enabled=true` and
  `random_delay_max_minutes=<N>` — the delay is clamped to 80% of the gap to the
  next tick. See the `schedule-workflow` skill.
- `toolkit_event` → you invoked `configure-trigger` with the resolved
  `workflow_id` + chosen `slug`. Don't claim it's firing until it reports
  `active` (async upstream).

On `aramb_workflows.create` error, tell the user the concise reason and what they
could change, then stop — don't retry.

## Rules

- **The workflow belongs to one agent — pass `agent_id` on `create`** (agent-first, create-and-link in one step), **or** attach it later with `aramb_agents.attach_workflow` (workflow-first); both converge on the same owned-and-filed end state, so never leave it *permanently* orphaned. It stays a **draft** and goes live automatically when that agent is published — **but a toolkit-using workflow only goes live once its toolkits are connected** (connect them on the **Integrations** page; see MUST rule #2). Do NOT call any workflow-publish tool as a build step, and test the draft via Preview / `aramb_workflows.run`.
- Each node's `prompt` carries real business context baked in.
- **Each node's `prompt` MUST end with the closing-instruction template** so the executing agent calls `aramb_workflows.update_step` (with the explicit `step_id` rendered into its dispatch User Message) at the end of its run. Without it, `outputs` stays NULL and the upstream-context hand-off chain shows "(no summary)".
- **Always emit `default_node_settings`** with the full sensible-defaults block; never leave it empty.
- **Per-node `settings`** stays `{}` unless the user asked for variation. Manual approval gating goes on individual node settings, never on the workflow default.
- **`assigned_agent`** — one agent per role, decided IDENTICALLY in solo and team (mode never enters the decision). For each node: reuse a fitting existing roster agent (`developer` / `*-tester` / `checker` / `*-deployer`), else set it to the `name` of a bespoke sub-agent spec you author INLINE in the workflow's `agent_specs` (identity/soul/agentsDoc to the template-grade bar) on the same `create` call — never the benji-CLI `create-agent` runtime flow. Empty `agent_specs` (all nodes → the main agent) only for a trivial single-node / single-role workflow; never collapse a genuinely multi-role workflow onto one agent.
- **`agent_specs`** — the top-level inline sub-agent array; one `TemplateAgent` (`name` + `identity`/`soul`/`agentsDoc` + optional `skills`/`defaultModel`/`defaultBackend`/`defaultThinking`) per genuinely-distinct role referenced by a node's `assigned_agent`. Passed in the SAME `create`/`update` call as `nodes`/`edges`; `'[]'` (or omit) for a single-role workflow. Provisioned deterministically at claim/run — the specs travel WITH the workflow.
- **`source_task_id`** — task dispatch: copy the literal `task_id` UUID from `aramb_tasks.list` (omit only for invented glue nodes). Chat dispatch: omit (or `null`) — solo has no source tasks.
- **`required_toolkits` per node is an honest list** of Composio slugs the node actually calls, grounded via `aramb_toolkits.list_toolkits`; `[]` when it touches no third-party service; never omit.
- **`toolkit` per node** is the primary slug for trigger-binding; it MUST be a member of `required_toolkits`; omit (or `null`) only when `required_toolkits` is `[]`.
- **No placeholder syntax in prompts** — no `{{env.KEY}}`, no `{{input.KEY}}`. There is no substitution layer; brahmi rejects prompts containing `{{ env.… }}`. Per-run values arrive in `<run_input>` (step 1 only); the agent reads them there.
- **Do NOT declare `env_variables`** — omit the field. The column has no runtime path in v2 and the schema rejects a non-empty map. Constant recipe values bake into prompts; secrets come from the Composio connection.
- **Trigger is recommend-and-add, not a save gate** — `trigger_choice` is optional; recommend a firing condition off the entry node (Section 4.5) and add it on approval, but save the workflow regardless of whether the user picks one.
- **Step 1's prompt must distill `<run_input>` into its `outputs.summary`** — downstream steps see only the parent's summary, never `<run_input>`.
- **For history-derived chat dispatch, generalize** — strip one-off dates / values; the recipe should run again with fresh inputs.
- `unique_id` values are sequential integers starting at 1 (never 0).
- Dependencies are expressed ONLY via the top-level `edges` array; never put `dependencies` / `depends_on` / `dependsOn` on node objects.
- `edges` must be a DAG — no cycles. Single-node workflow: pass `'[]'` or omit.
- Give the workflow a clear, descriptive name (not "Workflow 1").
- Never call `aramb_workflows.create` more than once — one shot, success or failure.
- **Close out:** task dispatch — always `aramb_tasks.update` (`done` or `failed`), then STOP; never leave `in_progress`. Chat dispatch — confirm inline in your reply text (success or failure), and call `aramb_workflows.set_schedule` yourself if the user also asked for a schedule.
