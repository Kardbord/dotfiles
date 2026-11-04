#!/bin/bash
# tool: fd
# description: Runs `fd` followed by the arguments you pass.
# param: args string required The arguments to pass to `fd`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"
source "$(dirname "${BASH_SOURCE[0]}")/include/str_to_arr.sh"

check_dependencies fd
str_to_arr PI_TOOL_ARGS "${PI_TOOL_ARGS}"

case "${PI_TOOL_ARGS[@]}" in
*-x* | *-X* | *--exec*)
  echo "The '--exec and '--exec-batch' flags are forbidden" >&2
  exit 1
  ;;
esac

fd "${PI_TOOL_ARGS[@]}"
