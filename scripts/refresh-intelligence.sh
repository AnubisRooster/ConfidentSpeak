#!/bin/sh
# Updates the local GitNexus index and graphify knowledge graph to match the
# current working tree. Called by the repo's git hooks after commits and
# merges, and can be run by hand anytime:
#
#   ./scripts/refresh-intelligence.sh
#
# Both output trees are intentionally gitignored: GitNexus stores a binary
# KuzuDB index (tens of MB) and graphify writes graphify-out/. They are meant
# to be regenerated locally on demand rather than committed, so this script
# re-derives them incrementally (no API key, no network model calls).

set -u

cd "$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

# 1. GitNexus: incremental re-index of the working tree.
if [ -f .gitnexus/run.cjs ]; then
    if ! node .gitnexus/run.cjs analyze --index-only >/dev/null 2>&1; then
        echo "[intelligence] gitnexus analyze failed; run 'gitnexus analyze' from the repo root" >&2
    fi
else
    echo "[intelligence] no .gitnexus/run.cjs — run 'npx gitnexus analyze' once to bootstrap" >&2
fi

# 2. graphify: re-extract changed code files and rebuild the graph + report.
if command -v graphify >/dev/null 2>&1; then
    # Deterministic clustering: pin PYTHONHASHSEED so community IDs don't churn.
    if ! PYTHONHASHSEED=0 graphify . --code-only --update >/dev/null 2>&1; then
        echo "[intelligence] graphify rebuild failed; run 'graphify . --code-only --update' by hand" >&2
    fi
else
    echo "[intelligence] graphify CLI not on PATH — install via 'uv tool install graphifyy'" >&2
fi

exit 0