#!/bin/bash
# tool: actionlint
# description: Runs `actionlint` followed by the arguments you pass.
# param: args string required The arguments to pass to `actionlint`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"

check_dependencies actionlint
actionlint "$@"
