#!/bin/bash
# tool: go_test
# description: Runs `go test` followed by the arguments you pass.
# detect: go.mod,go.sum,*.go
# param: args string required The arguments to pass to `go test`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"

check_dependencies go
go test "$@"
