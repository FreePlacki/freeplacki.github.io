#!/usr/bin/env bash
set -euo pipefail

INPUT="content.md"
OUTPUT="content.html"

HIGHLIGHT_STYLE="tango"
EXTRA_ARGS=(
  "--standalone"
  "--mathml"
  "--highlight-style=${HIGHLIGHT_STYLE}"
  "--template=../template.html"
  "--toc"
  "--toc-depth=2" # include only h2 for the table of contents
)

echo "Building '${OUTPUT}'..."

pandoc "${INPUT}" \
  "${EXTRA_ARGS[@]}" \
  -o "${OUTPUT}"

echo "Done. Output written to ${OUTPUT}"

