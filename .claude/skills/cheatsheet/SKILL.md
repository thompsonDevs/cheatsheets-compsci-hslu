---
name: cheatsheet
description: Add a chapter/section to an HSLU cheatsheet from lecture slides (PDF or Markdown), following this repo's LaTeX house style, then compile and commit. Use when the user gives a slides file (or already-converted .md) plus a subject/course name and wants it turned into cheatsheet content.
---

# Cheatsheet authoring skill

Turns one set of lecture slides into a new chapter in `src/<subject>/cheatsheet.tex`, compiles it,
and commits the result. The user works through a course gradually — expect this skill to run
once per chapter/lecture, repeatedly, over time. Never assume state from a previous run; always
re-read the current file fresh.

Read `CLAUDE.md` at the repo root first if you haven't already this session — it documents the
box conventions (`mainbox`/`subbox`), recurring content patterns (`Denkprozess`, `Merkregel`,
`Häufige Fehler & Tipps`, `Zusammenfassung`), the Umlaut encoding pitfall, and the commit style.
This skill assumes that context; it doesn't repeat it below.

## Inputs

Expect two arguments from the user's request:
1. A path to a **PDF** or **Markdown** file containing the lecture slides/content.
2. A **subject** name — the course folder under `src/` (e.g. `dmath-algo`, `lial`, `ana-g`).

If either is missing or the subject is ambiguous (doesn't match an existing `src/` folder and
isn't clearly a new course), ask the user rather than guessing.

## Steps

### 1. Resolve the subject folder

- If `src/<subject>/cheatsheet.tex` exists, that's your target file.
- If it doesn't exist, confirm with the user that they want a **new** course cheatsheet (easy to
  create a typo'd duplicate folder otherwise), then scaffold it by copying
  `src/template/template.tex` to `src/<subject>/cheatsheet.tex` and updating the `\title{}` to
  `Cheatsheet <SUBJECT>` (uppercased, matching the existing ones) and `\author{}`/`\date{}` to
  match the other cheatsheets in the repo.

### 2. Get the slide content as Markdown

- If the input is already `.md`, just read it directly — no temp dir needed.
- If the input is a `.pdf`, convert it with `markitdown` into a throwaway temp directory, read the
  result, then delete the temp directory. Don't leave converted intermediates lying around:

  ```bash
  tmp=$(mktemp -d)
  markitdown "<input.pdf>" -o "$tmp/slides.md"
  # read "$tmp/slides.md"
  rm -rf "$tmp"
  ```

  Use a `trap 'rm -rf "$tmp"' EXIT` (or equivalent) if running this across multiple commands, so
  the temp dir is cleaned up even if something fails midway.

### 3. Read the current cheatsheet before writing anything

Read the full existing `src/<subject>/cheatsheet.tex`. You need this to:
- avoid re-adding a topic that's already covered,
- match the existing section numbering/ordering and terminology already used in that file,
- find the right insertion point (see step 5).

### 4. Draft the new content

Turn the slide content into cheatsheet material — don't just transcribe slides verbatim. Condense
to exam-reference density:
- `mainbox` for definitions, theorems, formulas the slides present as the core takeaway.
- `subbox` for examples, worked problems, remarks.
- Use the recurring patterns from `CLAUDE.md` (`Denkprozess`, `Merkregel`/`Schlüsselidee`,
  `Häufige Fehler & Tipps`, a closing `Zusammenfassung`/checklist box) where the topic fits them —
  don't force all of them into every chapter.
- Write in German. Type Umlauts as direct UTF-8 characters (`ü`, `ö`, `ä`, `ß`) — double check
  your own output for mangled diacritics before writing the file, this has broken builds before.
- Keep lines/formulas short given the 4-column 7pt layout — see "TIPS FOR AVOIDING OVERFULL
  BOXES" in `src/template/template.tex`.

### 5. Insert into the file

Wrap the new content in its own `\section{<Topic>}` (or `\subsection{}` if it's clearly a
sub-topic of an existing section covering the same slide deck's theme).

- If the file has a `\section{Appendix}`, insert new regular chapter content **before** it, so
  Appendix stays last.
- Otherwise insert immediately before `\end{document}`.

### 6. Compile and check

```bash
cd src/<subject>
latexmk -pdf cheatsheet.tex
```

- Check the `.log` for `Overfull \hbox` warnings introduced by your new content. If found, revise
  (shorten text, split formulas across `align*`, abbreviate table headers) and recompile. Iterate
  a few times; don't loop forever chasing pre-existing overfull warnings unrelated to your change.
- Grep your inserted text for stray `¨` or other mangled-Umlaut artifacts.
- Run `latexmk -c` afterwards to remove the generated `.aux`/`.log`/`.fls`/`.fdb_latexmk` (they're
  gitignored and not needed once the PDF exists).

### 7. Commit (do not push)

Stage exactly the changed files for that subject — `src/<subject>/cheatsheet.tex` and
`src/<subject>/cheatsheet.pdf` (plus the two template-derived files if this was a new course) —
never `git add -A`.

Commit message follows the repo's existing convention from `git log`:
- New chapter: `feat: add chapter about <Topic>`
- New appendix entry: `feat: add appendix about <Topic>`

Do **not** push. Tell the user the commit is local and ask if they'd like it pushed.

### 8. Report back

Briefly state: which topic/section was added, to which file, whether the build was clean (no new
overfull-hbox warnings), and the new page count if it changed meaningfully.
