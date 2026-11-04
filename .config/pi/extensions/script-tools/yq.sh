#!/bin/bash
# tool: yq
# description: Runs `yq` followed by the arguments you pass.
# param: args string required The arguments to pass to `yq`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"

check_dependencies yq

case " $* " in
*" -i"* | *" --inplace"*)
  echo "In-place mode (-i/--inplace) is forbidden: use the edit tool to modify files instead" >&2
  exit 1
  ;;
esac

yq "$@"
