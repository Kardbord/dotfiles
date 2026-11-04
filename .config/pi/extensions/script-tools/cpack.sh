#!/bin/bash
# tool: cpack
# description: Runs `cpack` followed by the arguments you pass.
# param: args string optional The arguments to pass to `cpack`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"
source "$(dirname "${BASH_SOURCE[0]}")/include/str_to_arr.sh"

check_dependencies cpack
str_to_arr PI_TOOL_ARGS "${PI_TOOL_ARGS}"
cpack "${PI_TOOL_ARGS[@]}"
