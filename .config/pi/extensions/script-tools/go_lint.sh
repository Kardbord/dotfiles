#!/bin/bash
# tool: go_lint
# description: Runs `golangci-lint` followed by the arguments you pass.
# param: args string required The arguments to pass to `golangci-lint`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"
source "$(dirname "${BASH_SOURCE[0]}")/include/str_to_arr.sh"

check_dependencies golangci-lint
str_to_arr PI_TOOL_ARGS "${PI_TOOL_ARGS}"
golangci-lint "${PI_TOOL_ARGS[@]}"
