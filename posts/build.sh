#!/usr/bin/env bash
set -euo pipefail

# ─── INPUTS ─────────────────────────────────────────────────────────────────────
INPUT="content.md"
OUTPUT="content.html"
TITLE="${1:-Untitled}"  # Use first argument, or fallback to "Untitled"

# ─── CSS FILES ─────────────────────────────────────────────────────────────────
CSS_FILES=(
  "../../custom-highlight.css"
  "../../styles.css"
  "../../post.css"
)

# ─── PANDOC OPTIONS ────────────────────────────────────────────────────────────
HIGHLIGHT_STYLE="tango"
EXTRA_ARGS=(
  "--standalone"
  "--mathml"
  "--highlight-style=${HIGHLIGHT_STYLE}"
  "--metadata=title=${TITLE}"
)

# Add all the --css options
for css in "${CSS_FILES[@]}"; do
  EXTRA_ARGS+=("--css=${css}")
done

# ─── BUILD ─────────────────────────────────────────────────────────────────────
echo "📄 Building '${OUTPUT}' with title: '${TITLE}'…"

pandoc "${INPUT}" \
  "${EXTRA_ARGS[@]}" \
  -o "${OUTPUT}"

echo "✅ Done. Output written to ${OUTPUT}"

