---
name: cheatsheet
description: Add a chapter/section to an HSLU cheatsheet from lecture slides (PDF or Markdown), following this repo's LaTeX house style, then compile and commit. Use when the user gives a slides file (or already-converted .md) plus a subject/course name and wants it turned into cheatsheet content.
argument-hint: <slides.pdf|slides.md> <subject>
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

Paths often contain spaces (e.g. `.../SW11/Chinesischer Restsatz.md`), so don't split the
arguments on whitespace naively: the **subject is the last token**, everything before it is the
path. Verify the path exists before continuing.

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

### 2. Get the slide content

**Markdown input.** Read it. Notes from the Obsidian vault often contain little more than PDF
embeds (`![[DMATH-CODE-Serie11.pdf]]`) and an empty notes section. If so, resolve each embed to
the PDF next to the note (fall back to `find <vault> -name '<file>.pdf'`) and handle those PDFs as
below. Use **all** embedded PDFs: a `-final`/solutions variant usually holds the worked
solutions to the slide exercises. Any real prose in the note is extra content to include too.

**PDF input.** Extract text into a throwaway temp directory and delete it afterwards. Use the
first tool that is available and produces text:

1. `markitdown "<input.pdf>" -o "$tmp/slides.md"` (may not be installed)
2. `pdftotext -layout "<input.pdf>" "$tmp/slides.txt"`
3. If the extracted text is empty or near-empty, the PDF has no text layer (typical for OneNote
   exports of handwritten solutions): render pages with `pdftoppm -r 60 -png "<input.pdf>"
   "$tmp/p"` and read the page images visually. Raise `-r` only for pages that are hard to read.

```bash
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# extract / render into "$tmp", read the results
```

Keep the `trap` (or equivalent) so the temp dir is removed even if something fails midway.
Extracted text can garble digits (overlaid text produced "m₁ = 55" for `m₁ = 5`), so treat
numbers from the extraction as suspect until step 4 has verified them.

### 3. Read the current cheatsheet before writing anything

Cheatsheets grow past 2000 lines, longer than a default `Read` window, so a plain "read the
file" silently truncates exactly the end where new content goes. Instead:

1. Get the outline:
   `grep -nE '\\(sub)*section\{|\\end\{document\}|TIPS FOR AVOIDING' src/<subject>/cheatsheet.tex`
2. Read the **last chapter through the end of the file** in full (style, terminology, the
   insertion point).
3. For every existing section whose topic overlaps the new slides, read that range too.
4. Read the preamble once if you need its macros (e.g. `\Mod`, `\Div`, `\N`).

You need this to:
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
- **Verify every number you put on the sheet.** This is exam reference material; a wrong
  intermediate value is worse than a missing one. Recompute each worked example and every
  intermediate value (residues, inverses, sums, probabilities…) with a quick
  `python3 -I -c '...'`, and compare the results with the solutions PDF if there is one. If
  the slides and your computation disagree, work out which is the extraction error; don't copy
  the slide value blindly.

### 5. Insert into the file

Wrap the new content in its own `\section{<Topic>}` (or `\subsection{}` if it's clearly a
sub-topic of an existing section covering the same slide deck's theme). If the file's chapters
open with a banner comment, use the same one:

```latex
% ============================================================================
% SECTION: <TOPIC IN CAPS>
% ============================================================================
\section{<Topic>}
```

Insertion point, first match wins:
1. If the file has a `\section{Appendix}`, insert new regular chapter content **before** it, so
   Appendix stays last.
2. Otherwise, if the file ends with the `% TIPS FOR AVOIDING OVERFULL BOXES` comment block, insert
   **before** that block (i.e. right after the last chapter), so the tips stay at the end.
3. Otherwise insert immediately before `\end{document}`.

### 6. Compile and check

```bash
cd src/<subject>
latexmk -pdf -interaction=nonstopmode -halt-on-error cheatsheet.tex
```

- **The build must succeed first.** If `latexmk` exits non-zero, find the error with
  `grep -nA2 '^! [^\\]' cheatsheet.log` (the `l.<N>` line below it is the source line), fix it,
  and recompile. Never move on to step 7 after a failed build: the old `cheatsheet.pdf` would
  still be on disk and get committed as if it were current. (Don't grep plain `^! `: `Underfull`
  warnings dump font lines like `! \OMS/cmsy/...` that are not errors. The exit code is what
  decides.)
- Check the `.log` for `Overfull \hbox` warnings introduced by your new content. The log reports
  `at lines N--M`; only warnings whose line numbers fall inside your inserted range are yours. If
  found, revise (shorten text, split formulas across `align*`, abbreviate table headers) and
  recompile. Iterate a few times; don't loop forever chasing pre-existing overfull warnings
  unrelated to your change.
- Grep your inserted text for stray `¨` and combining diacritics (U+0308, e.g.
  `grep -nP '¨|\x{0308}'` on the diff) or other mangled-Umlaut artifacts.
- **Look at the result.** Render the pages that hold the new chapter
  (`pdftoppm -r 110 -png -f <first> -l <last> cheatsheet.pdf "$tmp/c"`) and view them: check for
  awkwardly wrapped box titles, tables that look wrong, or stretched lines. Fix what's ugly and
  recompile.
- Run `latexmk -c` afterwards to remove the generated `.aux`/`.log`/`.fls`/`.fdb_latexmk` (they're
  gitignored and not needed once the PDF exists).

### 7. Commit (do not push)

Stage exactly the changed files for that subject: `src/<subject>/cheatsheet.tex` and
`src/<subject>/cheatsheet.pdf`. Never `git add -A`.

Commit message follows the repo's existing convention from `git log`:
- New chapter: `feat: add chapter about <Topic>`
- New appendix entry: `feat: add appendix about <Topic>`

Do **not** push. Tell the user the commit is local and ask if they'd like it pushed.

### 8. Report back

Briefly state: which topic/section was added, to which file, whether the build was clean (no new
overfull-hbox warnings), and the new page count if it changed meaningfully. Also mention any
input problems you worked around (missing tool, image-only PDF, numbers on the slides that were
wrong and corrected).
