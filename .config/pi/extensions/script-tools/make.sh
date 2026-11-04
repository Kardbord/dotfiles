#!/bin/bash
# tool: make
# description: Runs `make` followed by the arguments you pass.
# detect: Makefile,GNUmakefile,makefile
# param: args string optional The arguments to pass to `make`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/include/check_dependencies.sh"

check_dependencies make
make "$@"
