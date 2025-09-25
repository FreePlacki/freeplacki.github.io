#!/usr/bin/env bash
set -euo pipefail

INPUT="content.md"
OUTPUT="index.html"

EXTRA_ARGS=(
  "--standalone"
  "--no-highlight"
  "--mathml"
  "--template=../template.html"
  "--toc"
  "--toc-depth=2" # include only h2 for the table of contents
)

echo "Building '$OUTPUT'..."

pandoc "$INPUT" \
  "${EXTRA_ARGS[@]}" \
  -o "$OUTPUT" \
&& \
../htmlhl $OUTPUT > "$OUTPUT.tmp" \
&& \
mv "$OUTPUT.tmp" $OUTPUT

echo "Done. Output written to $OUTPUT"

