#!/bin/bash

str_to_arr() {
  local -n __out="${1}"
  shift
  local IFS=' '
  read -ra __out <<<"${*}"
}
