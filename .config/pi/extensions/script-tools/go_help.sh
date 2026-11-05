#!/bin/bash
# tool: go_help
# description: Runs `go help` followed by the arguments you pass.
# lazy
# detect: go.mod,go.sum,*.go
# param: args string required The arguments to pass to `go help`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"

check_dependencies go
go help "$@"
