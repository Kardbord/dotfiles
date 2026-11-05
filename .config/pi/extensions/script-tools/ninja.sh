#!/bin/bash
# tool: ninja
# description: Runs `ninja` followed by the arguments you pass.
# detect: build.ninja
# lazy
# param: args string optional The arguments to pass to `ninja`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"

check_dependencies ninja
ninja "$@"
