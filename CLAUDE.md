# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

LaTeX exam cheatsheets for Thomas Schnyder's BSc Computer Science studies at HSLU. Each course
gets one dense, multi-page, landscape A4 cheatsheet used as allowed reference material during
exams. Content is German.

## Structure

```
src/
  template/
    template.tex     # canonical starting point / style reference for new cheatsheets
    template.pdf
  <course>/
    cheatsheet.tex    # source for that course's cheatsheet
    cheatsheet.pdf    # compiled output, committed alongside the source
```

Courses so far: `ana-g` (Analysis), `dmath-algo` (Diskrete Mathematik & Algorithmen), `lial`
(Lineare Algebra). Add new courses by copying `src/template/template.tex` into
`src/<new-course>/cheatsheet.tex`.

Both `cheatsheet.tex` and the compiled `cheatsheet.pdf` are tracked in git — always regenerate
and commit the PDF together with a `.tex` change. Build artifacts (`.aux`, `.log`, `.out`,
`.fls`, `.fdb_latexmk`, `.gz`) are gitignored.

## Document conventions (see `src/template/template.tex` for the full example)

- `scrartcl`, `fontsize=7pt`, landscape A4, 4-column `flowfram` layout (`\Ncolumn{4}`) — content
  is meant to be dense, not sparse.
- Two box types via `tcolorbox`:
  - `mainbox` (green) — definitions, theorems, important formulas.
  - `subbox` (gray) — examples, remarks, worked problems, secondary info.
- Recurring content patterns worth reusing when they fit (see `dmath-algo`'s Induktion appendix
  for a full example): `Denkprozess` (think-aloud steps before a proof), `Merkregel`/`Schlüsselidee`
  mnemonics, `Häufige Fehler & Tipps` boxes, `Zusammenfassung`/checklist boxes at the end of a
  topic.
- `\section{...}` per topic/chapter; an `Appendix` section (`\section{Appendix}`) holds
  supplementary deep-dives added after the main chapters.
- Encoding: `inputenc[utf8]`, no `babel`. Type German Umlauts as direct UTF-8 characters
  (`ü`, `ö`, `ä`, `ß`) — never as combining-diacritic sequences (e.g. `¨ u`) or the text will
  render broken. This has been a recurring bug (see commit `e5efeda "fix: Umlaute"`); always
  re-check generated/edited German text for mangled Umlauts before committing.

## Build

```bash
cd src/<course>
latexmk -pdf cheatsheet.tex      # preferred
# or: pdflatex cheatsheet.tex (run twice if layout/box positions look off)
```

`pdflatex` and `latexmk` are available locally. After compiling, check the `.log` for
`Overfull \hbox` warnings — with a fixed 4-column width, overfull boxes are the most common
defect when adding content (long formulas, wide tables, long inline math). Fix by shortening
text, breaking formulas across `align*` lines, or abbreviating table headers — see the "TIPS
FOR AVOIDING OVERFULL BOXES" comment block at the end of `template.tex`.

## Workflow / commit style

History shows two recurring kinds of commits:
- `feat: add chapter/appendix about <Topic>` — new `\section`/`\subsection` content.
- `fix: ...` — overfull-box fixes, Umlaut fixes, conciseness passes, typo/title fixes.

Keep that style: content additions and cleanup fixes as separate, small, descriptively-scoped
commits.
