#!/bin/bash
# tool: go_build
# description: Runs `go build` followed by the arguments you pass.
# param: args string required The arguments to pass to `go build`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"

check_dependencies go
go build "$@"
