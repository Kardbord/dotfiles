#!/bin/bash
# tool: yq
# description: Runs `yq` followed by the arguments you pass.
# param: args string required The arguments to pass to `yq`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"

check_dependencies yq
yq "$@"
