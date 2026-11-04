#!/bin/bash
# tool: ninja
# description: Runs `ninja` followed by the arguments you pass.
# param: args string optional The arguments to pass to `ninja`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"
source "$(dirname "${BASH_SOURCE[0]}")/include/str_to_arr.sh"

check_dependencies ninja
str_to_arr PI_TOOL_ARGS "${PI_TOOL_ARGS}"
ninja "${PI_TOOL_ARGS[@]}"
