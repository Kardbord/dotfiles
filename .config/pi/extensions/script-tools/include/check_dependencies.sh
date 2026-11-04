#!/bin/bash

check_dependencies() {
  local missing=0
  for tool in "$@"; do
    if ! command -v "${tool}" &>/dev/null; then
      echo "ERROR: prerequisite not found on PATH: ${tool}" >&2
      missing=1
    fi
  done
  return "${missing}"
}
