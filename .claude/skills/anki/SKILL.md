---
name: anki
description: Turn lecture slides (PDF or Markdown) into Anki flashcards for an HSLU course, stored as a diffable TSV source file and committed. Use when the user gives a slides file plus a subject/course name and wants flashcards, as a companion to (or independent of) that subject's cheatsheet.
---

# Anki card authoring skill

Companion to the `cheatsheet` skill, same input pipeline, different output: instead of a dense
exam-reference sheet, this produces individual atomic recall cards for spaced repetition. A
subject can have both a cheatsheet and an Anki deck side by side — they live in the same
`src/<subject>/` folder but are unrelated files; running one skill doesn't require the other.

The user works through a course gradually, one lecture/chapter at a time — expect this skill to
run repeatedly over time for the same subject. Always re-read the existing card file fresh; never
assume state from a previous run.

Read `CLAUDE.md` at the repo root first if you haven't this session, for repo conventions
(commit style, German content, UTF-8 Umlauts).

## Inputs

1. A path to a **PDF** or **Markdown** file with the lecture slides/content.
2. A **subject** name — the course folder under `src/` (e.g. `dmath-algo`, `lial`, `ana-g`).

If either is missing, or the subject doesn't match an existing `src/` folder and isn't clearly a
new course, ask rather than guessing.

## Output format: `src/<subject>/anki.tsv`

One TSV file per subject, appended to over time — not regenerated from scratch. It mixes
`Standard` (Anki's Basic notetype) and `Lückentext` (Anki's Cloze notetype) notes in a single file
using Anki's text-import header directives (supported by the installed Anki version). If the file
doesn't exist yet, create it with this exact header before any card rows:

```
#separator:tab
#html:true
#columns:notetype	deck	front	back	tags
#notetype column:1
#deck column:2
#tags column:5
```

Each subsequent line is one card:

```
Standard	<subject>	<question>	<answer>	<subject>::<chapter-slug>
Lückentext	<subject>	<text with {{c1::hidden part}}>		<subject>::<chapter-slug>
```

- Column 1: `Standard` (Basic-style) or `Lückentext` (Cloze-style). **This must exactly match an
  existing notetype name in the target Anki collection** — Anki's `#notetype column` import
  directive resolves by literal string match, and this user's Anki runs in German, where the
  built-in notetypes are named "Standard"/"Lückentext" rather than the English "Basic"/"Cloze".
  Getting this wrong doesn't error loudly: the file parses fine and every row silently comes back
  `Skipped` in Anki's import log (real incident — see commit `70074cf`, `git log --oneline
  src/ugdm/anki.tsv`). If a future session is unsure which names apply, ask the user to check
  Tools → Manage Note Types before writing the file.
- Column 2 (deck): always the bare subject name, e.g. `dmath-algo` — one flat deck per subject.
- Column 3: Standard → the front/question; Lückentext → the full cloze text (with `{{c1::...}}`
  markup).
- Column 4: Standard → the back/answer; Lückentext → leave empty (or use for "Back Extra" context,
  e.g. a source reference), since Cloze-style notes don't use a separate back field the same way.
- Column 5 (tags): `<subject>::<chapter-slug>`, space-separated if more than one tag. This is what
  gives chapter-level granularity — decks stay flat per subject, tags carry the chapter filter.
  Slugify the chapter/topic name (lowercase, hyphens) consistently with how it's named in the
  matching cheatsheet section, if one exists.
- No literal tabs or newlines inside a field. `#html:true` is set, so use `<br>` for line breaks
  within a field if ever needed, and escape any literal `<`/`&` that isn't meant as HTML.

## Steps

### 1. Resolve the subject

Confirm `src/<subject>/` — it may already contain a `cheatsheet.tex`, an `anki.tsv`, both, or
neither. Creating one doesn't require or affect the other. If the subject folder doesn't exist at
all, confirm with the user before creating it (avoid a typo'd new folder).

### 2. Get the slide content as Markdown

Same as the cheatsheet skill:
- `.md` input: read directly.
- `.pdf` input: convert via `markitdown` into a throwaway temp dir, read the result, delete the
  temp dir immediately after:

  ```bash
  tmp=$(mktemp -d)
  markitdown "<input.pdf>" -o "$tmp/slides.md"
  # read "$tmp/slides.md"
  rm -rf "$tmp"
  ```

### 3. Read the existing anki.tsv before writing anything

If `src/<subject>/anki.tsv` already exists, read it fully first. This is how you avoid: adding a
near-duplicate card for a fact already covered, reusing a chapter tag inconsistently, and losing
track of the notetype/column header (never rewrite or duplicate the `#` header lines — they go
once at the very top of the file only).

### 4. Draft the cards

This is not a condensed reference like the cheatsheet — it's atomic recall practice. Reshape the
slide content accordingly, don't just port over what a cheatsheet `mainbox` would say:

- **Minimum information principle**: one fact per card. Split compound statements into multiple
  cards rather than cramming a multi-part answer into one back field.
- Prefer **Standard** (Basic-style) for definitions, "what is X"/"why does X hold"/procedural
  steps, comparisons.
- Prefer **Lückentext** (Cloze-style) for formulas, fixed terminology, and structured sequences
  (e.g. proof steps, the IA/IV/IS layout from Induktion) where blanking out one part of a fixed
  structure is more natural than a question/answer pair.
- Cards must be self-contained — understandable without having the slides open. No "as shown
  above", no unexplained abbreviations.
- Write in German, matching the course material. Use direct UTF-8 Umlauts (`ü`, `ö`, `ä`, `ß`) —
  double-check your own output before writing, this has caused real encoding bugs in this repo
  before (see `CLAUDE.md`).
- Skip trivia that isn't worth long-term recall (e.g. slide numbers, lecturer's name) — this is
  study material, not a transcript.

### 5. Append to the file

Add the new rows after the existing ones (or after the header, if the file is new). Don't
reorder or touch existing rows.

### 6. Sanity-check before committing

- Every row has exactly 5 tab-separated columns.
- No literal tabs inside a field's text (that would silently shift columns).
- `Lückentext` rows actually contain `{{c1::...}}` (or `c2`, etc.) syntax in column 3.
- No accidental duplicate header lines partway through the file.
- Column 1 values are exactly `Standard` or `Lückentext` (not `Basic`/`Cloze`) — see the notetype
  note above.

### 7. Commit (do not push)

Stage only `src/<subject>/anki.tsv`. Commit message, mirroring this repo's existing style:

`feat: add anki cards about <Topic>`

Do **not** push. Tell the user the commit is local and ask if they'd like it pushed.

### 8. Report back, and remind about import

State how many `Standard` and `Lückentext` cards were added and under which chapter tag. Remind
the user this is a source file, not a live Anki deck: they import/re-import it into Anki via
**File → Import** and pick "Update" for existing notes if re-importing after edits (AnkiConnect
isn't set up in this environment, so there's no automatic sync to a running Anki instance).
