#!/bin/bash
# tool: go_format
# description: Runs `gofmt` followed by the arguments you pass.
# detect: go.mod,go.sum,*.go
# param: args string required The arguments to pass to `gofmt`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"

check_dependencies gofmt
gofmt "$@"
