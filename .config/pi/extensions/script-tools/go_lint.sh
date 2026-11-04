#!/bin/bash
# tool: go_lint
# description: Runs `golangci-lint` followed by the arguments you pass.
# detect: go.mod,go.sum,*.go
# param: args string required The arguments to pass to `golangci-lint`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"

check_dependencies golangci-lint
golangci-lint "$@"
