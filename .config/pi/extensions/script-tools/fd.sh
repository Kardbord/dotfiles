#!/bin/bash
# tool: fd
# description: Runs `fd` followed by the arguments you pass.
# param: args string required The arguments to pass to `fd`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"

check_dependencies fd

case " $* " in
*" -x "* | *" -X "* | *" --exec "* | *" --exec-batch "*)
  echo "The '--exec' and '--exec-batch' flags are forbidden" >&2
  exit 1
  ;;
esac

fd "$@"
