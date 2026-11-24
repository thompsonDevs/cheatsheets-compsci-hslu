---
name: anki
description: Turn lecture slides (PDF or Markdown) into Anki flashcards for an HSLU course, stored as a diffable TSV source file and committed. Use when the user gives a slides file plus a subject/course name and wants flashcards, as a companion to (or independent of) that subject's cheatsheet.
argument-hint: <slides.pdf|slides.md> <subject>
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

Paths often contain spaces (e.g. `.../SW11/Chinesischer Restsatz.md`), so don't split the
arguments on whitespace naively: the **subject is the last token**, everything before it is the
path. Verify the path exists before continuing.

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
  within a field if ever needed.
- **HTML escaping:** because of `#html:true`, every literal `<`, `>` and `&` that isn't HTML
  markup must be written as `&lt;`, `&gt;`, `&amp;`, **including inside MathJax** (MathJax sees
  the decoded character, so `\(a &lt; b\)` renders as a < b). A bare `<` can swallow the rest of
  the field as a broken tag without any import error.

### Note identity: the first field is the key

There is no GUID column, so on re-import Anki recognises an existing note **only by its first
field** (column 3: the Standard question, or the whole Lückentext text). Consequences:

- **Never edit column 3 of an existing row.** A changed first field re-imports as a *new* note,
  and the old one stays in the collection as a duplicate with its review history.
- Editing column 4 (answer/extra) or the tags of an existing row is safe: re-importing with
  "Update" overwrites the matched note.
- If a card's question or cloze text really must change (e.g. it was wrong), change it, and
  tell the user explicitly in the step-8 report which old note to delete in Anki (quote its old
  front text).

## Steps

### 1. Resolve the subject

Confirm `src/<subject>/` — it may already contain a `cheatsheet.tex`, an `anki.tsv`, both, or
neither. Creating one doesn't require or affect the other. If the subject folder doesn't exist at
all, confirm with the user before creating it (avoid a typo'd new folder).

### 2. Get the slide content

Follow **step 2 of `.claude/skills/cheatsheet/SKILL.md` exactly** (read that section now; it is
the single source of truth for the input pipeline). It covers Markdown notes that only embed
PDFs, the `markitdown` → `pdftotext` → `pdftoppm` fallback chain for PDFs (including image-only
solution PDFs), temp-dir cleanup, and the warning that extracted numbers can be garbled. Don't
re-implement a shorter version here.

### 3. Read the existing anki.tsv before writing anything

If `src/<subject>/anki.tsv` already exists, read it fully first (decks reach ~1000 lines; if one
is longer than a single `Read` window, read it in parts, or at minimum grep the existing tags with
`cut -f5 anki.tsv | sort | uniq -c` and read every row whose tag or topic overlaps the new slides).
This is how you avoid: adding a near-duplicate card for a fact already covered, reusing a chapter
tag inconsistently, and losing track of the notetype/column header (never rewrite or duplicate the
`#` header lines — they go once at the very top of the file only).

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
- **Formeln:** write math as MathJax, which Anki renders natively: inline `\( ... \)`, display
  `\[ ... \]` (not `$...$`, which Anki doesn't render). Simple expressions without special
  symbols (e.g. `n = 5`) can stay plain text. Inside a cloze, a `}}` in the LaTeX ends the cloze
  early: separate closing braces with a space, e.g. `{{c1::\(\frac{a}{b} \)}}` or
  `\(\frac{a}{ {{c1::b}} }\)`, never `{{c1::\frac{a}{b}}}`. Remember the HTML-escaping rule above
  for `<`, `>`, `&`.
- **Verify every number.** A wrong answer card is worse than a wrong line on the cheatsheet:
  spaced repetition drills it into memory. Recompute every numeric answer and worked-example
  value with a quick `python3 -I -c '...'`, and compare against the solutions PDF if there is
  one. If the slides disagree with your computation, work out which is the extraction error
  instead of copying the slide value.

### 5. Append to the file

Add the new rows after the existing ones (or after the header, if the file is new). Don't
reorder or touch existing rows (see "Note identity" above for why column 3 is untouchable).

### 6. Sanity-check before committing

Run the check script that sits next to this file, from the repo root:

```bash
bash .claude/skills/anki/check.sh src/<subject>/anki.tsv
```

**It must print nothing and exit 0**; fix every row it reports and re-run. It checks: exactly 5
columns per row (also catches literal tabs inside a field), column 1 is `Standard`/`Lückentext`
(catches `Basic`/`Cloze`, see the notetype note above), every Lückentext row has a cloze, no `#`
header line inside the body, no bare `<` or `&` (must be `&lt;`/`&amp;`), no `}}}` (cloze closed
by a LaTeX brace), no `$...$` math, no mangled Umlauts, and no duplicate first fields.

Don't inline these checks back into this file: the skill loader replaces positional shell/awk
variables (dollar sign + digit) in SKILL.md with the skill's arguments, which silently turned the
awk field references into garbage and made the checks pass vacuously.

### 7. Commit (do not push)

Stage only `src/<subject>/anki.tsv`. Commit message, mirroring this repo's existing style:

`feat: add anki cards about <Topic>`

Do **not** push. Tell the user the commit is local and ask if they'd like it pushed.

### 8. Report back, and remind about import

State:
- how many `Standard` and `Lückentext` cards were added, under which chapter tag, and the new
  total card count of `anki.tsv` (`grep -vc '^#' anki.tsv`);
- any input problems you worked around (missing tool, image-only PDF, slide values that were
  wrong and corrected);
- if an existing row's column 3 was changed, which old note (quote its old front) the user must
  delete in Anki.

Remind the user this is a source file, not a live Anki deck: they import it into Anki via
**File → Import**, choosing "Update" for existing notes. Update only matches notes whose first
field is unchanged; new rows come in as new notes. (AnkiConnect isn't set up in this environment,
so there's no automatic sync to a running Anki instance.)
