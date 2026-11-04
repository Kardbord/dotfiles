#!/bin/bash
# tool: jq
# description: Runs `jq` followed by the arguments you pass.
# param: args string required The arguments to pass to `jq`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"
source "$(dirname "${BASH_SOURCE[0]}")/include/str_to_arr.sh"

check_dependencies jq
str_to_arr PI_TOOL_ARGS "${PI_TOOL_ARGS}"
jq "${PI_TOOL_ARGS[@]}"
