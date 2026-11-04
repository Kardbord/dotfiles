#!/bin/bash
# tool: cmake
# description: Runs `cmake` followed by the arguments you pass.
# detect: CMakeLists.txt,CMakeCache.txt,*.cmake
# param: args string required The arguments to pass to `cmake`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"

check_dependencies cmake
cmake "$@"
