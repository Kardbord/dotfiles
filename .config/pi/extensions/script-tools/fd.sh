#!/bin/bash
# tool: fd
# description: Runs `fd` followed by the arguments you pass.
# param: args string required The arguments to pass to `fd`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"

check_dependencies fd

for arg in "$@"; do
  case "$arg" in
  # --exec / --exec-batch, with or without an attached value:
  --exec | --exec-batch | --exec=* | --exec-batch=*)
    echo "The '--exec' and '--exec-batch' flags are forbidden" >&2
    exit 1
    ;;
  # Short flags: -x / -X, attached values (-xfoo), and combined
  # clusters that embed them (-jx, -jXfoo, ...).
  -[xX]* | -[!-]*[xX]*)
    echo "The '--exec' and '--exec-batch' flags are forbidden" >&2
    exit 1
    ;;
  esac
done

fd "$@"
