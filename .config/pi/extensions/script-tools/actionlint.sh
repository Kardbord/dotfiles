#!/bin/bash
# tool: actionlint
# description: Runs `actionlint` followed by the arguments you pass.
# param: args string required The arguments to pass to `actionlint`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"
source "$(dirname "${BASH_SOURCE[0]}")/include/str_to_arr.sh"

check_dependencies actionlint
str_to_arr PI_TOOL_ARGS "${PI_TOOL_ARGS}"
actionlint "${PI_TOOL_ARGS[@]}"
