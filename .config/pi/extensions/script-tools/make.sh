#!/bin/bash
# tool: make
# description: Runs `make` followed by the arguments you pass.
# param: args string optional The arguments to pass to `make`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"
source "$(dirname "${BASH_SOURCE[0]}")/include/str_to_arr.sh"

check_dependencies make
str_to_arr PI_TOOL_ARGS "${PI_TOOL_ARGS}"
make "${PI_TOOL_ARGS[@]}"
