#!/usr/bin/env bash
# PreToolUse hook: warn on censys search --max-pages -1 pitfalls.
#
# Reads tool input JSON from stdin. Checks for:
#   1. Missing -S (streaming) on exhaustive searches
#   2. Credit cost reminder + aggregate pre-check suggestion
#
# Exit 0 = allow execution (with optional warning).
# These are advisory warnings, not blockers.

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Bail early if not a censys search command
case "$COMMAND" in
  *"censys search"*) ;;
  *) exit 0 ;;
esac

# Only check exhaustive searches
case "$COMMAND" in
  *"--max-pages -1"*|*"-p -1"*) ;;
  *) exit 0 ;;
esac

WARNINGS=""

# Check 1: exhaustive search without streaming
case "$COMMAND" in
  *"--streaming"*|*"-S"*) ;;
  *)
    WARNINGS="[censys-skills] Exhaustive search without -S: the full result set will be buffered as a single JSON array, which can use excessive memory or stall on large results. Add -S for NDJSON streaming."
    ;;
esac

# Check 2: credit cost reminder (always on exhaustive)
COST_NOTE="[censys-skills] --max-pages -1 fetches up to 100 pages (10,000 results). Consider running 'censys aggregate' first to check population size before committing credits."

if [[ -n "$WARNINGS" ]]; then
  WARNINGS="${WARNINGS}
${COST_NOTE}"
else
  WARNINGS="$COST_NOTE"
fi

printf '%s' "$WARNINGS" | jq -Rs '{"systemMessage": .}'
exit 0
