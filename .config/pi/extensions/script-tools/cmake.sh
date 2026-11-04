#!/bin/bash
# tool: cmake
# description: Runs `cmake` followed by the arguments you pass.
# param: args string required The arguments to pass to `cmake`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"

check_dependencies cmake
cmake "$@"
