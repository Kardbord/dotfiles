#!/bin/bash
# tool: ctest
# description: Runs `ctest` followed by the arguments you pass.
# param: args string optional The arguments to pass to `ctest`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"

check_dependencies ctest
ctest "$@"
