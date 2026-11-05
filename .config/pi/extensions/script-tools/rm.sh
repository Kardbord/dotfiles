#!/bin/bash
# tool: rm
# description: Deletes files (no recursion) with the arguments you pass.
# param: args string required The paths to delete, optionally with allowed flags like `-v`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"

check_dependencies rm

if (($# == 0)); then
  echo "No paths given; nothing to delete." >&2
  exit 1
fi

for arg in "$@"; do
  case "$arg" in
  # Recursion and force, with or without an attached value:
  -[rRf]* | --recursive | --recursive=* | --force | --force=*)
    echo "The '--recursive'/'-r'/'-R' and '--force'/'-f' flags are forbidden" >&2
    exit 1
    ;;
  # Interactive: prompts read from stdin regardless of TTY status
  # (coreutils only TTY-gates the default write-protected prompt),
  # so -i/-I either hangs on an inherited TTY or silently skips
  # everything on EOF and still exits 0.
  -[iI]* | --interactive | --interactive=*)
    echo "The '--interactive'/'-i'/'-I' flags are forbidden" >&2
    exit 1
    ;;
  # Short-flag clusters that embed any forbidden letter anywhere
  # (-fr, -rvf, -iv, ...). No harmless rm short flag contains
  # r/R/f/i/I, so any cluster embedding one is a forbidden flag.
  -[!-]*[rRfiI]*)
    echo "Forbidden flag cluster: '$arg'" >&2
    exit 1
    ;;
  esac
done

# `-v` keeps the tool result evidential: one line per deleted path.
# No prompt can occur here: prompt flags are rejected above, and the
# default write-protected prompt only fires on a TTY stdin (which
# would fail loudly, not hang, when stdin is a pipe).
rm -v -- "$@"
