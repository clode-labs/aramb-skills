---
name: artifacts
description: >
  How a worker produces a real deliverable — a spreadsheet, a deck, a PDF, a
  document, a report, a data export — and proves it opens before claiming done.
  Use whenever the brief's output is a FILE rather than an answer. Covers parsing
  the artifact back, sourcing its content, labelling illustrative data, and
  handing it over so it survives the sandbox. NOT for a prose answer in chat.
---

# Artifacts — build it, open it, then claim it

A deliverable is a thing the user opens. Two failure modes account for almost every bad
one: **it does not open**, and **it contains numbers nobody can source**. Both are
avoidable with one habit each.

## Parse it back before you claim done

**Every artifact is verified after it is built, by reading it back with a different
path than the one that wrote it.** Not "the write succeeded" — exit 0 is not evidence.

- **`.xlsx` / `.csv`** — open it and read the actual cells: the sheet names, the header
  row, the row count, and one real data row. A corrupt workbook and a written file look
  identical from the writer's side.
- **`.pdf`** — render it and read text out of it. Confirm the page count and that page 1
  is not blank.
- **`.pptx` / a deck** — open it, count the slides, read the title of the first and last.
- **`.docx` / markdown / a document** — read the produced file back and check the
  headings survived.
- **Images and charts** — look at the rendered output. A chart with no data points still
  writes a valid PNG.

Your evidence is what the read-back **returned**: "12 rows across 2 sheets, headers
`name,url,posted_at`, row 1 reads …" — not "generated the spreadsheet".

## Content is real and sourced, or it is labelled

Every figure in an artifact is one of two things, and never anything in between:

1. **Real and sourced** — you observed it, and the artifact says where it came from
   (the URL, the file, the query, the date you pulled it).
2. **Illustrative** — and then it is **visibly labelled inside the artifact itself**:

   > `EXAMPLE — illustrative data, not real`

   in the sheet, on the slide, in the document. Not only in your report — the artifact
   travels without your report attached, and an unlabelled placeholder becomes a fact
   the moment someone forwards it.

**Never invent a number to fill a cell.** A blank with a note beside it is honest; a
plausible figure is fabrication, and fabrication in a file the user will forward is the
worst failure available to you.

Related discipline, when the sources disagree:

- **Conflicting numbers mean conflicting definitions until proven otherwise.** Reconcile
  the definitions, geographies, dates and units before you reconcile the values. Most
  conflicts are two different things wearing one label.
- **A number you cannot reproduce is a flag, not a choice.** Put both figures in with
  their sources and say they disagree. Never quietly pick whichever one looks closer to
  what was expected.
- **Declare the authoritative artifact.** When records disagree, name which one is
  authoritative and why (source document beats keyed copy; live page beats cached file),
  quantify the delta, and cite the exact cells or lines.
- **Garbage input gets named, not processed.** If the input is noise, a fixture, or the
  wrong file, the deliverable is the finding that the input is broken. A confident
  artifact built on noise is worse than no artifact.

## Handing it over so it survives

The sandbox is disposable; the work is not.

- Write the file under your working directory, at an **absolute path**.
- Attach it on the close, do not describe it:

```
aramb_mcp.tasks_update(
  project_id = "<PROJECT_ID>", task_id = "<TASK_ID>",
  status     = "done",
  summary    = "<what is now true, with the read-back evidence>",
  artifacts  = [{"kind":      "blob",
                 "path":      "/home/node/workspace/<WD>/report.pdf",
                 "name":      "report.pdf",
                 "mime_hint": "application/pdf"}]
)
```

- **`kind="blob"`** stages the bytes so the file reaches the user on any surface —
  WhatsApp, Slack, email, a share link. `kind="file"` is only an in-workspace pointer
  with no download; use it only when the live in-workspace file is specifically what is
  wanted.
- A deliverable arrives as a **usable artifact**, never as a description of one.

## Checkpoint before you run out

On any long build or collection run, write partial results to disk **as you go**, with
per-item evidence. If you are cut off — budget, timeout, killed session — partial
verified results outlive you and unreported work does not exist. When you feel a limit
approaching, stop taking new work and emit the checkpoint: what is complete, exactly
where the file is, what remains.

A limit is not a deadline to finish at any cost. Never lower the verification standard
because room is running out, and never cross an irreversible boundary to beat a budget.
