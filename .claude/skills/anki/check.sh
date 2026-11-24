#!/usr/bin/env bash
# Sanity checks for an anki.tsv source file (see SKILL.md step 6).
# Usage: check.sh <path/to/anki.tsv>
# Prints one line per problem; prints nothing and exits 0 when the file is clean.
#
# These checks live in a separate script on purpose: the skill loader substitutes positional
# variables like $1/$3 in SKILL.md with the skill's arguments, which silently broke the awk
# field references when they were inlined there.
set -u
f="${1:?usage: check.sh <anki.tsv>}"
[ -f "$f" ] || { echo "no such file: $f"; exit 2; }

out=$(
awk -F'\t' '!/^#/ && NF!=5 {print NR": "NF" columns (expected 5)"}' "$f"
awk -F'\t' '!/^#/ && $1!="Standard" && $1!="Lückentext" {print NR": bad notetype \""$1"\""}' "$f"
awk -F'\t' '$1=="Lückentext" && $3!~/\{\{c[0-9]+::/ {print NR": Lückentext without cloze"}' "$f"
awk '/^#/ && NR>6 {print NR": header line inside body"}' "$f"
grep -nP '<(?![a-zA-Z/!])' "$f"              | sed 's/^/bare < (use \&lt;): /'
grep -nP '&(?![a-zA-Z]+;|#[0-9]+;)' "$f"     | sed 's/^/bare \& (use \&amp;): /'
grep -n '}}}' "$f"                           | sed 's/^/cloze closed by LaTeX brace: /'
grep -nP '\$[^\s$]([^$\t]*[^\s$])?\$' "$f"   | sed 's/^/$...$ math (use \\( \\)): /'
grep -nP '¨|\x{0308}' "$f"                   | sed 's/^/mangled Umlaut: /'
cut -f3 "$f" | grep -v '^#' | sort | uniq -d | sed 's/^/duplicate first field: /'
)
[ -z "$out" ] && exit 0
printf '%s\n' "$out"
exit 1
