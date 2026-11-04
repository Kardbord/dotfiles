#!/bin/bash
# tool: ctest
# description: Runs `ctest` followed by the arguments you pass.
# detect: CMakeLists.txt,CMakeCache.txt,*.cmake
# param: args string optional The arguments to pass to `ctest`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"

check_dependencies ctest
ctest "$@"
