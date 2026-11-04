#!/bin/bash
# tool: cpack
# description: Runs `cpack` followed by the arguments you pass.
# detect: CMakeLists.txt,CMakeCache.txt,*.cmake
# param: args string optional The arguments to pass to `cpack`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"

check_dependencies cpack
cpack "$@"
