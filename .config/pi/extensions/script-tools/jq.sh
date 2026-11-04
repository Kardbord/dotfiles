#!/bin/bash
# tool: jq
# description: Runs `jq` followed by the arguments you pass.
# param: args string required The arguments to pass to `jq`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"

check_dependencies jq
jq "$@"
