#!/bin/bash
# tool: go_mod
# description: Runs `go mod` followed by the arguments you pass.
# param: args string required The arguments to pass to `go mod`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"

check_dependencies go
go mod "$@"
